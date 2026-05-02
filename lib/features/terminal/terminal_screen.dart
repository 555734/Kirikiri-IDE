import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xterm/xterm.dart' hide TerminalController;

import '../../core/secure_storage_service.dart';
import '../../theme/app_theme.dart';
import '../plugins/loaded_plugin.dart';
import '../plugins/tui_launcher.dart';
import '../plugins/widgets/plugin_command_chips.dart';
import '../plugins/widgets/plugin_toolbar_buttons.dart';
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
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with WidgetsBindingObserver {
  bool _keyboardVisible = false;
  double _fontSize = 13;

  TuiLauncher? _tuiLauncher;

  // ── フローティングコマンドバブル ─────────────────────────
  List<_FloatingCommand> _floatingCmds = [];
  bool _floatingEditMode = false;

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
    return Consumer<TerminalController>(
      builder: (context, controller, _) {
        return Scaffold(
          backgroundColor: AppColors.terminalBackground,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // ── メインコンテンツ列（Stackを全体に埋める）────────
                Positioned.fill(
                  child: Column(
                    children: [
                      const SizedBox(height: 46), // 上部オーバーレイ分のスペース
                      // ターミナル領域（右側アクションボタンも内包）
                      Expanded(
                        child: _buildTerminalArea(context, controller),
                      ),
                      PluginCommandChips(
                        onSend: (cmd) =>
                            controller.terminal.onOutput?.call(cmd),
                      ),
                      CommandInputBar(
                        enabled: controller.isConnected,
                        onSend: (data) =>
                            controller.terminal.onOutput?.call(data),
                      ),
                      MobileKeyboardBar(
                        onInput: controller.isConnected
                            ? (data) =>
                                controller.terminal.onOutput?.call(data)
                            : (_) {},
                      ),
                    ],
                  ),
                ),

                // ── トップオーバーレイ: 戻るボタン + 接続状態 ─────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: const Color(0xD0161B22),
                    child: Row(
                    children: [
                      // 戻るボタン（左上）
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
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 接続状態インジケーター
                      _ConnectionIndicator(
                          state: controller.connectionState),
                      const SizedBox(width: 6),
                      // ワークスペース名
                      Expanded(
                        child: Text(
                          controller.workspaceId,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // プラグインツールバーボタン
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
          ),
        );
      },
    );
  }

  // ── ターミナル領域（右側アクションボタン含む） ─────────────

  Widget _buildTerminalArea(
      BuildContext context, TerminalController controller) {
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
                      textStyle: TerminalStyle(fontSize: _fontSize),
                      autofocus: true,
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
            for (final cmd in _floatingCmds)
              _buildOneBubble(context, controller, constraints, cmd),

            // 編集モード: 追加ボタン
            if (_floatingEditMode)
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

            // ── 右側アクションパネル（ドラッグで移動可能） ────────
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
                      color: const Color(0xCC161B22),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ドラッグハンドル
                        const Icon(Icons.drag_handle_rounded,
                            color: Colors.white24, size: 18),
                        const SizedBox(height: 2),
                        if (controller.webHost != null)
                          _TikTokActionButton(
                            icon: Icons.open_in_browser_rounded,
                            label: AppLocalizations.of(context)!.preview,
                            onTap: () => _showPortPicker(
                                context, controller.webHost!),
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
                        _TikTokActionButton(
                          icon: _floatingEditMode
                              ? Icons.check_circle_rounded
                              : Icons.widgets_outlined,
                          label: _floatingEditMode
                              ? AppLocalizations.of(context)!.buttonsDone
                              : AppLocalizations.of(context)!.buttonsEdit,
                          color: _floatingEditMode
                              ? AppColors.success
                              : Colors.white,
                          onTap: () => setState(
                              () => _floatingEditMode = !_floatingEditMode),
                        ),
                        _TikTokFontSizeButton(
                          fontSize: _fontSize,
                          onChanged: (size) =>
                              setState(() => _fontSize = size),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
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

  // ── 接続中オーバーレイ ────────────────────────────────────

  Widget _buildConnectingOverlay(BuildContext context) {
    return Container(
      color: AppColors.terminalBackground.withOpacity(0.88),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.sshConnecting,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(AppLocalizations.of(context)!.sshConnectingToServer,
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
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
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.error.withOpacity(0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 40),
              const SizedBox(height: 14),
              Text(AppLocalizations.of(context)!.connectionError,
                  style: const TextStyle(
                    color: AppColors.errorLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 13),
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
                icon: const Icon(Icons.list_alt_rounded,
                    size: 16, color: Colors.white38),
                label: Text(AppLocalizations.of(context)!.showSshLog,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
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
        backgroundColor: const Color(0xFF161B22),
        title: Text(AppLocalizations.of(context)!.sshLog,
            style: const TextStyle(color: Colors.white, fontSize: 15)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: logs.isEmpty
              ? Center(
                  child: Text(AppLocalizations.of(context)!.noLogs,
                      style: const TextStyle(color: Colors.white38)))
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (_, i) => Text(
                    logs[i],
                    style: const TextStyle(
                        color: Colors.white60,
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
      color: const Color(0xFF1C2128),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: [
        PopupMenuItem(
          child: Row(children: [
            const Icon(Icons.content_paste_rounded,
                size: 16, color: Colors.white54),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context)!.paste,
                style: const TextStyle(color: Colors.white)),
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
                size: 16, color: Colors.white54),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context)!.copy,
                style: const TextStyle(color: Colors.white)),
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

  // ── Webプレビュー ─────────────────────────────────────────

  void _showPortPicker(BuildContext context, String webHost) {
    final portCtrl = TextEditingController();
    const commonPorts = [3000, 4200, 5000, 5173, 8000, 8080];

    void openPreview(int port) {
      final url = 'https://$port-$webHost';
      launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.portPickerTitle,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(AppLocalizations.of(context)!.portPickerBody,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 12)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: commonPorts
                  .map((port) => ActionChip(
                        label: Text('$port',
                            style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace')),
                        backgroundColor:
                            AppColors.primary.withOpacity(0.2),
                        side: BorderSide(
                            color: AppColors.primary.withOpacity(0.6)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          openPreview(port);
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: portCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        color: Colors.white, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.portPickerCustom,
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.4)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.07),
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
                    final port = int.tryParse(portCtrl.text.trim());
                    if (port == null || port < 1 || port > 65535) return;
                    Navigator.pop(ctx);
                    openPreview(port);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: Text(AppLocalizations.of(context)!.open),
                ),
              ],
            ),
          ],
        ),
      ),
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
            backgroundColor: const Color(0xFF161B22),
            title: Text(AppLocalizations.of(context)!.tuiUploading,
                style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
                const SizedBox(height: 8),
                Text('${(progress * 100).toInt()}%',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
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

class _TikTokActionButton extends StatelessWidget {
  const _TikTokActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.85),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ── フォントサイズボタン（TikTokスタイル）──────────────────────

class _TikTokFontSizeButton extends StatelessWidget {
  const _TikTokFontSizeButton({
    required this.fontSize,
    required this.onChanged,
  });

  final double fontSize;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _showSizeSheet(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${fontSize.toInt()}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.fontSizeLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showSizeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.fontSizeLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [10, 11, 12, 13, 14, 16, 18, 20]
                  .map((size) => GestureDetector(
                        onTap: () {
                          onChanged(size.toDouble());
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 52,
                          height: 44,
                          decoration: BoxDecoration(
                            color: fontSize == size
                                ? AppColors.primary
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${size}px',
                            style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 13),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── ターミナルテーマ (Light Red-White) ────────────────────────

const _terminalTheme = TerminalTheme(
  cursor: AppColors.terminalCursor,
  selection: AppColors.terminalSelection,
  foreground: Color(0xFF24292E),
  background: AppColors.terminalBackground,
  black: Color(0xFF24292E),
  red: Color(0xFFCF222E),
  green: Color(0xFF116329),
  yellow: Color(0xFF953800),
  blue: Color(0xFF0550AE),
  magenta: Color(0xFF6639BA),
  cyan: Color(0xFF1B7C83),
  white: Color(0xFF6E7781),
  brightBlack: Color(0xFF57606A),
  brightRed: Color(0xFFA40E26),
  brightGreen: Color(0xFF1A7F37),
  brightYellow: Color(0xFFCA8A04),
  brightBlue: Color(0xFF218BFF),
  brightMagenta: Color(0xFF8250DF),
  brightCyan: Color(0xFF3192AA),
  brightWhite: Color(0xFF24292E),
  searchHitBackground: Color(0x55DC2626),
  searchHitBackgroundCurrent: Color(0xFFDC2626),
  searchHitForeground: Color(0xFFFFFFFF),
);

// ── 接続状態インジケーター ────────────────────────────────────

class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator({required this.state});
  final SshConnectionState state;

  Color get _color => switch (state) {
        SshConnectionState.connected => AppColors.success,
        SshConnectionState.connecting => AppColors.warning,
        SshConnectionState.error => AppColors.error,
        SshConnectionState.disconnected => Colors.white38,
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
