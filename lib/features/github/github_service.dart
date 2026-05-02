import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../core/secure_storage_service.dart';

// ── モデル ────────────────────────────────────────────────

class GitHubRepo {
  const GitHubRepo({
    required this.name,
    required this.owner,
    this.description,
    required this.cloneUrl,
    required this.isPrivate,
    required this.defaultBranch,
    required this.updatedAt,
  });

  final String name;
  final String owner;
  final String? description;
  final String cloneUrl;
  final bool isPrivate;
  final String defaultBranch;
  final DateTime updatedAt;

  String get fullName => '$owner/$name';

  factory GitHubRepo.fromJson(Map<String, dynamic> j) => GitHubRepo(
        name: j['name'] as String,
        owner: (j['owner'] as Map<String, dynamic>)['login'] as String,
        description: j['description'] as String?,
        cloneUrl: j['clone_url'] as String,
        isPrivate: j['private'] as bool,
        defaultBranch: j['default_branch'] as String? ?? 'main',
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

class GitHubFile {
  const GitHubFile({
    required this.path,
    required this.type,
    this.sha,
    this.size,
  });

  final String path;
  final String type; // 'blob' | 'tree'
  final String? sha;
  final int? size;

  String get name => path.split('/').last;
  bool get isFile => type == 'blob';
  bool get isDir => type == 'tree';
  int get depth => path.split('/').length - 1;

  factory GitHubFile.fromJson(Map<String, dynamic> j) => GitHubFile(
        path: j['path'] as String,
        type: j['type'] as String,
        sha: j['sha'] as String?,
        size: j['size'] as int?,
      );
}

class GitHubFileContent {
  const GitHubFileContent({
    required this.path,
    required this.content,
    required this.sha,
  });

  final String path;
  final String content;
  final String sha;

  String get name => path.split('/').last;

  factory GitHubFileContent.fromJson(Map<String, dynamic> j) {
    final encoded = (j['content'] as String).replaceAll('\n', '');
    final decoded = utf8.decode(base64.decode(encoded));
    return GitHubFileContent(
      path: j['path'] as String,
      content: decoded,
      sha: j['sha'] as String,
    );
  }
}

// ── サービス ──────────────────────────────────────────────

class GitHubService extends ChangeNotifier {
  final _storage = SecureStorageService.instance;

  String? _pat;
  String? _username;
  bool _isLoading = false;
  String? _error;

  bool get isAuthenticated => _pat != null && _pat!.isNotEmpty;
  String? get username => _username;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get pat => _pat;

  Future<void> init() async {
    _pat = await _storage.getGitHubPat();
    if (isAuthenticated) {
      try {
        await _fetchCurrentUser();
      } catch (_) {
        _pat = null;
        await _storage.deleteGitHubPat();
      }
    }
    notifyListeners();
  }

  Future<void> signIn(String pat) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _pat = pat.trim();
      await _fetchCurrentUser();
      await _storage.saveGitHubPat(_pat!);
    } catch (e) {
      _pat = null;
      _error = 'トークンが無効です。repo スコープ付きの PAT を入力してください。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _pat = null;
    _username = null;
    await _storage.deleteGitHubPat();
    notifyListeners();
  }

  Future<void> _fetchCurrentUser() async {
    final body = await _get('/user');
    final json = jsonDecode(body) as Map<String, dynamic>;
    _username = json['login'] as String?;
  }

  Future<List<GitHubRepo>> listRepos() async {
    final body = await _get(
        '/user/repos?sort=updated&per_page=100&affiliation=owner,collaborator');
    final list = jsonDecode(body) as List<dynamic>;
    return list
        .map((e) => GitHubRepo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<GitHubFile>> getFileTree(
      String owner, String repo, String branch) async {
    final body = await _get(
        '/repos/$owner/$repo/git/trees/$branch?recursive=1');
    final json = jsonDecode(body) as Map<String, dynamic>;
    final tree = json['tree'] as List<dynamic>;
    return tree
        .map((e) => GitHubFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GitHubFileContent> getFileContent(
      String owner, String repo, String path) async {
    final body = await _get('/repos/$owner/$repo/contents/$path');
    final json = jsonDecode(body) as Map<String, dynamic>;
    return GitHubFileContent.fromJson(json);
  }

  Future<void> updateFile({
    required String owner,
    required String repo,
    required String path,
    required String content,
    required String sha,
    String? commitMessage,
  }) async {
    final message = commitMessage ?? 'Update $path via kirikiri';
    await _put(
      '/repos/$owner/$repo/contents/$path',
      jsonEncode({
        'message': message,
        'content': base64.encode(utf8.encode(content)),
        'sha': sha,
      }),
    );
  }

  // PAT を使った clone URL（private リポジトリ対応）
  String cloneUrl(GitHubRepo repo) {
    if (!repo.isPrivate || _pat == null) return repo.cloneUrl;
    return 'https://oauth2:$_pat@github.com/${repo.owner}/${repo.name}.git';
  }

  // Cloud Shell で実行する clone/pull コマンド
  String buildShellCommand(GitHubRepo repo) {
    final dir = '\$HOME/${repo.name}';
    final url = cloneUrl(repo);
    return 'if [ -d "$dir/.git" ]; then '
        'echo "↓ Pulling ${repo.name}..." && cd "$dir" && git pull; '
        'else '
        'echo "⬇ Cloning ${repo.fullName}..." && git clone "$url" "$dir" && cd "$dir"; '
        'fi';
  }

  Future<String> _get(String path) async {
    final response = await http.get(
      Uri.parse('${AppConstants.gitHubApiBase}$path'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('GitHub API ${response.statusCode}');
    }
    return response.body;
  }

  Future<void> _put(String path, String body) async {
    final response = await http.put(
      Uri.parse('${AppConstants.gitHubApiBase}$path'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'GitHub API ${response.statusCode}: ${response.body}');
    }
  }

  Map<String, String> get _headers => {
        'Authorization': 'token $_pat',
        'Accept': 'application/vnd.github.v3+json',
      };
}
