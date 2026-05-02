import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme.dart';
import '../plugin_manifest.dart';
import '../plugin_service.dart';

/// 有効なプラグインの command_chips を横スクロールで表示するウィジェット。
/// CommandInputBar の上、ターミナル画面下部に配置する。
class PluginCommandChips extends StatelessWidget {
  const PluginCommandChips({
    super.key,
    required this.onSend,
    this.onJsAction,
    this.onTuiAction,
  });

  final void Function(String command) onSend;
  final void Function(dynamic plugin, String function)? onJsAction;
  final void Function(dynamic plugin, String entry)? onTuiAction;

  @override
  Widget build(BuildContext context) {
    return Consumer<PluginService>(
      builder: (context, service, _) {
        final chips = service.enabledPlugins
            .expand((p) => p.manifest.ui.commandChips
                .map((c) => (plugin: p, chip: c)))
            .toList();

        if (chips.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.surfaceVariant,
            border: Border(
              top: BorderSide(color: AppColors.surfaceHighlight),
            ),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            itemCount: chips.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              if (i == 0) {
                // ラベル
                return Center(
                  child: Text(
                    AppLocalizations.of(context)!.pluginLabel,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }
              final item = chips[i - 1];
              return _PluginChip(
                chip: item.chip,
                onTap: () => _handleAction(item.chip.action, item.plugin),
              );
            },
          ),
        );
      },
    );
  }

  void _handleAction(PluginAction action, dynamic plugin) {
    switch (action.type) {
      case PluginActionType.command:
        if (action.command != null) onSend(action.command!);
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

class _PluginChip extends StatelessWidget {
  const _PluginChip({required this.chip, required this.onTap});
  final PluginCommandChip chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.extension_rounded,
                  size: 10, color: AppColors.primary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  chip.label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
