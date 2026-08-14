import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── フローティングコマンドモデル ──────────────────────────────

class FloatingCommand {
  FloatingCommand({
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

  factory FloatingCommand.fromJson(Map<String, dynamic> j) => FloatingCommand(
        id: j['id'] as String,
        label: j['label'] as String,
        command: j['command'] as String,
        relX: (j['x'] as num).toDouble(),
        relY: (j['y'] as num).toDouble(),
      );
}

// ── フローティングコマンドバブルウィジェット ──────────────────

class FloatingCmdBubble extends StatefulWidget {
  const FloatingCmdBubble({
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
  State<FloatingCmdBubble> createState() => FloatingCmdBubbleState();
}

class FloatingCmdBubbleState extends State<FloatingCmdBubble> {
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
