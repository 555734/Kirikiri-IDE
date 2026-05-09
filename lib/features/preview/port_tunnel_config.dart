import 'dart:convert';

class PortTunnelConfig {
  const PortTunnelConfig({
    required this.id,
    required this.connectionId,
    required this.remotePort,
    required this.localPort,
    required this.label,
    this.autoConnect = false,
  });

  final String id;
  final String connectionId;
  final int remotePort;
  final int localPort;
  final String label;
  final bool autoConnect;

  /// Default local port for a given remote port: 14000 + (remotePort % 1000)
  /// e.g. 3000→14000, 8080→14080, 5173→14173
  static int defaultLocalPort(int remotePort) => 14000 + (remotePort % 1000);

  Map<String, dynamic> toJson() => {
        'id': id,
        'connectionId': connectionId,
        'remotePort': remotePort,
        'localPort': localPort,
        'label': label,
        'autoConnect': autoConnect,
      };

  factory PortTunnelConfig.fromJson(Map<String, dynamic> j) => PortTunnelConfig(
        id: j['id'] as String,
        connectionId: j['connectionId'] as String,
        remotePort: (j['remotePort'] as num).toInt(),
        localPort: (j['localPort'] as num).toInt(),
        label: j['label'] as String,
        autoConnect: (j['autoConnect'] as bool?) ?? false,
      );

  PortTunnelConfig copyWith({
    String? label,
    bool? autoConnect,
    int? localPort,
  }) =>
      PortTunnelConfig(
        id: id,
        connectionId: connectionId,
        remotePort: remotePort,
        localPort: localPort ?? this.localPort,
        label: label ?? this.label,
        autoConnect: autoConnect ?? this.autoConnect,
      );

  static String encodeList(List<PortTunnelConfig> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<PortTunnelConfig> decodeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => PortTunnelConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
