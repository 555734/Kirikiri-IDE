import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirikiri/l10n/app_localizations.dart';

import '../../../theme/app_theme.dart';
import '../terminal_controller.dart';

// ── 選択テキストコピーボタン ──────────────────────────────────

class CopyButton extends StatelessWidget {
  const CopyButton({required this.controller});
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

class TerminalActionButton extends StatefulWidget {
  const TerminalActionButton({
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
  State<TerminalActionButton> createState() => TerminalActionButtonState();
}

class TerminalActionButtonState extends State<TerminalActionButton> {
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
