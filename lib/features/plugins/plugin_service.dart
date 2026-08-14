import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../core/secure_storage_service.dart';
import 'loaded_plugin.dart';
import 'plugin_manifest.dart';

// ── ストアエントリモデル ────────────────────────────────

class PluginStoreEntry {
  const PluginStoreEntry({
    required this.name,
    required this.repoUrl,
    required this.author,
    this.description,
    this.stars = 0,
    this.updatedAt,
    this.topics = const [],
  });

  final String name;
  final String repoUrl;   // https://github.com/owner/repo
  final String author;
  final String? description;
  final int stars;
  final DateTime? updatedAt;
  final List<String> topics;

  factory PluginStoreEntry.fromGitHub(Map<String, dynamic> j) =>
      PluginStoreEntry(
        name: j['name'] as String,
        repoUrl: j['html_url'] as String,
        author: (j['owner'] as Map<String, dynamic>)['login'] as String,
        description: j['description'] as String?,
        stars: j['stargazers_count'] as int? ?? 0,
        updatedAt: j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'] as String)
            : null,
        topics: (j['topics'] as List? ?? []).cast<String>(),
      );
}

/// プラグインのインストール・読み込み・有効/無効・削除を管理する
class PluginService extends ChangeNotifier {
  List<LoadedPlugin> _plugins = [];
  bool _isInstalling = false;
  double _installProgress = 0.0;
  String? _installError;

  List<LoadedPlugin> get plugins => List.unmodifiable(_plugins);
  List<LoadedPlugin> get enabledPlugins =>
      _plugins.where((p) => p.isEnabled).toList();
  bool get isInstalling => _isInstalling;
  double get installProgress => _installProgress;
  String? get installError => _installError;

  // ── 起動時読み込み ─────────────────────────────────

  Future<void> loadAll() async {
    final raw = await SecureStorageService.instance.getPluginList();
    if (raw == null) return;

    List list;
    try {
      list = jsonDecode(raw) as List;
    } catch (_) {
      return;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final loaded = <LoadedPlugin>[];

    for (final item in list) {
      final id = item['id'] as String?;
      if (id == null) continue;
      final dir = Directory('${docsDir.path}/kirikiri_plugins/$id');
      if (!await dir.exists()) continue;
      try {
        final manifestFile = File('${dir.path}/plugin.json');
        final manifest =
            PluginManifest.fromJson(jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>);
        loaded.add(LoadedPlugin(
          manifest: manifest,
          directory: dir,
          isEnabled: item['enabled'] as bool? ?? true,
        ));
      } catch (_) {
        // 壊れたプラグインはスキップ
      }
    }

    _plugins = loaded;
    notifyListeners();
  }

  // ── GitHub URLからインストール ──────────────────────

  Future<void> installFromGitHub(String repoUrl) async {
    _isInstalling = true;
    _installError = null;
    _installProgress = 0.0;
    notifyListeners();

    try {
      final zipUrl = _toZipUrl(repoUrl.trim());
      final response = await http.get(
        Uri.parse(zipUrl),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(AppConstants.httpDownloadTimeout);
      if (response.statusCode != 200) {
        throw Exception('ダウンロード失敗 (HTTP ${response.statusCode})');
      }

      _installProgress = 0.4;
      notifyListeners();

      final archive = ZipDecoder().decodeBytes(response.bodyBytes);

      // ZIPの最上位ディレクトリ名 (GitHub は "owner-repo-sha/" を付ける)
      final topLevel = archive.files
          .map((f) => f.name.split('/').first)
          .where((s) => s.isNotEmpty)
          .first;

      // plugin.json を探してマニフェストを取得
      final manifestEntry = archive.files.firstWhere(
        (f) =>
            f.name == 'plugin.json' ||
            f.name == '$topLevel/plugin.json' ||
            f.name.endsWith('/plugin.json'),
        orElse: () => throw Exception('plugin.json が見つかりません'),
      );
      final manifest = PluginManifest.fromJson(
          jsonDecode(utf8.decode(manifestEntry.content as List<int>))
              as Map<String, dynamic>);

      _installProgress = 0.6;
      notifyListeners();

      final docsDir = await getApplicationDocumentsDirectory();
      final targetDir =
          Directory('${docsDir.path}/kirikiri_plugins/${manifest.id}');
      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
      await targetDir.create(recursive: true);

      // ファイルを解凍（最上位ディレクトリを除去）
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final stripped = file.name.startsWith('$topLevel/')
            ? file.name.substring(topLevel.length + 1)
            : file.name;
        if (stripped.isEmpty) continue;

        // Zip Slip 対策: 展開先がプラグインディレクトリ配下に収まることを
        // 必ず確認する（'../' を含むエントリで任意のパスへ書き込ませない）
        final outFile = File(_safeJoin(targetDir, stripped));
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }

      _installProgress = 0.9;
      notifyListeners();

      _plugins.removeWhere((p) => p.manifest.id == manifest.id);
      _plugins.add(LoadedPlugin(
        manifest: manifest,
        directory: targetDir,
        isEnabled: true,
      ));
      await _persist();

      _installProgress = 1.0;
    } catch (e) {
      _installError = e.toString();
    } finally {
      _isInstalling = false;
      notifyListeners();
    }
  }

  // ── 有効/無効 ──────────────────────────────────────

  Future<void> setEnabled(String pluginId, bool enabled) async {
    final idx = _plugins.indexWhere((p) => p.manifest.id == pluginId);
    if (idx == -1) return;
    _plugins[idx] = _plugins[idx].copyWith(isEnabled: enabled);
    await _persist();
    notifyListeners();
  }

  // ── アンインストール ────────────────────────────────

  Future<void> uninstall(String pluginId) async {
    final plugin =
        _plugins.firstWhere((p) => p.manifest.id == pluginId);
    if (await plugin.directory.exists()) {
      await plugin.directory.delete(recursive: true);
    }
    await SecureStorageService.instance.deletePluginValues(pluginId);
    _plugins.removeWhere((p) => p.manifest.id == pluginId);
    await _persist();
    notifyListeners();
  }

  // ── ストア検索 (GitHub Topics API) ────────────────────

  /// GitHub Topics APIで kirikiri-plugin タグのリポジトリを検索する。
  /// query が空の場合はスター数降順で全件取得。
  /// PAT があればレート制限が緩和される（10→30 req/min）。
  Future<List<PluginStoreEntry>> searchStore({
    String query = '',
    String sort = 'stars', // stars | updated
  }) async {
    final pat = await SecureStorageService.instance.getGitHubPat();
    final q = [
      'topic:kirikiri-plugin',
      if (query.trim().isNotEmpty) query.trim(),
    ].join(' ');

    // クエリは Uri のクエリパラメータとして渡す。文字列連結だと空白や
    // & を含む検索語で URL が壊れる。
    final uri = Uri.https('api.github.com', '/search/repositories', {
      'q': q,
      'sort': sort,
      'order': 'desc',
      'per_page': '30',
    });
    final headers = <String, String>{
      'Accept': 'application/vnd.github+json',
      if (pat != null && pat.isNotEmpty) 'Authorization': 'Bearer $pat',
    };

    final res =
        await http.get(uri, headers: headers).timeout(AppConstants.httpTimeout);
    if (res.statusCode != 200) {
      throw Exception('GitHub検索エラー (${res.statusCode})');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['items'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    return items.map(PluginStoreEntry.fromGitHub).toList();
  }

  bool isInstalled(String repoUrl) {
    final uri = Uri.tryParse(repoUrl);
    if (uri == null) return false;
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) return false;
    // repo名をidとして確認（完全一致は保証できないが実用上は十分）
    return _plugins.any((p) =>
        p.manifest.id == parts[1] ||
        p.manifest.id == '${parts[0]}.${parts[1]}');
  }

  // ── 永続化 ─────────────────────────────────────────

  Future<void> _persist() async {
    final list = _plugins
        .map((p) => {'id': p.manifest.id, 'enabled': p.isEnabled})
        .toList();
    await SecureStorageService.instance.savePluginList(jsonEncode(list));
  }

  // ── ユーティリティ ─────────────────────────────────

  /// [entryName] を [targetDir] 配下の絶対パスに解決する。
  /// 解決結果が [targetDir] の外へ出る場合は例外を投げる。
  @visibleForTesting
  static String safeJoin(Directory targetDir, String entryName) =>
      _safeJoin(targetDir, entryName);

  static String _safeJoin(Directory targetDir, String entryName) {
    final base = _normalize(targetDir.path);
    final resolved = _normalize('$base/$entryName');
    if (resolved != base && !resolved.startsWith('$base/')) {
      throw Exception('不正なパスを含むプラグインです: $entryName');
    }
    return resolved;
  }

  /// '.' と '..' を解決してパスを正規化する（絶対パス前提）。
  static String _normalize(String path) {
    final isAbsolute = path.startsWith('/');
    final parts = <String>[];
    for (final segment in path.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (parts.isNotEmpty && parts.last != '..') {
          parts.removeLast();
        } else if (!isAbsolute) {
          parts.add('..');
        }
        continue;
      }
      parts.add(segment);
    }
    return (isAbsolute ? '/' : '') + parts.join('/');
  }

  static String _toZipUrl(String repoUrl) {
    // https://github.com/owner/repo  →  https://api.github.com/repos/owner/repo/zipball
    final uri = Uri.parse(repoUrl);
    final parts =
        uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) throw Exception('GitHubリポジトリのURLを入力してください');
    return 'https://api.github.com/repos/${parts[0]}/${parts[1]}/zipball';
  }
}
