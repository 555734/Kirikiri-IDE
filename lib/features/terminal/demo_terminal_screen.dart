import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';

import '../../theme/app_theme.dart';
import 'widgets/mobile_keyboard_bar.dart';

class DemoTerminalScreen extends StatelessWidget {
  const DemoTerminalScreen({super.key, this.title = 'Cloud Shell'});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.terminalBackground,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  const SizedBox(height: 46),
                  Expanded(child: _DemoTerminalArea(title: title)),
                  const _DemoCommandBar(),
                  MobileKeyboardBar(onInput: (_) {}),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _DemoTopOverlay(title: title),
            ),
          ],
        ),
      ),
    );
  }
}

// ── トップオーバーレイ ────────────────────────────────────

class _DemoTopOverlay extends StatelessWidget {
  const _DemoTopOverlay({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xD0161B22),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 4),
          // 接続インジケーター（緑丸）
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'monospace',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded,
                color: Colors.white54, size: 20),
            onPressed: null,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ],
      ),
    );
  }
}

// ── メインターミナル領域 ──────────────────────────────────

class _DemoTerminalArea extends StatelessWidget {
  const _DemoTerminalArea({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            // ターミナル出力テキスト
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                child: const _TerminalOutput(),
              ),
            ),

            // フローティングコマンドバブル
            _bubble('git pull',       w * 0.10, h * 0.15),
            _bubble('flutter run',    w * 0.42, h * 0.08),
            _bubble('git status',     w * 0.62, h * 0.30),
            _bubble('flutter test',   w * 0.08, h * 0.52),
            _bubble('clear',          w * 0.55, h * 0.60),

            // 右アクションパネル
            Positioned(
              right: 8,
              top: h * 0.28,
              child: const _RightPanel(),
            ),
          ],
        );
      },
    );
  }

  Widget _bubble(String label, double left, double top) {
    return Positioned(
      left: left,
      top: top,
      child: _FloatingBubble(label: label),
    );
  }
}

class _FloatingBubble extends StatelessWidget {
  const _FloatingBubble({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.45),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── 右アクションパネル ────────────────────────────────────

class _RightPanel extends StatelessWidget {
  const _RightPanel();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC161B22),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.drag_handle_rounded, color: Colors.white24, size: 18),
          const SizedBox(height: 2),
          _PanelButton(
            icon: Icons.open_in_browser_rounded,
            label: l.preview,
          ),
          _PanelButton(
            icon: Icons.play_arrow_rounded,
            label: l.run,
            color: AppColors.successLight,
          ),
          _PanelButton(
            icon: Icons.source_rounded,
            label: l.repository,
          ),
          _PanelButton(
            icon: Icons.widgets_outlined,
            label: l.buttonsEdit,
          ),
          // フォントサイズボタン
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              children: [
                const Icon(Icons.text_fields_rounded,
                    color: Colors.white70, size: 20),
                const SizedBox(height: 2),
                Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 9,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Icon(icon, color: color ?? Colors.white70, size: 22),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: (color ?? Colors.white).withOpacity(0.55),
              fontSize: 9,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── ターミナル出力（リッチテキスト） ─────────────────────────

class _TerminalOutput extends StatelessWidget {
  const _TerminalOutput();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      _buildOutput(),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12.5,
        height: 1.55,
        color: Color(0xFF24292E),
      ),
    );
  }

  TextSpan _buildOutput() {
    const g = Color(0xFF16A34A);   // green
    const y = Color(0xFFD97706);   // yellow/amber
    const r = Color(0xFFDC2626);   // red
    const c = Color(0xFF0891B2);   // cyan
    const dim = Color(0xFF9CA3AF); // muted

    return TextSpan(children: [
      // === git pull ===
      ..._prompt('~/kirikiri'),
      _t('git pull\n', bold: true),
      _t('remote: Enumerating objects: 5, done.\n', color: dim),
      _t('remote: Counting objects: 100% (5/5), done.\n', color: dim),
      _t('Updating '),
      _t('a3f8c12..7b2e491\n', color: y),
      _t('Fast-forward\n'),
      _t(' lib/core/screenshot_mode.dart', color: g),
      _t(' | 1 +\n'),
      _t(' lib/main.dart', color: g),
      _t('                | 3 +-\n'),
      _t(' 2 files changed, 3 insertions(+), 1 deletion(-)\n', color: g),
      const TextSpan(text: '\n'),

      // === flutter pub get ===
      ..._prompt('~/kirikiri'),
      _t('flutter pub get\n', bold: true),
      _t('Resolving dependencies', color: dim),
      _t('... (0.8s)\n', color: dim),
      _t('✓ ', color: g, bold: true),
      _t('Got dependencies.\n'),
      const TextSpan(text: '\n'),

      // === flutter analyze ===
      ..._prompt('~/kirikiri'),
      _t('flutter analyze\n', bold: true),
      _t('Analyzing kirikiri', color: dim),
      _t('...\n', color: dim),
      _t('✓ ', color: g, bold: true),
      _t('No issues found! ', bold: true),
      _t('(ran in 3.4s)\n', color: dim),
      const TextSpan(text: '\n'),

      // === git log ===
      ..._prompt('~/kirikiri'),
      _t('git log --oneline -5\n', bold: true),
      _t('7b2e491 ', color: y),
      _t('(', color: dim),
      _t('HEAD -> ', color: c),
      _t('main', color: g, bold: true),
      _t(')', color: dim),
      _t(' feat: add SCREENSHOT_MODE for demo\n'),
      _t('3c1d057 ', color: y),
      _t('fix: guard SshForegroundService with kIsWeb\n'),
      _t('1ca5658 ', color: y),
      _t('refactor: add DemoTerminalScreen\n'),
      _t('edc08ac ', color: y),
      _t('(', color: dim),
      _t('origin/main', color: r),
      _t(')', color: dim),
      _t(' fix: SCREENSHOT_MODE web crash\n'),
      _t('bd9ed25 ', color: y),
      _t('chore: add screenshot mode scaffolding\n'),
      const TextSpan(text: '\n'),

      // === prompt ===
      ..._prompt('~/kirikiri'),
      _t('█', color: r, bold: true),
    ]);
  }

  List<TextSpan> _prompt(String path) {
    const g = Color(0xFF16A34A);
    const b = Color(0xFF1D4ED8);
    return [
      _t('user@cloudshell', color: g, bold: true),
      _t(':'),
      _t(path, color: b, bold: true),
      _t('\$ '),
    ];
  }

  TextSpan _t(String text, {Color? color, bool bold = false}) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontWeight: bold ? FontWeight.bold : null,
      ),
    );
  }
}

// ── コマンド入力バー（デモ用） ────────────────────────────

class _DemoCommandBar extends StatelessWidget {
  const _DemoCommandBar();

  static const _suggestions = [
    'git pull',
    'flutter pub get',
    'flutter analyze',
    'git commit -am ""',
    'flutter run',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 候補チップ行
        Container(
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
            itemBuilder: (_, i) => Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0E0),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Text(
                _suggestions[i],
                style: const TextStyle(
                  color: Color(0xFF24292E),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),

        // 入力フィールド行
        Container(
          decoration: const BoxDecoration(
            color: AppColors.terminalBackground,
            border: Border(top: BorderSide(color: Color(0xFFE8D5D5))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8E8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE8D5D5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context)!.commandInputHint,
                    style: const TextStyle(
                      color: Color(0xFFBB9999),
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _barButton(Icons.star_border_rounded, const Color(0xFFBBAA9A),
                  const Color(0xFFFFE8E8)),
              const SizedBox(width: 4),
              _barButton(Icons.send_rounded, Colors.white, AppColors.primary,
                  filled: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _barButton(IconData icon, Color iconColor, Color bg,
      {bool filled = false}) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: iconColor),
    );
  }
}
