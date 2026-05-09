import 'dart:convert';

class LauncherCommand {
  const LauncherCommand({
    required this.id,
    required this.label,
    required this.command,
  });

  final String id;
  final String label;
  final String command;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'command': command,
      };

  factory LauncherCommand.fromJson(Map<String, dynamic> j) => LauncherCommand(
        id: j['id'] as String,
        label: j['label'] as String,
        command: j['command'] as String,
      );

  LauncherCommand copyWith({String? label, String? command}) => LauncherCommand(
        id: id,
        label: label ?? this.label,
        command: command ?? this.command,
      );
}

class LauncherCategory {
  const LauncherCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.commands,
  });

  final String id;
  final String label;
  final String icon; // emoji
  final List<LauncherCommand> commands;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'icon': icon,
        'commands': commands.map((c) => c.toJson()).toList(),
      };

  factory LauncherCategory.fromJson(Map<String, dynamic> j) => LauncherCategory(
        id: j['id'] as String,
        label: j['label'] as String,
        icon: (j['icon'] as String?) ?? '📁',
        commands: (j['commands'] as List<dynamic>)
            .map((e) => LauncherCommand.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  LauncherCategory copyWith({
    String? label,
    String? icon,
    List<LauncherCommand>? commands,
  }) =>
      LauncherCategory(
        id: id,
        label: label ?? this.label,
        icon: icon ?? this.icon,
        commands: commands ?? this.commands,
      );

  static String encodeList(List<LauncherCategory> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<LauncherCategory> decodeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => LauncherCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
