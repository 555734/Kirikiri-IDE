import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xterm/xterm.dart' hide TerminalController;

import '../../core/known_hosts_service.dart';
import '../../core/secure_storage_service.dart';
import '../../core/theme_service.dart';
import '../../theme/app_theme.dart';
import '../plugins/loaded_plugin.dart';
import '../plugins/tui_launcher.dart';
import '../plugins/widgets/plugin_command_chips.dart';
import '../plugins/widgets/plugin_toolbar_buttons.dart';
import 'ssh_service.dart';
import 'terminal_controller.dart';
import 'widgets/command_input_bar.dart';
import 'widgets/command_launcher_sheet.dart';
import 'widgets/connection_indicator.dart';
import 'widgets/floating_command_bubble.dart';
import 'widgets/mobile_keyboard_bar.dart';
import 'widgets/port_picker_sheet.dart';
import 'widgets/terminal_action_buttons.dart';
import 'widgets/terminal_theme.dart';

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
  List<FloatingCommand> _floatingCmds = [];
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
      final controller = context.read<TerminalController>();
      // ホスト鍵の確認ダイアログを接続前に登録する。未登録のまま接続すると
      // 未知のホスト鍵はすべて拒否される（SshService のフェイルセーフ）。
      controller.onHostkeyPrompt = _confirmHostkey;
      controller.messages = TerminalMessages(
        describeFailure: _localizeFailure,
        reconnecting: () => AppLocalizations.of(context)!.sshReconnecting,
      );
      controller.connect();
      _loadFloatingCmds();
      _loadPanelPosition();
    });
  }

  Future<void> _loadFloatingCmds() async {
    final raw = await SecureStorageService.instance.getFloatingCommands();
    if (raw == null || !mounted) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => FloatingCommand.fromJson(e as Map<String, dynamic>))
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
                _floatingCmds.add(FloatingCommand(
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

  void _showEditCmdDialog(BuildContext context, FloatingCommand cmd) {
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // iOS はバックグラウンドでソケットを維持できないため、復帰時は
    // 切れている前提で繋ぎ直しを試みる。
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<TerminalController>().onAppResumed();
    }
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
                          ConnectionIndicator(
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
                      theme: kTerminalTheme,
                      textStyle: TerminalStyle(fontSize: fontSize),
                      autofocus: !widget.embedded,
                      backgroundOpacity: 1.0,
                      simulateScroll: true,
                      onSecondaryTapDown: (details, offset) =>
                          _showContextMenu(
                              context, controller, details.globalPosition),
                    ),
                  ),
                  CopyButton(controller: controller),
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
                          TerminalActionButton(
                            icon: Icons.open_in_browser_rounded,
                            label: AppLocalizations.of(context)!.preview,
                            onTap: () => _showPortPicker(context, controller),
                          ),
                        // コマンドランチャー
                        TerminalActionButton(
                          icon: Icons.grid_view_rounded,
                          label: AppLocalizations.of(context)!.launcherTitle,
                          onTap: () =>
                              _showCommandLauncher(context, controller),
                        ),
                        // コマンド実行ボタン（プレビューの下）
                        TerminalActionButton(
                          icon: Icons.play_arrow_rounded,
                          label: AppLocalizations.of(context)!.run,
                          color: AppColors.success,
                          onTap: () =>
                              controller.terminal.onOutput?.call('\n'),
                        ),
                        if (controller.workspaceId.contains('/'))
                          TerminalActionButton(
                            icon: Icons.source_rounded,
                            label: AppLocalizations.of(context)!.repository,
                            onTap: () =>
                                _openGitHubRepo(controller.workspaceId),
                          ),
                        if (controller.connectionState ==
                                SshConnectionState.error ||
                            controller.connectionState ==
                                SshConnectionState.disconnected)
                          TerminalActionButton(
                            icon: Icons.refresh_rounded,
                            label: AppLocalizations.of(context)!.reconnectButton,
                            color: AppColors.warning,
                            onTap: () => _reconnect(controller),
                          ),
                        // 全バッファコピー
                        if (controller.isConnected)
                          TerminalActionButton(
                            icon: Icons.copy_all_rounded,
                            label: AppLocalizations.of(context)!.copy,
                            onTap: () =>
                                _copyAllOutput(context, controller),
                          ),
                        // UI 全非表示ボタン
                        TerminalActionButton(
                          icon: Icons.keyboard_hide_rounded,
                          label: AppLocalizations.of(context)!.hideUi,
                          color: AppColors.primary,
                          onTap: () => setState(() => _uiVisible = false),
                        ),
                        TerminalActionButton(
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
    FloatingCommand cmd,
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
      child: FloatingCmdBubble(
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
              if (controller.failure != null) ...[
                const SizedBox(height: 8),
                Text(
                  _localizeFailure(controller.failure!),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _reconnect(controller),
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

  void _reconnect(TerminalController controller) {
    controller.reconnect(
        notice: AppLocalizations.of(context)!.sshReconnecting);
  }

  // ── 接続失敗メッセージのローカライズ ──────────────────────

  /// SshFailure を表示用の文言に変換する。技術的な詳細は括弧で添える。
  String _localizeFailure(SshFailure failure) {
    final l = AppLocalizations.of(context)!;
    final message = switch (failure.kind) {
      SshFailureKind.hostkeyUnconfirmed => l.sshErrorHostkeyUnconfirmed,
      SshFailureKind.hostkeyChanged => l.sshErrorHostkeyChanged,
      SshFailureKind.hostkeyRejected => l.sshErrorHostkeyRejected,
      SshFailureKind.hostkeyInvalid => l.sshErrorHostkeyInvalid,
      SshFailureKind.authFailed => l.sshErrorAuthFailed,
      SshFailureKind.authRejected => l.sshErrorAuthRejected,
      SshFailureKind.connectionFailed => l.sshErrorConnectionFailed,
    };
    final detail = failure.detail;
    return detail == null ? message : '$message ($detail)';
  }

  // ── ホスト鍵確認ダイアログ ────────────────────────────────

  /// 未知・変更されたホスト鍵をユーザーに提示し、受け入れ可否を返す。
  /// ダイアログを閉じられた場合は拒否として扱う。
  Future<bool> _confirmHostkey(HostkeyRequest request) async {
    if (!mounted) return false;
    final changed = request.verdict == HostkeyVerdict.changed;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx)!;
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(
                changed
                    ? Icons.gpp_maybe_rounded
                    : Icons.vpn_key_rounded,
                color: changed ? AppColors.error : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  changed ? l.hostkeyChangedTitle : l.hostkeyUnknownTitle,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 15),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  changed
                      ? l.hostkeyChangedBody(request.hostLabel)
                      : l.hostkeyUnknownBody(request.hostLabel),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _hostkeyField(l.hostkeyTypeLabel, request.keyType),
                const SizedBox(height: 8),
                _hostkeyField(
                    l.hostkeyFingerprintLabel, request.fingerprint),
                if (request.knownFingerprint != null) ...[
                  const SizedBox(height: 8),
                  _hostkeyField(l.hostkeyKnownFingerprintLabel,
                      request.knownFingerprint!),
                ],
              ],
            ),
          ),
          // 鍵が変更されている場合は「信頼する」を目立たせず、
          // 安全側の選択肢（接続しない）を強調する
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                l.hostkeyTrustButton,
                style: TextStyle(
                  color:
                      changed ? AppColors.textMuted : AppColors.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                l.hostkeyRejectButton,
                style: TextStyle(
                  color: changed
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight:
                      changed ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        );
      },
    );
    return accepted ?? false;
  }

  Widget _hostkeyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      ],
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
      builder: (ctx) => CommandLauncherSheet(controller: controller),
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
      builder: (ctx) => PortPickerSheet(controller: controller),
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
