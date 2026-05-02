import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirikiri/l10n/app_localizations.dart';

import '../../../core/secure_storage_service.dart';
import '../../../theme/app_theme.dart';

/// ターミナル下部のコマンド入力バー
///
/// 機能:
///   - テキスト入力フィールド + 送信ボタン
///   - ★ボタンで現在のコマンドをお気に入りに登録
///   - 入力中はお気に入りをフィルタして候補チップを表示（予測変換風）
///   - 未入力時はお気に入り全件を表示
///   - 候補チップのロングプレスで削除
class CommandInputBar extends StatefulWidget {
  const CommandInputBar({super.key, required this.onSend, this.enabled = true});

  final void Function(String data) onSend;
  final bool enabled;

  @override
  State<CommandInputBar> createState() => _CommandInputBarState();
}

class _CommandInputBarState extends State<CommandInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<String> _favorites = [];
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _controller.addListener(_updateSuggestions);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateSuggestions);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final raw = await SecureStorageService.instance.getTerminalFavorites();
    if (raw != null && mounted) {
      final list = (jsonDecode(raw) as List).cast<String>();
      setState(() {
        _favorites = list;
        _updateSuggestions();
      });
    }
  }

  Future<void> _saveFavorites() async {
    await SecureStorageService.instance
        .saveTerminalFavorites(jsonEncode(_favorites));
  }

  void _updateSuggestions() {
    final text = _controller.text.trim();
    setState(() {
      if (text.isEmpty) {
        _suggestions = _favorites.take(8).toList();
      } else {
        _suggestions = _favorites
            .where((f) => f.toLowerCase().contains(text.toLowerCase()))
            .take(8)
            .toList();
      }
    });
  }

  void _send() {
    final text = _controller.text;
    if (text.isEmpty) return;
    widget.onSend('$text\n');
    _controller.clear();
  }

  void _fillInput(String cmd) {
    _controller.text = cmd;
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: cmd.length));
    _focusNode.requestFocus();
  }

  void _addToFavorites() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final l = AppLocalizations.of(context)!;
    if (_favorites.contains(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.favoriteAlreadyExists),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _favorites.insert(0, text);
      if (_favorites.length > 100) _favorites = _favorites.take(100).toList();
      _updateSuggestions();
    });
    _saveFavorites();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.favoriteAdded),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: l.undo,
          onPressed: () {
            setState(() {
              _favorites.remove(text);
              _updateSuggestions();
            });
            _saveFavorites();
          },
        ),
      ),
    );
  }

  void _removeFromFavorites(String cmd) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppLocalizations.of(context)!.deleteFavorite,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        content: Text(
          cmd,
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _favorites.remove(cmd);
                _updateSuggestions();
              });
              _saveFavorites();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  bool get _isFavorite => _favorites.contains(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 候補チップ行 ─────────────────────────────
        if (_suggestions.isNotEmpty) _buildSuggestions(),

        // ── 入力フィールド行 ──────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: AppColors.terminalBackground,
            border: Border(
              top: BorderSide(color: Color(0xFFE8D5D5)),
            ),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              // 入力フィールド
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8E8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE8D5D5)),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    style: const TextStyle(
                      color: Color(0xFF24292E),
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.commandInputHint,
                      hintStyle: TextStyle(
                          color: Color(0xFFBB9999), fontSize: 13),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // お気に入り追加/済みボタン
              _BarIconButton(
                icon: _isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: _isFavorite ? AppColors.warning : const Color(0xFFBBAA9A),
                tooltip: 'お気に入りに追加',
                onTap: _isFavorite ? null : _addToFavorites,
                bgColor: const Color(0xFFFFE8E8),
              ),

              const SizedBox(width: 4),

              // 送信ボタン
              _BarIconButton(
                icon: Icons.send_rounded,
                color: widget.enabled
                    ? AppColors.primary
                    : const Color(0xFFBBAA9A),
                tooltip: '送信 (Enter)',
                onTap: widget.enabled ? _send : null,
                filled: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: AppColors.terminalBackground,
        border: Border(top: BorderSide(color: Color(0xFFE8D5D5))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cmd = _suggestions[i];
          return _SuggestionChip(
            label: cmd,
            onTap: () => _fillInput(cmd),
            onLongPress: () => _removeFromFavorites(cmd),
          );
        },
      ),
    );
  }
}

// ── 候補チップ ────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFE0E0),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF24292E),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

// ── アイコンボタン ────────────────────────────────────

class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
    this.filled = false,
    this.bgColor = const Color(0xFFFFE8E8),
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  final bool filled;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled && onTap != null ? AppColors.primary : bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap != null
              ? () {
                  HapticFeedback.lightImpact();
                  onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 20,
              color: filled && onTap != null ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
