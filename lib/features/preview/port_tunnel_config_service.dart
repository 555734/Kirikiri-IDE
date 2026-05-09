import 'package:flutter/foundation.dart';

import '../../core/secure_storage_service.dart';
import 'port_tunnel_config.dart';

class PortTunnelConfigService extends ChangeNotifier {
  List<PortTunnelConfig> _configs = [];
  String? _connectionId;

  List<PortTunnelConfig> get configs => List.unmodifiable(_configs);
  String? get connectionId => _connectionId;

  Future<void> load(String connectionId) async {
    _connectionId = connectionId;
    final raw = await SecureStorageService.instance.getPortTunnels(connectionId);
    if (raw != null && raw.isNotEmpty) {
      try {
        _configs = PortTunnelConfig.decodeList(raw);
      } catch (_) {
        _configs = [];
      }
    } else {
      _configs = [];
    }
    notifyListeners();
  }

  Future<void> add(PortTunnelConfig config) async {
    _configs = [..._configs, config];
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _configs = _configs.where((c) => c.id != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> update(PortTunnelConfig config) async {
    _configs = _configs.map((c) => c.id == config.id ? config : c).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_connectionId == null) return;
    await SecureStorageService.instance.savePortTunnels(
      _connectionId!,
      PortTunnelConfig.encodeList(_configs),
    );
  }
}
