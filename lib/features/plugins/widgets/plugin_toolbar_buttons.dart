import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme.dart';
import '../loaded_plugin.dart';
import '../plugin_manifest.dart';
import '../plugin_service.dart';

/// 有効なプラグインのツールバーボタンをAppBar actionsに注入するウィジェット
class PluginToolbarButtons extends StatelessWidget {
  const PluginToolbarButtons({
    super.key,
    required this.onCommandAction,
    this.onJsAction,
    this.onTuiAction,
  });

  final void Function(String command) onCommandAction;
  final void Function(LoadedPlugin plugin, String function)? onJsAction;
  final void Function(LoadedPlugin plugin, String entry)? onTuiAction;

  @override
  Widget build(BuildContext context) {
    return Consumer<PluginService>(
      builder: (context, service, _) {
        final buttons = service.enabledPlugins
            .expand((p) => p.manifest.ui.toolbarButtons
                .map((b) => (plugin: p, button: b)))
            .toList();
        if (buttons.isEmpty) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: buttons.map((item) {
            return Tooltip(
              message:
                  item.button.tooltip ?? item.button.label,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _handle(item.button.action, item.plugin);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.extension_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        item.button.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _handle(PluginAction action, LoadedPlugin plugin) {
    switch (action.type) {
      case PluginActionType.command:
        if (action.command != null) onCommandAction(action.command!);
      case PluginActionType.js:
        if (action.function != null && onJsAction != null) {
          onJsAction!(plugin, action.function!);
        }
      case PluginActionType.tui:
        if (action.entry != null && onTuiAction != null) {
          onTuiAction!(plugin, action.entry!);
        }
    }
  }
}
