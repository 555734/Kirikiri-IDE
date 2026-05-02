import 'dart:convert';

enum SshAuthType { password, privateKey }

class SshConnection {
  const SshConnection({
    required this.id,
    required this.label,
    required this.host,
    required this.port,
    required this.username,
    required this.authType,
  });

  final String id;
  final String label;
  final String host;
  final int port;
  final String username;
  final SshAuthType authType;

  String get displayHost => port == 22 ? host : '$host:$port';

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'host': host,
        'port': port,
        'username': username,
        'authType': authType.name,
      };

  factory SshConnection.fromJson(Map<String, dynamic> j) => SshConnection(
        id: j['id'] as String,
        label: j['label'] as String,
        host: j['host'] as String,
        port: (j['port'] as num).toInt(),
        username: j['username'] as String,
        authType: SshAuthType.values.firstWhere(
          (e) => e.name == j['authType'],
          orElse: () => SshAuthType.password,
        ),
      );

  SshConnection copyWith({
    String? label,
    String? host,
    int? port,
    String? username,
    SshAuthType? authType,
  }) =>
      SshConnection(
        id: id,
        label: label ?? this.label,
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        authType: authType ?? this.authType,
      );

  static String encodeList(List<SshConnection> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<SshConnection> decodeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => SshConnection.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
