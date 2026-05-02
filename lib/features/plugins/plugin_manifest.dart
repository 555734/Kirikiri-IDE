/// プラグインの plugin.json スキーマのデータモデル
library;

// ── アクション ──────────────────────────────────────────

enum PluginActionType { js, command, tui }

class PluginAction {
  const PluginAction({
    required this.type,
    this.function,
    this.command,
    this.entry,
  });

  final PluginActionType type;
  final String? function; // type == js
  final String? command;  // type == command
  final String? entry;    // type == tui (server_tools/ 内のスクリプト名)

  factory PluginAction.fromJson(Map<String, dynamic> j) {
    final t = switch (j['type'] as String? ?? '') {
      'js' => PluginActionType.js,
      'tui' => PluginActionType.tui,
      _ => PluginActionType.command,
    };
    return PluginAction(
      type: t,
      function: j['function'] as String?,
      command: j['command'] as String?,
      entry: j['entry'] as String?,
    );
  }
}

// ── UI 要素 ────────────────────────────────────────────

class PluginToolbarButton {
  const PluginToolbarButton({
    required this.id,
    required this.label,
    required this.icon,
    required this.action,
    this.tooltip,
  });

  final String id;
  final String label;
  final String icon;
  final String? tooltip;
  final PluginAction action;

  factory PluginToolbarButton.fromJson(Map<String, dynamic> j) =>
      PluginToolbarButton(
        id: j['id'] as String,
        label: j['label'] as String? ?? '',
        icon: j['icon'] as String? ?? 'extension',
        tooltip: j['tooltip'] as String?,
        action: PluginAction.fromJson(j['action'] as Map<String, dynamic>),
      );
}

class PluginCommandChip {
  const PluginCommandChip({
    required this.id,
    required this.label,
    required this.action,
  });

  final String id;
  final String label;
  final PluginAction action;

  factory PluginCommandChip.fromJson(Map<String, dynamic> j) =>
      PluginCommandChip(
        id: j['id'] as String,
        label: j['label'] as String,
        action: PluginAction.fromJson(j['action'] as Map<String, dynamic>),
      );
}

class PluginMenuItem {
  const PluginMenuItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.action,
  });

  final String id;
  final String label;
  final String icon;
  final PluginAction action;

  factory PluginMenuItem.fromJson(Map<String, dynamic> j) => PluginMenuItem(
        id: j['id'] as String,
        label: j['label'] as String,
        icon: j['icon'] as String? ?? 'extension',
        action: PluginAction.fromJson(j['action'] as Map<String, dynamic>),
      );
}

class PluginUi {
  const PluginUi({
    this.toolbarButtons = const [],
    this.commandChips = const [],
    this.menuItems = const [],
  });

  final List<PluginToolbarButton> toolbarButtons;
  final List<PluginCommandChip> commandChips;
  final List<PluginMenuItem> menuItems;

  factory PluginUi.fromJson(Map<String, dynamic> j) {
    List<T> _parse<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?)?.cast<Map<String, dynamic>>() ?? []).map(f).toList();
    return PluginUi(
      toolbarButtons: _parse('toolbar_buttons', PluginToolbarButton.fromJson),
      commandChips: _parse('command_chips', PluginCommandChip.fromJson),
      menuItems: _parse('menu_items', PluginMenuItem.fromJson),
    );
  }
}

// ── マニフェスト ───────────────────────────────────────

/// plugin.json 全体のデータモデル
class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    this.author = '',
    this.permissions = const [],
    this.minAppVersion,
    required this.ui,
  });

  final String id;
  final String name;
  final String version;
  final String description;
  final String author;
  final List<String> permissions;
  final String? minAppVersion;
  final PluginUi ui;

  bool hasPermission(String perm) => permissions.contains(perm);

  factory PluginManifest.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    if (id == null || id.isEmpty) throw FormatException('plugin.json に id が必要です');
    return PluginManifest(
      id: id,
      name: j['name'] as String? ?? id,
      version: j['version'] as String? ?? '0.0.0',
      description: j['description'] as String? ?? '',
      author: j['author'] as String? ?? '',
      permissions:
          (j['permissions'] as List?)?.cast<String>() ?? const [],
      minAppVersion: j['min_app_version'] as String?,
      ui: j['ui'] != null
          ? PluginUi.fromJson(j['ui'] as Map<String, dynamic>)
          : const PluginUi(),
    );
  }
}
