import 'package:flutter/material.dart' show Color;
import 'package:xterm/xterm.dart';

import '../../../theme/app_theme.dart';

// ── ターミナルテーマ (Dark Red-White) ─────────────────────────

const kTerminalTheme = TerminalTheme(
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
