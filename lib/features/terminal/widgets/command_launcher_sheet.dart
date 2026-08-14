import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';

import '../../../core/secure_storage_service.dart';
import '../../../theme/app_theme.dart';
import '../command_launcher.dart';
import '../terminal_controller.dart';

// ══════════════════════════════════════════════════════════════
// コマンドランチャー
// ══════════════════════════════════════════════════════════════

class CommandLauncherSheet extends StatefulWidget {
  const CommandLauncherSheet({required this.controller});
  final TerminalController controller;

  @override
  State<CommandLauncherSheet> createState() => CommandLauncherSheetState();
}

class CommandLauncherSheetState extends State<CommandLauncherSheet> {
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
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppLocalizations.of(context)!.launcherDeleteCategory,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
            '「${cat.icon} ${cat.label}」${l.launcherDeleteCategoryConfirm}',
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
