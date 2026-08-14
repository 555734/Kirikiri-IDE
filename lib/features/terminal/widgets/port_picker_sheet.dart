import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_theme.dart';
import '../../preview/port_tunnel_config.dart';
import '../../preview/port_tunnel_config_service.dart';
import '../../preview/ssh_tunnel_service.dart';
import '../../preview/web_preview_screen.dart';
import '../terminal_controller.dart';

// ── ポートピッカーシート ──────────────────────────────────────

class PortPickerSheet extends StatefulWidget {
  const PortPickerSheet({required this.controller});
  final TerminalController controller;

  @override
  State<PortPickerSheet> createState() => PortPickerSheetState();
}

class PortPickerSheetState extends State<PortPickerSheet> {
  static const _commonPorts = [3000, 4200, 5000, 5173, 8000, 8080];

  final _portCtrl = TextEditingController();
  List<int>? _detectedPorts;
  bool _detecting = false;

  @override
  void dispose() {
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _detect() async {
    setState(() {
      _detecting = true;
      _detectedPorts = null;
    });
    final ports = await widget.controller.detectRunningPorts();
    if (mounted) {
      setState(() {
        _detecting = false;
        _detectedPorts = ports;
      });
    }
  }

  void _openPort(int port) {
    final webHost = widget.controller.webHost;
    if (webHost != null) {
      // Cloud Shell: open via webHost proxy URL
      Navigator.pop(context);
      launchUrl(
        Uri.parse('https://$port-$webHost'),
        mode: LaunchMode.inAppBrowserView,
      );
      return;
    }

    // Custom SSH: start tunnel then open WebView
    final tunnelService = widget.controller.tunnels;
    if (tunnelService == null) return;
    // Capture navigator before closing the sheet
    final nav = Navigator.of(context);
    Navigator.pop(context);

    tunnelService.startTunnel(port).then((_) {
      final url = tunnelService.getPreviewUrl(port);
      if (url != null) {
        nav.push(MaterialPageRoute(
          builder: (_) => WebPreviewScreen(url: url),
        ));
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tunnelService = widget.controller.tunnels;
    final isCloudShell = widget.controller.webHost != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── タイトル ──
            Text(l.portPickerTitle,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l.portPickerBody,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),

            // ── Section A: アクティブなトンネル（SSH専用） ──
            if (!isCloudShell && tunnelService != null)
              _ActiveTunnelsSection(
                tunnelService: tunnelService,
                onOpen: (port) => _openPort(port),
              ),

            // ── Section B: クイックポートチップ ──
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._commonPorts.map((port) => _PortChip(
                      port: port,
                      status: tunnelService?.statusOf(port) ?? TunnelStatus.idle,
                      isCloudShell: isCloudShell,
                      onTap: () => _openPort(port),
                    )),
                // 検出ボタン
                ActionChip(
                  avatar: _detecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.primary))
                      : const Icon(Icons.search_rounded,
                          size: 14, color: AppColors.primary),
                  label: Text(
                    _detecting ? l.portDetecting : l.portDetect,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  backgroundColor: AppColors.surfaceVariant,
                  side: BorderSide(
                      color: AppColors.primary.withOpacity(0.25)),
                  onPressed: _detecting ? null : _detect,
                ),
              ],
            ),

            // ── 検出されたポート ──
            if (_detectedPorts != null) ...[
              const SizedBox(height: 12),
              if (_detectedPorts!.isEmpty)
                Text(AppLocalizations.of(context)!.portDetectedNone,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _detectedPorts!
                      .where((p) => !_commonPorts.contains(p))
                      .map((port) => _PortChip(
                            port: port,
                            status: tunnelService?.statusOf(port) ??
                                TunnelStatus.idle,
                            isCloudShell: isCloudShell,
                            onTap: () => _openPort(port),
                          ))
                      .toList(),
                ),
            ],

            const SizedBox(height: 16),

            // ── Section C: 保存済み設定（SSH専用） ──
            if (!isCloudShell && tunnelService != null)
              _SavedPortsSection(
                tunnelService: tunnelService,
                onOpen: (port) => _openPort(port),
              ),

            // ── カスタムポート入力 ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _portCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: l.portPickerCustom,
                      hintStyle: const TextStyle(
                          color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final port = int.tryParse(_portCtrl.text.trim());
                    if (port == null || port < 1 || port > 65535) return;
                    _openPort(port);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: Text(l.open),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── ポートチップ ────────────────────────────────────────────

class _PortChip extends StatelessWidget {
  const _PortChip({
    required this.port,
    required this.status,
    required this.isCloudShell,
    required this.onTap,
  });

  final int port;
  final TunnelStatus status;
  final bool isCloudShell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = status == TunnelStatus.active;
    final color = isActive ? AppColors.success : AppColors.primary;
    return ActionChip(
      avatar: isActive && !isCloudShell
          ? Icon(Icons.circle, size: 8, color: color)
          : null,
      label: Text('$port',
          style: const TextStyle(
              color: AppColors.textPrimary, fontFamily: 'monospace')),
      backgroundColor: color.withOpacity(0.15),
      side: BorderSide(color: color.withOpacity(0.5)),
      onPressed: onTap,
    );
  }
}

// ── アクティブトンネルセクション ────────────────────────────

class _ActiveTunnelsSection extends StatelessWidget {
  const _ActiveTunnelsSection(
      {required this.tunnelService, required this.onOpen});
  final SshTunnelService tunnelService;
  final void Function(int port) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tunnelService,
      builder: (context, _) {
        final active = tunnelService.tunnelStatuses.entries
            .where((e) => e.value == TunnelStatus.active)
            .toList();
        if (active.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.tunnelActive,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...active.map((e) => _TunnelRow(
                  remotePort: e.key,
                  localPort: tunnelService.localPortOf(e.key)!,
                  onOpen: () => onOpen(e.key),
                  onStop: () => tunnelService.stopTunnel(e.key),
                )),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _TunnelRow extends StatelessWidget {
  const _TunnelRow({
    required this.remotePort,
    required this.localPort,
    required this.onOpen,
    required this.onStop,
  });
  final int remotePort;
  final int localPort;
  final VoidCallback onOpen;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.success),
          const SizedBox(width: 8),
          Text(':$remotePort → :$localPort',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 13)),
          const Spacer(),
          TextButton(
            onPressed: onStop,
            style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Text(l.tunnelStop, style: const TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: onOpen,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(l.open),
          ),
        ],
      ),
    );
  }
}

// ── 保存済みポートセクション ────────────────────────────────

class _SavedPortsSection extends StatefulWidget {
  const _SavedPortsSection(
      {required this.tunnelService, required this.onOpen});
  final SshTunnelService tunnelService;
  final void Function(int port) onOpen;

  @override
  State<_SavedPortsSection> createState() => _SavedPortsSectionState();
}

class _SavedPortsSectionState extends State<_SavedPortsSection> {
  PortTunnelConfigService? _configService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _configService = context.read<PortTunnelConfigService>();
    } catch (_) {
      // PortTunnelConfigService not in provider tree (e.g. demo mode)
      return;
    }
    if (_configService!.connectionId == null &&
        widget.tunnelService.connectionId.isNotEmpty) {
      _configService!.load(widget.tunnelService.connectionId);
    }
  }

  void _showAddDialog() {
    final portCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppLocalizations.of(context)!.addPort,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: portCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.portNumber,
                labelStyle: const TextStyle(
                    color: AppColors.textSecondary),
              ),
            ),
            TextField(
              controller: labelCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.portLabel,
                labelStyle: const TextStyle(
                    color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final port = int.tryParse(portCtrl.text.trim());
              if (port == null || port < 1 || port > 65535) return;
              final label = labelCtrl.text.trim().isEmpty
                  ? ':$port'
                  : labelCtrl.text.trim();
              final id = DateTime.now().millisecondsSinceEpoch.toString();
              _configService?.add(PortTunnelConfig(
                id: id,
                connectionId: widget.tunnelService.connectionId,
                remotePort: port,
                localPort: PortTunnelConfig.defaultLocalPort(port),
                label: label,
                autoConnect: false,
              ));
              Navigator.pop(ctx);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(AppLocalizations.of(context)!.addPort),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configService = _configService;
    if (configService == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: configService,
      builder: (context, _) {
        final configs = configService.configs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l.savedPorts,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_rounded,
                      size: 18, color: AppColors.primary),
                  onPressed: _showAddDialog,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (configs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l.portDetectedNone,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              )
            else
              ...configs.map((cfg) => _SavedPortRow(
                    config: cfg,
                    status: widget.tunnelService.statusOf(cfg.remotePort),
                    onToggle: () {
                      final s = widget.tunnelService.statusOf(cfg.remotePort);
                      if (s == TunnelStatus.active) {
                        widget.tunnelService.stopTunnel(cfg.remotePort);
                      } else {
                        widget.tunnelService
                            .startTunnel(cfg.remotePort)
                            .catchError((_) {});
                      }
                    },
                    onOpen: () => widget.onOpen(cfg.remotePort),
                    onDelete: () => configService.remove(cfg.id),
                    onAutoConnectChanged: (v) =>
                        configService.update(cfg.copyWith(autoConnect: v)),
                  )),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _SavedPortRow extends StatelessWidget {
  const _SavedPortRow({
    required this.config,
    required this.status,
    required this.onToggle,
    required this.onOpen,
    required this.onDelete,
    required this.onAutoConnectChanged,
  });

  final PortTunnelConfig config;
  final TunnelStatus status;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final ValueChanged<bool> onAutoConnectChanged;

  @override
  Widget build(BuildContext context) {
    final isActive = status == TunnelStatus.active;
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Switch(
            value: isActive,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.success,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(config.label,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                Text(':${config.remotePort}',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
          if (isActive)
            TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text(l.open, style: const TextStyle(fontSize: 12)),
            ),
          Checkbox(
            value: config.autoConnect,
            onChanged: (v) => onAutoConnectChanged(v ?? false),
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 16, color: AppColors.error),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
