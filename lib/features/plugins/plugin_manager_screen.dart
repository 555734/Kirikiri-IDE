import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/failure_messages.dart';
import '../../theme/app_theme.dart';
import 'loaded_plugin.dart';
import 'plugin_service.dart';
import 'plugin_store_screen.dart';

/// プラグインのインストール・管理画面
class PluginManagerScreen extends StatefulWidget {
  const PluginManagerScreen({super.key});

  @override
  State<PluginManagerScreen> createState() => _PluginManagerScreenState();
}

class _PluginManagerScreenState extends State<PluginManagerScreen> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.pluginsTitle),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.storefront_rounded),
            tooltip: AppLocalizations.of(context)!.pluginStoreTitle,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PluginStoreScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<PluginService>(
        builder: (context, service, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildInstallSection(context, service),
              const SizedBox(height: 24),
              _buildInstalledSection(context, service),
            ],
          );
        },
      ),
    );
  }

  // ── インストールセクション ──────────────────────────

  Widget _buildInstallSection(
      BuildContext context, PluginService service) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.pluginAddTitle,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.pluginAddDescription,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: l.pluginUrlHint,
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                onSubmitted: (_) => _install(context, service),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed:
                  service.isInstalling ? null : () => _install(context, service),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
              ),
              child: Text(AppLocalizations.of(context)!.pluginInstall),
            ),
          ],
        ),
        if (service.isInstalling) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: service.installProgress,
            backgroundColor: AppColors.surfaceHighlight,
            valueColor:
                const AlwaysStoppedAnimation(AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.pluginInstallProgress((service.installProgress * 100).toInt()),
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
        if (service.installError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pluginFailureMessage(AppLocalizations.of(context)!,
                        service.installError!),
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _install(
      BuildContext context, PluginService service) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await service.installFromGitHub(url);
    if (service.installError == null && context.mounted) {
      _urlController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pluginInstall)),
      );
    }
  }

  // ── インストール済みセクション ──────────────────────

  Widget _buildInstalledSection(
      BuildContext context, PluginService service) {
    final l = AppLocalizations.of(context)!;
    if (service.plugins.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              const Icon(Icons.extension_off_rounded,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                l.pluginInstalledEmpty,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.pluginInstalledCount(service.plugins.length),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...service.plugins
            .map((p) => _PluginCard(plugin: p))
            .toList(),
      ],
    );
  }
}

// ── プラグインカード ────────────────────────────────────

class _PluginCard extends StatefulWidget {
  const _PluginCard({required this.plugin});
  final LoadedPlugin plugin;

  @override
  State<_PluginCard> createState() => _PluginCardState();
}

class _PluginCardState extends State<_PluginCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.plugin.manifest;
    final service = context.read<PluginService>();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHighlight),
      ),
      child: Column(
        children: [
          // ── ヘッダー行 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.redSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.extension_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'v${m.version}${m.author.isNotEmpty ? ' • ${m.author}' : ''}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: widget.plugin.isEnabled,
                  activeColor: AppColors.primary,
                  onChanged: (v) =>
                      service.setEnabled(m.id, v),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 20, color: AppColors.textMuted),
                  onPressed: () => _confirmDelete(context, service),
                ),
                IconButton(
                  icon: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () =>
                      setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),

          // ── 展開詳細 ──
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.surfaceHighlight),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.description.isNotEmpty) ...[
                    Text(m.description,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13)),
                    const SizedBox(height: 12),
                  ],
                  _infoRow(
                      AppLocalizations.of(context)!.pluginToolbarButtons,
                      '${m.ui.toolbarButtons.length}'),
                  _infoRow(
                      AppLocalizations.of(context)!.pluginCommandChips,
                      '${m.ui.commandChips.length}'),
                  _infoRow(
                      AppLocalizations.of(context)!.pluginMenuItems,
                      '${m.ui.menuItems.length}'),
                  if (m.permissions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.pluginPermissions,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: m.permissions
                          .map((p) => _permChip(p))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );

  Widget _permChip(String perm) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.redSurface,
          borderRadius: BorderRadius.circular(4),
          border:
              Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Text(
          perm,
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontFamily: 'monospace'),
        ),
      );

  void _confirmDelete(BuildContext context, PluginService service) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.pluginUninstall),
        content: Text('「${widget.plugin.manifest.name}」${l.pluginUninstallConfirm}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await service.uninstall(widget.plugin.manifest.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.delete)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: Text(l.delete),
          ),
        ],
      ),
    );
  }
}
