import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import 'port_tunnel_config.dart';
import 'port_tunnel_config_service.dart';

enum TunnelStatus { idle, active, error }

class _TunnelEntry {
  _TunnelEntry({required this.server, required this.localPort});

  final ServerSocket server;
  final int localPort;
  TunnelStatus status = TunnelStatus.active;
  String? errorMessage;
  StreamSubscription<Socket>? acceptSub;
  final List<StreamSubscription<dynamic>> pipeSubs = [];
}

/// Manages SSH local port forwarding tunnels for dev server preview.
///
/// Each tunnel binds a local ServerSocket on 127.0.0.1:localPort and proxies
/// TCP connections through the SSH ForwardChannel to the remote server port.
class SshTunnelService extends ChangeNotifier {
  SshTunnelService({
    required this.connectionId,
    required this.configService,
  });

  final String connectionId;
  final PortTunnelConfigService configService;

  SSHClient? _client;
  final _tunnels = <int, _TunnelEntry>{}; // keyed by remotePort

  Map<int, TunnelStatus> get tunnelStatuses =>
      _tunnels.map((k, v) => MapEntry(k, v.status));

  TunnelStatus statusOf(int remotePort) =>
      _tunnels[remotePort]?.status ?? TunnelStatus.idle;

  int? localPortOf(int remotePort) => _tunnels[remotePort]?.localPort;

  String? getPreviewUrl(int remotePort) {
    final entry = _tunnels[remotePort];
    if (entry == null || entry.status != TunnelStatus.active) return null;
    return 'http://127.0.0.1:${entry.localPort}';
  }

  Future<void> onSshConnected(SSHClient client) async {
    _client = client;
    // Load saved configs if not already loaded, then re-start autoConnect tunnels
    if (configService.connectionId == null) {
      await configService.load(connectionId);
    }
    for (final cfg in configService.configs) {
      if (cfg.autoConnect) {
        unawaited(startTunnel(cfg.remotePort));
      }
    }
  }

  Future<void> onSshDisconnected() async {
    _client = null;
    await stopAll();
  }

  Future<void> startTunnel(int remotePort) async {
    if (_tunnels[remotePort]?.status == TunnelStatus.active) return;
    if (_client == null) {
      throw StateError('SSH not connected');
    }

    final localPort = await _allocateLocalPort(remotePort);
    final ServerSocket server;
    try {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, localPort);
    } catch (e) {
      notifyListeners();
      rethrow;
    }

    final entry = _TunnelEntry(server: server, localPort: localPort);
    _tunnels[remotePort] = entry;
    notifyListeners();

    entry.acceptSub = server.listen(
      (socket) => _pipeSocketToTunnel(socket, remotePort, entry),
      onError: (Object e) {
        entry.status = TunnelStatus.error;
        entry.errorMessage = e.toString();
        notifyListeners();
      },
      cancelOnError: false,
    );
  }

  Future<void> stopTunnel(int remotePort) async {
    final entry = _tunnels.remove(remotePort);
    if (entry == null) return;
    await _closeEntry(entry);
    notifyListeners();
  }

  Future<void> stopAll() async {
    final entries = _tunnels.values.toList();
    _tunnels.clear();
    for (final entry in entries) {
      await _closeEntry(entry);
    }
    notifyListeners();
  }

  /// Runs `ss -tlnp` (or netstat fallback) via a non-PTY exec channel and
  /// returns listening port numbers in the range 1024–65535.
  Future<List<int>> detectRunningPorts() async {
    if (_client == null) return [];
    try {
      final result = await _client!.run(
        'ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null',
      );
      final output = utf8.decode(result, allowMalformed: true);
      final portRegex = RegExp(r':(\d{4,5})\s');
      return portRegex
          .allMatches(output)
          .map((m) => int.parse(m.group(1)!))
          .where((p) => p >= 1024 && p <= 65535)
          .toSet()
          .toList()
        ..sort();
    } catch (_) {
      return [];
    }
  }

  // ── Private ────────────────────────────────────────────────

  void _pipeSocketToTunnel(
      Socket socket, int remotePort, _TunnelEntry entry) async {
    final client = _client;
    if (client == null) {
      socket.destroy();
      return;
    }
    try {
      final channel = await client.forwardLocal('127.0.0.1', remotePort);
      final sub1 = channel.stream.listen(
        socket.add,
        onDone: socket.destroy,
        cancelOnError: true,
      );
      final sub2 = socket.listen(
        channel.sink.add,
        onDone: () => channel.sink.close(),
        cancelOnError: true,
      );
      entry.pipeSubs.addAll([sub1, sub2]);
    } catch (_) {
      socket.destroy();
    }
  }

  Future<void> _closeEntry(_TunnelEntry entry) async {
    await entry.acceptSub?.cancel();
    for (final sub in entry.pipeSubs) {
      await sub.cancel();
    }
    try {
      await entry.server.close();
    } catch (_) {}
  }

  Future<int> _allocateLocalPort(int remotePort) async {
    var candidate = PortTunnelConfig.defaultLocalPort(remotePort);
    while (true) {
      // Check if candidate is already in use by our tunnels
      final inUse = _tunnels.values.any((e) => e.localPort == candidate);
      if (!inUse) {
        // Try to bind briefly to confirm the port is free on the OS
        try {
          final probe = await ServerSocket.bind(
              InternetAddress.loopbackIPv4, candidate);
          await probe.close();
          return candidate;
        } catch (_) {
          candidate++;
        }
      } else {
        candidate++;
      }
    }
  }

  @override
  void dispose() {
    stopAll();
    super.dispose();
  }
}
