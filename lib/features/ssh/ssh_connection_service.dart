import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ssh_connection.dart';

class SshConnectionService extends ChangeNotifier {
  static const _keyList = 'ssh_server_list';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  List<SshConnection> _connections = [];
  List<SshConnection> get connections => List.unmodifiable(_connections);

  Future<void> load() async {
    final raw = await _storage.read(key: _keyList);
    if (raw != null && raw.isNotEmpty) {
      try {
        _connections = SshConnection.decodeList(raw);
      } catch (_) {
        _connections = [];
      }
    }
    notifyListeners();
  }

  Future<void> add(SshConnection conn,
      {String? password, String? privateKeyPem}) async {
    _connections.add(conn);
    await _persist();
    await _saveSecret(conn.id, password: password, privateKeyPem: privateKeyPem);
    notifyListeners();
  }

  Future<void> update(SshConnection conn,
      {String? password, String? privateKeyPem}) async {
    final idx = _connections.indexWhere((c) => c.id == conn.id);
    if (idx == -1) return;
    _connections[idx] = conn;
    await _persist();
    if (password != null || privateKeyPem != null) {
      await _saveSecret(conn.id,
          password: password, privateKeyPem: privateKeyPem);
    }
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _connections.removeWhere((c) => c.id == id);
    await _persist();
    await _storage.delete(key: _passwordKey(id));
    await _storage.delete(key: _keyKey(id));
    notifyListeners();
  }

  Future<String?> getPassword(String id) =>
      _storage.read(key: _passwordKey(id));

  Future<String?> getPrivateKey(String id) =>
      _storage.read(key: _keyKey(id));

  Future<void> _persist() async {
    await _storage.write(
        key: _keyList, value: SshConnection.encodeList(_connections));
  }

  Future<void> _saveSecret(String id,
      {String? password, String? privateKeyPem}) async {
    if (password != null) {
      await _storage.write(key: _passwordKey(id), value: password);
    }
    if (privateKeyPem != null) {
      await _storage.write(key: _keyKey(id), value: privateKeyPem);
    }
  }

  static String _passwordKey(String id) => 'ssh_srv_${id}_pw';
  static String _keyKey(String id) => 'ssh_srv_${id}_key';
}
