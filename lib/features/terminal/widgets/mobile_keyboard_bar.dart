import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';

/// スマホ開発に必要なキーをターミナルの上に横スクロールで表示するバー
///
/// 機能:
///   - Ctrl モディファイアキー (タップで ON/OFF、次のキー入力に Ctrl を付加)
///   - Tab / Esc / 矢印キー
///   - Ctrl+C/D/Z/L のショートカット
///   - コーディングでよく使う記号
class MobileKeyboardBar extends StatefulWidget {
  const MobileKeyboardBar({
    super.key,
    required this.onInput,
  });

  /// キー入力時のコールバック (送信する文字列を受け取る)
  final void Function(String data) onInput;

  @override
  State<MobileKeyboardBar> createState() => _MobileKeyboardBarState();
}

class _MobileKeyboardBarState extends State<MobileKeyboardBar> {
  bool _ctrlActive = false;
  bool _altActive = false;

  void _send(String data) {
    widget.onInput(data);
    // モディファイア使用後はリセット
    if (_ctrlActive || _altActive) {
      setState(() {
        _ctrlActive = false;
        _altActive = false;
      });
    }
  }

  /// Ctrl+key の ASCII コードを計算して送信
  void _sendCtrl(String key) {
    final lower = key.toLowerCase();
    final code = lower.codeUnitAt(0) - 'a'.codeUnitAt(0) + 1;
    _send(String.fromCharCode(code));
  }

  /// 通常キーを押したとき: Ctrl モードならコントロールコードに変換
  void _onKey(String key) {
    if (_ctrlActive) {
      _sendCtrl(key);
    } else if (_altActive) {
      // Alt = ESC + key
      _send('\x1b$key');
    } else {
      _send(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.terminalBackground,
        border: Border(
          top: BorderSide(color: Color(0xFFE8D5D5)),
        ),
      ),
      child: ScrollConfiguration(
        behavior: _NoGlowScrollBehavior(),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          children: [
            // ── モディファイアキー ──────────────────────
            _ModifierKey(
              label: 'CTRL',
              isActive: _ctrlActive,
              onTap: () => setState(() {
                _ctrlActive = !_ctrlActive;
                if (_ctrlActive) _altActive = false;
              }),
            ),
            const _Separator(),
            _ModifierKey(
              label: 'ALT',
              isActive: _altActive,
              onTap: () => setState(() {
                _altActive = !_altActive;
                if (_altActive) _ctrlActive = false;
              }),
            ),
            const _Separator(),

            // ── 特殊キー ───────────────────────────────
            _Key(label: 'ESC', onTap: () => _send('\x1b')),
            _Key(label: 'TAB', onTap: () => _send('\t')),
            const _Separator(),

            // ── 矢印キー ───────────────────────────────
            _Key(
              label: '↑',
              icon: Icons.arrow_upward_rounded,
              onTap: () => _send('\x1b[A'),
            ),
            _Key(
              label: '↓',
              icon: Icons.arrow_downward_rounded,
              onTap: () => _send('\x1b[B'),
            ),
            _Key(
              label: '→',
              icon: Icons.arrow_forward_rounded,
              onTap: () => _send('\x1b[C'),
            ),
            _Key(
              label: '←',
              icon: Icons.arrow_back_rounded,
              onTap: () => _send('\x1b[D'),
            ),
            const _Separator(),

            // ── Ctrl ショートカット ─────────────────────
            _ShortcutKey(
              label: 'C',
              sublabel: 'Ctrl',
              color: AppColors.error,
              onTap: () => _sendCtrl('c'), // Ctrl+C: SIGINT
            ),
            _ShortcutKey(
              label: 'D',
              sublabel: 'Ctrl',
              color: AppColors.warning,
              onTap: () => _sendCtrl('d'), // Ctrl+D: EOF
            ),
            _ShortcutKey(
              label: 'Z',
              sublabel: 'Ctrl',
              color: AppColors.secondary,
              onTap: () => _sendCtrl('z'), // Ctrl+Z: suspend
            ),
            _ShortcutKey(
              label: 'L',
              sublabel: 'Ctrl',
              color: AppColors.primary,
              onTap: () => _sendCtrl('l'), // Ctrl+L: clear
            ),
            const _Separator(),

            // ── Page Up/Down ───────────────────────────
            _Key(label: 'PgUp', onTap: () => _send('\x1b[5~')),
            _Key(label: 'PgDn', onTap: () => _send('\x1b[6~')),
            _Key(label: 'Home', onTap: () => _send('\x1b[H')),
            _Key(label: 'End', onTap: () => _send('\x1b[F')),
            const _Separator(),

            // ── よく使う記号 ───────────────────────────
            for (final sym in _symbols)
              _Key(label: sym, onTap: () => _onKey(sym)),
          ],
        ),
      ),
    );
  }
}

const _symbols = [
  '|', '&', ';', '~', '/', '-', '_', '>',
  '<', '*', '#', r'$', '`', "'", '"', '!',
  '@', '(', ')', '[', ']', '{', '}', '\\',
  '=', '+', '.', ',', '?', '%',
];

// ── キーウィジェット ─────────────────────────────────

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFD4A8A8),
              blurRadius: 0,
              offset: Offset(0, 1.5),
            ),
          ],
        ),
        child: Material(
          color: const Color(0xFFFFE0E0),
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(9),
            child: Container(
              constraints: const BoxConstraints(minWidth: 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, size: 16, color: const Color(0xFF24292E))
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF24292E),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ctrl / Alt などのトグルキー
class _ModifierKey extends StatelessWidget {
  const _ModifierKey({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? AppColors.primary.withOpacity(0.45)
                  : const Color(0xFFD4A8A8),
              blurRadius: 0,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Material(
          color: isActive ? AppColors.primary : const Color(0xFFFFE0E0),
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF24292E),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ctrl+C など色付きショートカットキー
class _ShortcutKey extends StatelessWidget {
  const _ShortcutKey({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.30),
              blurRadius: 0,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Material(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '^',
                      style: TextStyle(
                        color: color.withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      color: const Color(0xFFE8D5D5),
    );
  }
}

/// スクロールのグロー効果を無効化
class _NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
