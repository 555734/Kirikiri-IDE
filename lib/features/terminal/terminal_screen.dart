import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xterm/xterm.dart' hide TerminalController;

import '../../core/secure_storage_service.dart';
import '../../core/theme_service.dart';
import '../../theme/app_theme.dart';
import '../plugins/loaded_plugin.dart';
import '../plugins/tui_launcher.dart';
import '../plugins/widgets/plugin_command_chips.dart';
import '../plugins/widgets/plugin_toolbar_buttons.dart';
import '../preview/port_tunnel_config.dart';
import '../preview/port_tunnel_config_service.dart';
import '../preview/ssh_tunnel_service.dart';
import '../preview/web_preview_screen.dart';
import 'command_launcher.dart';
import 'ssh_service.dart';
import 'terminal_controller.dart';
import 'widgets/command_input_bar.dart';
import 'widgets/mobile_keyboard_bar.dart';

/// フルスクリーンターミナル（ショート動画スタイル）
///
/// 構成:
///   ┌──────────────────────────────┐
///   │ ← (back)         [●接続状態] │  ← 透明オーバーレイ
///   │                          [🌐]│
///   │       TerminalView            │  [📁] 右側アクションボタン
///   │                          [↺] │
///   │                          [A] │
///   ├──────────────────────────────┤
///   │         Plugin Chips          │
///   │         CommandInputBar       │
///   │         MobileKeyboardBar     │
///   └──────────────────────────────┘
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key, this.embedded = false});

  /// true のとき Scaffold をラップせず body のみを返す。
  /// Cloud Shell タブへ直接埋め込む場合に使用。
  final bool embedded;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with WidgetsBindingObserver {
  bool _keyboardVisible = false;

  TuiLauncher? _tuiLauncher;

  // ── フローティングコマンドバブル ─────────────────────────
  List<_FloatingCommand> _floatingCmds = [];
  bool _floatingEditMode = false;

  // ── UI 全体表示/非表示（イマーシブモード） ──────────────────
  bool _uiVisible = true;

  // ── 右アクションパネル位置（相対座標 0.0–1.0） ──────────
  double _panelRelX = 0.93;
  double _panelRelY = 0.60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TerminalController>().connect();
      _loadFloatingCmds();
      _loadPanelPosition();
    });
  }

  Future<void> _loadFloatingCmds() async {
    final raw = await SecureStorageService.instance.getFloatingCommands();
    if (raw == null || !mounted) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => _FloatingCommand.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() => _floatingCmds = list);
    } catch (_) {}
  }

  Future<void> _saveFloatingCmds() async {
    await SecureStorageService.instance.saveFloatingCommands(
      jsonEncode(_floatingCmds.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> _loadPanelPosition() async {
    final raw = await SecureStorageService.instance.getRightPanelPosition();
    if (raw == null || !mounted) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _panelRelX = (m['x'] as num).toDouble();
        _panelRelY = (m['y'] as num).toDouble();
      });
    } catch (_) {}
  }

  Future<void> _savePanelPosition() async {
    await SecureStorageService.instance.saveRightPanelPosition(
      jsonEncode({'x': _panelRelX, 'y': _panelRelY}),
    );
  }

  void _showAddCmdDialog(BuildContext context, BoxConstraints constraints) {
    final l = AppLocalizations.of(context)!;
    final labelCtrl = TextEditingController();
    final cmdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.commandButtonAdd,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: l.commandButtonLabel,
                counterText: '',
              ),
              maxLength: 12,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cmdCtrl,
              decoration: InputDecoration(labelText: l.commandButtonCommand),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final label = labelCtrl.text.trim();
              final command = cmdCtrl.text.trim();
              if (label.isEmpty || command.isEmpty) return;
              setState(() {
                _floatingCmds.add(_FloatingCommand(
                  id: '${DateTime.now().millisecondsSinceEpoch}',
                  label: label,
                  command: command,
                  relX: 0.15 + Random().nextDouble() * 0.55,
                  relY: 0.15 + Random().nextDouble() * 0.55,
                ));
              });
              _saveFloatingCmds();
              Navigator.pop(ctx);
            },
            child: Text(l.add),
          ),
        ],
      ),
    );
  }

  void _showEditCmdDialog(BuildContext context, _FloatingCommand cmd) {
    final l = AppLocalizations.of(context)!;
    final labelCtrl = TextEditingController(text: cmd.label);
    final cmdCtrl = TextEditingController(text: cmd.command);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.commandButtonEdit,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: l.commandButtonLabelShort,
                counterText: '',
              ),
              maxLength: 12,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cmdCtrl,
              decoration: InputDecoration(labelText: l.commandButtonCommand),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _floatingCmds.remove(cmd));
              _saveFloatingCmds();
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l.delete),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final label = labelCtrl.text.trim();
              final command = cmdCtrl.text.trim();
              if (label.isEmpty || command.isEmpty) return;
              setState(() {
                cmd.label = label;
                cmd.command = command;
              });
              _saveFloatingCmds();
              Navigator.pop(ctx);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    final visible = bottomInset > 100;
    if (_keyboardVisible != visible) {
      setState(() => _keyboardVisible = visible);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tuiLauncher?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = context.watch<ThemeService>().terminalFontSize;
    return Consumer<TerminalController>(
      builder: (context, controller, _) {
        final body = SafeArea(
          bottom: false,
          child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      // 上部オーバーレイ分のスペース（非 embedded かつ UI 表示時のみ）
                      if (!widget.embedded && _uiVisible) const SizedBox(height: 46),
                      Expanded(
                        child: _buildTerminalArea(context, controller, fontSize),
                      ),
                      if (_uiVisible)
                        PluginCommandChips(
                          onSend: (cmd) =>
                              controller.terminal.onOutput?.call(cmd),
                        ),
                      if (_uiVisible)
                        CommandInputBar(
                          enabled: controller.isConnected,
                          onSend: (data) =>
                              controller.terminal.onOutput?.call(data),
                        ),
                      if (_uiVisible)
                        MobileKeyboardBar(
                          onInput: controller.isConnected
                              ? (data) =>
                                  controller.terminal.onOutput?.call(data)
                              : (_) {},
                        ),
                    ],
                  ),
                ),

                // 非 embedded かつ UI 表示時のみトップバーを表示
                if (!widget.embedded && _uiVisible)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: AppColors.surface.withOpacity(0.95),
                      child: Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () async {
                                await controller.disconnect();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _ConnectionIndicator(
                              state: controller.connectionState),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              controller.workspaceId,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PluginToolbarButtons(
                            onCommandAction: (cmd) =>
                                controller.terminal.onOutput?.call(cmd),
                            onTuiAction: (plugin, entry) => _handleTuiAction(
                                context, controller, plugin, entry),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        );
        if (widget.embedded) return body;
        return Scaffold(
          backgroundColor: AppColors.terminalBackground,
          body: body,
        );
      },
    );
  }

  // ── ターミナル領域（右側アクションボタン含む） ─────────────

  Widget _buildTerminalArea(
      BuildContext context, TerminalController controller, double fontSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // ── ターミナル + オーバーレイ（内側 Stack） ──────────
            Positioned.fill(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TerminalView(
                      controller.terminal,
                      controller: controller.xtermController,
                      theme: _terminalTheme,
                      textStyle: TerminalStyle(fontSize: fontSize),
                      autofocus: !widget.embedded,
                      backgroundOpacity: 1.0,
                      simulateScroll: true,
                      onSecondaryTapDown: (details, offset) =>
                          _showContextMenu(
                              context, controller, details.globalPosition),
                    ),
                  ),
                  _CopyButton(controller: controller),
                  if (controller.connectionState ==
                      SshConnectionState.connecting)
                    _buildConnectingOverlay(context),
                  if (controller.connectionState == SshConnectionState.error)
                    _buildErrorOverlay(context, controller),
                ],
              ),
            ),

            // ── フローティングコマンドバブル ──────────────────────
            if (_uiVisible)
              for (final cmd in _floatingCmds)
                _buildOneBubble(context, controller, constraints, cmd),

            // 編集モード: 追加ボタン
            if (_uiVisible && _floatingEditMode)
              Positioned(
                left: 12,
                bottom: 12,
                child: GestureDetector(
                  onTap: () => _showAddCmdDialog(context, constraints),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.45),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 26),
                  ),
                ),
              ),

            // ── 右側アクションパネル（UI 表示時のみ） ──────────────
            if (_uiVisible)
            Builder(builder: (_) {
              const panelW = 60.0;
              final left = (_panelRelX * constraints.maxWidth - panelW / 2)
                  .clamp(4.0, constraints.maxWidth - panelW - 4);
              final top = (_panelRelY * constraints.maxHeight)
                  .clamp(4.0, constraints.maxHeight - 220.0);
              return Positioned(
                left: left,
                top: top,
                child: GestureDetector(
                  onPanUpdate: (d) => setState(() {
                    _panelRelX = (_panelRelX +
                            d.delta.dx / constraints.maxWidth)
                        .clamp(0.05, 0.97);
                    _panelRelY = (_panelRelY +
                            d.delta.dy / constraints.maxHeight)
                        .clamp(0.02, 0.90);
                  }),
                  onPanEnd: (_) => _savePanelPosition(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFEDD5D5), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ドラッグハンドル
                        Icon(Icons.drag_handle_rounded,
                            color: AppColors.primary.withOpacity(0.25),
                            size: 18),
                        const SizedBox(height: 2),
                        if (controller.isConnected)
                          _TikTokActionButton(
                            icon: Icons.open_in_browser_rounded,
                            label: AppLocalizations.of(context)!.preview,
                            onTap: () => _showPortPicker(context, controller),
                          ),
                        // コマンドランチャー
                        _TikTokActionButton(
                          icon: Icons.grid_view_rounded,
                          label: AppLocalizations.of(context)!.launcherTitle,
                          onTap: () =>
                              _showCommandLauncher(context, controller),
                        ),
                        // コマンド実行ボタン（プレビューの下）
                        _TikTokActionButton(
                          icon: Icons.play_arrow_rounded,
                          label: AppLocalizations.of(context)!.run,
                          color: AppColors.success,
                          onTap: () =>
                              controller.terminal.onOutput?.call('\n'),
                        ),
                        if (controller.workspaceId.contains('/'))
                          _TikTokActionButton(
                            icon: Icons.source_rounded,
                            label: AppLocalizations.of(context)!.repository,
                            onTap: () =>
                                _openGitHubRepo(controller.workspaceId),
                          ),
                        if (controller.connectionState ==
                                SshConnectionState.error ||
                            controller.connectionState ==
                                SshConnectionState.disconnected)
                          _TikTokActionButton(
                            icon: Icons.refresh_rounded,
                            label: AppLocalizations.of(context)!.reconnectButton,
                            color: AppColors.warning,
                            onTap: controller.reconnect,
                          ),
                        // 全バッファコピー
                        if (controller.isConnected)
                          _TikTokActionButton(
                            icon: Icons.copy_all_rounded,
                            label: AppLocalizations.of(context)!.copy,
                            onTap: () =>
                                _copyAllOutput(context, controller),
                          ),
                        // UI 全非表示ボタン
                        _TikTokActionButton(
                          icon: Icons.keyboard_hide_rounded,
                          label: '非表示',
                          color: AppColors.primary,
                          onTap: () => setState(() => _uiVisible = false),
                        ),
                        _TikTokActionButton(
                          icon: _floatingEditMode
                              ? Icons.check_circle_rounded
                              : Icons.widgets_outlined,
                          label: _floatingEditMode
                              ? AppLocalizations.of(context)!.buttonsDone
                              : AppLocalizations.of(context)!.buttonsEdit,
                          color: _floatingEditMode
                              ? AppColors.success
                              : AppColors.primary,
                          onTap: () => setState(
                              () => _floatingEditMode = !_floatingEditMode),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            // ── UI 非表示時の復元ボタン ──────────────────────────
            if (!_uiVisible)
              Positioned(
                bottom: 24,
                right: 16,
                child: GestureDetector(
                  onTap: () => setState(() => _uiVisible = true),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.75),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.menu_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOneBubble(
    BuildContext context,
    TerminalController controller,
    BoxConstraints constraints,
    _FloatingCommand cmd,
  ) {
    const bw = 56.0;
    const bh = 44.0;
    final left = (cmd.relX * constraints.maxWidth - bw / 2)
        .clamp(4.0, constraints.maxWidth - bw - 4);
    final top = (cmd.relY * constraints.maxHeight - bh / 2)
        .clamp(4.0, constraints.maxHeight - bh - 4);

    return Positioned(
      left: left,
      top: top,
      child: _FloatingCmdBubble(
        label: cmd.label,
        editMode: _floatingEditMode,
        onTap: _floatingEditMode
            ? () => _showEditCmdDialog(context, cmd)
            : () => controller.terminal.onOutput?.call('${cmd.command} '),
        onLongPress:
            _floatingEditMode ? null : () => setState(() => _floatingEditMode = true),
        onPanUpdate: _floatingEditMode
            ? (d) => setState(() {
                  cmd.relX =
                      (cmd.relX + d.delta.dx / constraints.maxWidth)
                          .clamp(0.05, 0.95);
                  cmd.relY =
                      (cmd.relY + d.delta.dy / constraints.maxHeight)
                          .clamp(0.05, 0.95);
                })
            : null,
        onPanEnd: _floatingEditMode ? (_) => _saveFloatingCmds() : null,
      ),
    );
  }

  // ── GitHubリポジトリを開く ──────────────────────────────

  void _openGitHubRepo(String workspaceId) {
    launchUrl(
      Uri.parse('https://github.com/$workspaceId'),
      mode: LaunchMode.externalApplication,
    );
  }

  // ── 全バッファコピー ──────────────────────────────────────

  Future<void> _copyAllOutput(
      BuildContext context, TerminalController controller) async {
    final text = controller.terminal.buffer.getText();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.copied),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ── 接続中オーバーレイ ────────────────────────────────────

  Widget _buildConnectingOverlay(BuildContext context) {
    return Container(
      color: AppColors.terminalBackground.withOpacity(0.88),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDD5D5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.sshConnecting,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(AppLocalizations.of(context)!.sshConnectingToServer,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // ── エラーオーバーレイ ────────────────────────────────────

  Widget _buildErrorOverlay(
      BuildContext context, TerminalController controller) {
    return Container(
      color: AppColors.terminalBackground.withOpacity(0.88),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 40),
              const SizedBox(height: 14),
              Text(AppLocalizations.of(context)!.connectionError,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: controller.reconnect,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context)!.reconnect),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () =>
                    _showSshLog(context, controller.sshLog),
                icon: Icon(Icons.list_alt_rounded,
                    size: 16,
                    color: AppColors.textMuted),
                label: Text(AppLocalizations.of(context)!.showSshLog,
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SSHログダイアログ ─────────────────────────────────────

  void _showSshLog(BuildContext context, List<String> logs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppLocalizations.of(context)!.sshLog,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 15)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: logs.isEmpty
              ? Center(
                  child: Text(AppLocalizations.of(context)!.noLogs,
                      style: const TextStyle(
                          color: AppColors.textMuted)))
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (_, i) => Text(
                    logs[i],
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.close,
                style: const TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // ── コンテキストメニュー ──────────────────────────────────

  void _showContextMenu(
      BuildContext context, TerminalController controller, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      color: AppColors.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: [
        PopupMenuItem(
          child: Row(children: [
            const Icon(Icons.content_paste_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context)!.paste,
                style: const TextStyle(color: AppColors.textPrimary)),
          ]),
          onTap: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (data?.text != null) {
              controller.terminal.onOutput?.call(data!.text!);
            }
          },
        ),
        PopupMenuItem(
          child: Row(children: [
            const Icon(Icons.content_copy_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context)!.copy,
                style: const TextStyle(color: AppColors.textPrimary)),
          ]),
          onTap: () => _copySelection(context, controller),
        ),
      ],
    );
  }

  void _copySelection(
      BuildContext context, TerminalController controller) async {
    final range = controller.xtermController.selection;
    if (range == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.dragToSelect),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final text = controller.terminal.buffer.getText(range);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.copied),
            duration: const Duration(seconds: 1)),
      );
    }
  }

  // ── コマンドランチャー ─────────────────────────────────────

  void _showCommandLauncher(
      BuildContext context, TerminalController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CommandLauncherSheet(controller: controller),
    );
  }

  // ── Webプレビュー ─────────────────────────────────────────

  void _showPortPicker(BuildContext context, TerminalController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PortPickerSheet(controller: controller),
    );
  }

  // ── TUIアクション ─────────────────────────────────────────

  Future<void> _handleTuiAction(
    BuildContext context,
    TerminalController controller,
    LoadedPlugin plugin,
    String entryScript,
  ) async {
    if (!controller.isConnected) {
      return;
    }

    _tuiLauncher ??= TuiLauncher(sshService: controller.sshService);
    double progress = 0;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(AppLocalizations.of(context)!.tuiUploading,
                style: const TextStyle(color: AppColors.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceHighlight,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
                const SizedBox(height: 8),
                Text('${(progress * 100).toInt()}%',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    try {
      await _tuiLauncher!.launch(
        plugin: plugin,
        entryScript: entryScript,
        onUploadProgress: (p) => progress = p,
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.tuiLaunchError(e.toString()))));
        return;
      }
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}

// ── 選択テキストコピーボタン ──────────────────────────────────

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.controller});
  final TerminalController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.xtermController,
      builder: (context, _) {
        final range = controller.xtermController.selection;
        if (range == null) return const SizedBox.shrink();
        return Positioned(
          top: 44,
          right: 8,
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            elevation: 4,
            shadowColor: Colors.black45,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                FocusScope.of(context).unfocus();
                final text =
                    controller.terminal.buffer.getText(range);
                await Clipboard.setData(ClipboardData(text: text));
                controller.xtermController.clearSelection();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(AppLocalizations.of(context)!.copied),
                        duration: const Duration(seconds: 1)),
                  );
                }
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(AppLocalizations.of(context)!.copy,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── TikTokスタイル アクションボタン ───────────────────────────

class _TikTokActionButton extends StatefulWidget {
  const _TikTokActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  State<_TikTokActionButton> createState() => _TikTokActionButtonState();
}

class _TikTokActionButtonState extends State<_TikTokActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.82 : 1.0,
        duration: const Duration(milliseconds: 60),
        child: Container(
          width: 52,
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: widget.color.withOpacity(0.20), width: 1),
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.color.withOpacity(0.80),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ターミナルテーマ (Dark Red-White) ─────────────────────────

const _terminalTheme = TerminalTheme(
  cursor:     AppColors.terminalCursor,      // #DC2626 赤
  selection:  AppColors.terminalSelection,   // #40DC2626 半透明赤
  foreground: AppColors.terminalForeground,  // #FFFFFF 白
  background: AppColors.terminalBackground,  // #000000 黒
  black:       Color(0xFF1E1E2E),
  red:         Color(0xFFDC2626), // ブランドレッド
  green:       Color(0xFF50FA7B),
  yellow:      Color(0xFFF1FA8C),
  blue:        Color(0xFF6272A4),
  magenta:     Color(0xFFFF79C6),
  cyan:        Color(0xFF8BE9FD),
  white:       Color(0xFFBFBFBF),
  brightBlack:   Color(0xFF6272A4),
  brightRed:     Color(0xFFEF4444), // primaryLight
  brightGreen:   Color(0xFF69FF94),
  brightYellow:  Color(0xFFFFFFA5),
  brightBlue:    Color(0xFFD6ACFF),
  brightMagenta: Color(0xFFFF92DF),
  brightCyan:    Color(0xFFA4FFFF),
  brightWhite:   Color(0xFFFFFFFF),
  searchHitBackground:        Color(0x55DC2626),
  searchHitBackgroundCurrent: Color(0xFFDC2626),
  searchHitForeground:        Color(0xFFFFFFFF),
);

// ── 接続状態インジケーター ────────────────────────────────────

class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator({required this.state});
  final SshConnectionState state;

  Color get _color => switch (state) {
        SshConnectionState.connected => AppColors.success,
        SshConnectionState.connecting => AppColors.warning,
        SshConnectionState.error => AppColors.error,
        SshConnectionState.disconnected => AppColors.textMuted,
      };

  String get _label => switch (state) {
        SshConnectionState.connected => '接続済み',
        SshConnectionState.connecting => '接続中',
        SshConnectionState.error => 'エラー',
        SshConnectionState.disconnected => '切断',
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            boxShadow: state == SshConnectionState.connected
                ? [BoxShadow(color: _color.withOpacity(0.5), blurRadius: 4)]
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          _label,
          style: TextStyle(
              color: _color, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ── フローティングコマンドモデル ──────────────────────────────

class _FloatingCommand {
  _FloatingCommand({
    required this.id,
    required this.label,
    required this.command,
    this.relX = 0.5,
    this.relY = 0.5,
  });

  final String id;
  String label;
  String command;
  double relX;
  double relY;

  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'command': command, 'x': relX, 'y': relY};

  factory _FloatingCommand.fromJson(Map<String, dynamic> j) => _FloatingCommand(
        id: j['id'] as String,
        label: j['label'] as String,
        command: j['command'] as String,
        relX: (j['x'] as num).toDouble(),
        relY: (j['y'] as num).toDouble(),
      );
}

// ── フローティングコマンドバブルウィジェット ──────────────────

class _FloatingCmdBubble extends StatefulWidget {
  const _FloatingCmdBubble({
    required this.label,
    required this.editMode,
    required this.onTap,
    this.onLongPress,
    this.onPanUpdate,
    this.onPanEnd,
  });

  final String label;
  final bool editMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(DragUpdateDetails)? onPanUpdate;
  final void Function(DragEndDetails)? onPanEnd;

  @override
  State<_FloatingCmdBubble> createState() => _FloatingCmdBubbleState();
}

class _FloatingCmdBubbleState extends State<_FloatingCmdBubble> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      onLongPress: widget.onLongPress != null
          ? () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            }
          : null,
      onPanUpdate: widget.onPanUpdate,
      onPanEnd: widget.onPanEnd,
      child: AnimatedScale(
        scale: _pressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 60),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minWidth: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: widget.editMode
                ? const Color(0xCC2563EB)
                : const Color(0xBB0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.editMode
                  ? Colors.white.withOpacity(0.55)
                  : Colors.white.withOpacity(0.28),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.editMode
                        ? const Color(0xFF2563EB)
                        : Colors.black)
                    .withOpacity(widget.editMode ? 0.5 : 0.4),
                blurRadius: widget.editMode ? 12 : 7,
                spreadRadius: widget.editMode ? 2 : 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.editMode) ...[
                const Icon(Icons.drag_indicator_rounded,
                    size: 13, color: Colors.white60),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
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

// ── ポートピッカーシート ──────────────────────────────────────

class _PortPickerSheet extends StatefulWidget {
  const _PortPickerSheet({required this.controller});
  final TerminalController controller;

  @override
  State<_PortPickerSheet> createState() => _PortPickerSheetState();
}

class _PortPickerSheetState extends State<_PortPickerSheet> {
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

// ══════════════════════════════════════════════════════════════
// コマンドランチャー
// ══════════════════════════════════════════════════════════════

class _CommandLauncherSheet extends StatefulWidget {
  const _CommandLauncherSheet({required this.controller});
  final TerminalController controller;

  @override
  State<_CommandLauncherSheet> createState() => _CommandLauncherSheetState();
}

class _CommandLauncherSheetState extends State<_CommandLauncherSheet> {
  List<LauncherCategory> _categories = [];
  int _selectedIndex = 0;

  static const _presetIcons = ['📁', '🐙', '📦', '🐳', '⚡', '🔧', '🚀', '🌿'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw =
        await SecureStorageService.instance.getCommandLauncher();
    if (raw != null && raw.isNotEmpty) {
      try {
        final cats = LauncherCategory.decodeList(raw);
        if (mounted) setState(() => _categories = cats);
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    await SecureStorageService.instance
        .saveCommandLauncher(LauncherCategory.encodeList(_categories));
  }

  void _runCommand(String command) {
    Navigator.pop(context);
    widget.controller.terminal.onOutput?.call('$command\n');
  }

  void _showAddCategoryDialog() {
    final labelCtrl = TextEditingController();
    String selectedIcon = _presetIcons.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(AppLocalizations.of(context)!.launcherAddCategory,
              style: const TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context)!.launcherCategoryLabel,
                  labelStyle: const TextStyle(
                      color: AppColors.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.surfaceHighlight)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.launcherIcon,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _presetIcons
                    .map((emoji) => GestureDetector(
                          onTap: () => setD(() => selectedIcon = emoji),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: selectedIcon == emoji
                                  ? AppColors.primary.withOpacity(0.12)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                              border: selectedIcon == emoji
                                  ? Border.all(
                                      color: AppColors.primary, width: 1.5)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 18)),
                          ),
                        ))
                    .toList(),
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
                final label = labelCtrl.text.trim();
                if (label.isEmpty) return;
                final id =
                    DateTime.now().millisecondsSinceEpoch.toString();
                setState(() {
                  _categories = [
                    ..._categories,
                    LauncherCategory(
                        id: id,
                        label: label,
                        icon: selectedIcon,
                        commands: []),
                  ];
                  _selectedIndex = _categories.length - 1;
                });
                _save();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: Text(AppLocalizations.of(context)!.launcherAddCategory),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCommandDialog() {
    if (_categories.isEmpty) return;
    final labelCtrl = TextEditingController();
    final commandCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppLocalizations.of(context)!.launcherAddCommand,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.launcherCommandLabel,
                labelStyle: const TextStyle(
                    color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: AppColors.surfaceHighlight)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commandCtrl,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.launcherCommandHint,
                labelStyle: const TextStyle(
                    color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: AppColors.surfaceHighlight)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary)),
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
              final label = labelCtrl.text.trim();
              final command = commandCtrl.text.trim();
              if (label.isEmpty || command.isEmpty) return;
              final id =
                  DateTime.now().millisecondsSinceEpoch.toString();
              final cat = _categories[_selectedIndex];
              final updated = cat.copyWith(commands: [
                ...cat.commands,
                LauncherCommand(id: id, label: label, command: command),
              ]);
              setState(() {
                _categories = [
                  ..._categories.sublist(0, _selectedIndex),
                  updated,
                  ..._categories.sublist(_selectedIndex + 1),
                ];
              });
              _save();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            child: Text(AppLocalizations.of(context)!.launcherAddCommand),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(int index) {
    setState(() {
      _categories = [
        ..._categories.sublist(0, index),
        ..._categories.sublist(index + 1),
      ];
      if (_selectedIndex >= _categories.length) {
        _selectedIndex = (_categories.length - 1).clamp(0, 9999);
      }
    });
    _save();
  }

  void _deleteCommand(int catIndex, int cmdIndex) {
    final cat = _categories[catIndex];
    final updatedCmds = [...cat.commands]..removeAt(cmdIndex);
    setState(() {
      _categories = [
        ..._categories.sublist(0, catIndex),
        cat.copyWith(commands: updatedCmds),
        ..._categories.sublist(catIndex + 1),
      ];
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final maxH = MediaQuery.of(context).size.height * 0.72;

    return ConstrainedBox(
      constraints: BoxConstraints(
          maxHeight: maxH + MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ヘッダー ──
            Row(
              children: [
                const Icon(Icons.grid_view_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(l.launcherTitle,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showAddCategoryDialog,
                  icon: const Icon(Icons.add_rounded,
                      size: 16, color: AppColors.primary),
                  label: Text(l.launcherAddCategory,
                      style: const TextStyle(
                          color: AppColors.primary, fontSize: 12)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── カテゴリタブ ──
            if (_categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.grid_view_outlined,
                          color: AppColors.primary.withOpacity(0.3),
                          size: 40),
                      const SizedBox(height: 8),
                      Text(l.launcherEmptyCategories,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddCategoryDialog,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(l.launcherAddCategory),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // カテゴリチップ横スクロール
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final cat = _categories[i];
                    final isSelected = i == _selectedIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = i),
                      onLongPress: () => _confirmDeleteCategory(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.12)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.5)
                                : AppColors.surfaceHighlight,
                          ),
                        ),
                        child: Text(
                          '${cat.icon} ${cat.label}',
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // ── コマンド一覧 ──
              Flexible(
                child: Builder(builder: (ctx) {
                  final cat = _categories[_selectedIndex];
                  if (cat.commands.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l.launcherEmptyCommands,
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _showAddCommandDialog,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text(l.launcherAddCommand),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: cat.commands.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == cat.commands.length) {
                        // 追加ボタン
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: TextButton.icon(
                            onPressed: _showAddCommandDialog,
                            icon: const Icon(Icons.add_rounded,
                                size: 15, color: AppColors.primary),
                            label: Text(l.launcherAddCommand,
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12)),
                            style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4)),
                          ),
                        );
                      }
                      final cmd = cat.commands[i];
                      return _CommandRow(
                        command: cmd,
                        onRun: () => _runCommand(cmd.command),
                        onDelete: () =>
                            _deleteCommand(_selectedIndex, i),
                      );
                    },
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(int index) {
    final cat = _categories[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppLocalizations.of(context)!.launcherDeleteCategory,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text('「${cat.icon} ${cat.label}」を削除しますか？',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCategory(index);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }
}

class _CommandRow extends StatefulWidget {
  const _CommandRow({
    required this.command,
    required this.onRun,
    required this.onDelete,
  });

  final LauncherCommand command;
  final VoidCallback onRun;
  final VoidCallback onDelete;

  @override
  State<_CommandRow> createState() => _CommandRowState();
}

class _CommandRowState extends State<_CommandRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onRun,
          onLongPress: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceHighlight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.terminal_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.command.label,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          Text(widget.command.command,
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: widget.onRun,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(l.launcherRun),
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 14, color: Colors.redAccent),
                        label: Text(l.delete,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12)),
                        style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
