import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'secure_storage_service.dart';

/// ホスト鍵の照合結果。
enum HostkeyVerdict {
  /// 保存済みの指紋と一致した。
  trusted,

  /// このホスト・鍵種別の指紋を保存していない（初回接続）。
  unknown,

  /// 保存済みの指紋と異なる指紋が提示された（中間者攻撃の可能性）。
  changed,
}

/// ユーザーにホスト鍵の受け入れ可否を問い合わせるための情報。
@immutable
class HostkeyRequest {
  const HostkeyRequest({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    required this.verdict,
    this.knownFingerprint,
  });

  final String host;
  final int port;

  /// 'ssh-ed25519' などの鍵種別。
  final String keyType;

  /// サーバーが提示した指紋（表示用フォーマット済み）。
  final String fingerprint;

  final HostkeyVerdict verdict;

  /// [HostkeyVerdict.changed] のときに保存されていた指紋。
  final String? knownFingerprint;

  String get hostLabel => port == 22 ? host : '$host:$port';
}

/// ホスト鍵を受け入れるなら true を返す。
typedef HostkeyPromptHandler = Future<bool> Function(HostkeyRequest request);

/// OpenSSH の known_hosts 相当。信頼したホスト鍵の指紋を保存し、
/// 次回以降の接続で同一性を検証する（TOFU: Trust On First Use）。
///
/// エントリは OpenSSH と同様に (ホスト:ポート, 鍵種別) 単位で保持する。
/// サーバーが別種別の鍵を提示した場合は「変更」ではなく「初回」として扱われる。
class KnownHostsService {
  KnownHostsService._();
  static final KnownHostsService instance = KnownHostsService._();

  final _storage = SecureStorageService.instance;

  Map<String, String>? _cache;

  /// dartssh2 が渡す MD5 ダイジェストを OpenSSH 形式の文字列に整形する。
  ///
  /// dartssh2 2.x のホスト鍵検証コールバックは MD5 ダイジェストしか渡さないため、
  /// より強い SHA-256 指紋を利用することはできない。ピン留めの用途としては
  /// 「検証しない」より遥かに強い保証が得られるが、将来 dartssh2 が
  /// SHA-256 指紋を提供した場合は移行すること。
  static String formatFingerprint(Uint8List digest) {
    final hex =
        digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
    return 'MD5:$hex';
  }

  static String _entryKey(String host, int port, String keyType) =>
      '$host:$port $keyType';

  Future<Map<String, String>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await _storage.getKnownHosts();
    var parsed = <String, String>{};
    if (raw != null) {
      try {
        parsed = (jsonDecode(raw) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as String));
      } catch (_) {
        // 壊れたエントリは破棄して作り直す（次回接続時に再確認される）
        parsed = <String, String>{};
      }
    }
    return _cache = parsed;
  }

  Future<void> _persist(Map<String, String> entries) async {
    _cache = entries;
    await _storage.saveKnownHosts(jsonEncode(entries));
  }

  /// 保存済みの指紋。未登録なら null。
  Future<String?> fingerprintOf(String host, int port, String keyType) async {
    final entries = await _load();
    return entries[_entryKey(host, port, keyType)];
  }

  /// 提示された指紋を保存済みの値と照合する。
  Future<HostkeyVerdict> verify(
    String host,
    int port,
    String keyType,
    String fingerprint,
  ) async {
    final known = await fingerprintOf(host, port, keyType);
    if (known == null) return HostkeyVerdict.unknown;
    return known == fingerprint
        ? HostkeyVerdict.trusted
        : HostkeyVerdict.changed;
  }

  /// 指紋を信頼済みとして保存する（既存エントリは上書き）。
  Future<void> trust(
    String host,
    int port,
    String keyType,
    String fingerprint,
  ) async {
    final entries = Map<String, String>.from(await _load());
    entries[_entryKey(host, port, keyType)] = fingerprint;
    await _persist(entries);
  }

  /// 指定ホストの全鍵種別のエントリを削除する。
  Future<void> forget(String host, int port) async {
    final entries = Map<String, String>.from(await _load());
    entries.removeWhere((k, _) => k.startsWith('$host:$port '));
    await _persist(entries);
  }

  /// 保存済みエントリ一覧（キー: 'host:port keyType'）。
  Future<Map<String, String>> all() async =>
      Map.unmodifiable(await _load());

  /// 全エントリを削除する。
  Future<void> clear() async => _persist(<String, String>{});
}
