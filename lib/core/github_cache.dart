/// インメモリ TTL キャッシュ。GitHubService の GET レスポンスを保持する。
class _CacheEntry {
  _CacheEntry(this.data, Duration ttl)
      : expiresAt = DateTime.now().add(ttl);

  final String data;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class GitHubCache {
  final _store = <String, _CacheEntry>{};

  /// TTL 内のデータを返す。期限切れまたは存在しない場合は null。
  String? getFresh(String key) {
    final e = _store[key];
    return (e != null && !e.isExpired) ? e.data : null;
  }

  /// 期限切れでもデータを返す（Stale-While-Revalidate 用）。
  String? getAny(String key) => _store[key]?.data;

  /// キャッシュに保存。
  void put(String key, String data, Duration ttl) =>
      _store[key] = _CacheEntry(data, ttl);

  /// 指定キーを削除。
  void invalidate(String key) => _store.remove(key);

  /// 条件に合致するキーを全削除（書き込み後の関連キャッシュ無効化）。
  void invalidateWhere(bool Function(String key) test) =>
      _store.removeWhere((k, _) => test(k));

  /// 全キャッシュをクリア（サインアウト時）。
  void clear() => _store.clear();
}
