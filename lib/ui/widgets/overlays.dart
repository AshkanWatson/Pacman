import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/achievements.dart';
import '../theme.dart';
import 'arcade_button.dart';

/// Dimmed full-screen card used by the pause and game-over overlays.
class OverlayCard extends StatelessWidget {
  const OverlayCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: Palette.background.withValues(alpha: 0.82),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FocusTraversalGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.quip,
    required this.onResume,
    required this.onRestart,
    required this.onSettings,
    required this.onQuit,
  });

  final String quip;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onSettings;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) => OverlayCard(
    children: [
      Text('BREAKPOINT', style: ArcadeText.title(22)),
      const SizedBox(height: 12),
      Text('// $quip', textAlign: TextAlign.center, style: ArcadeText.code(9)),
      const SizedBox(height: 24),
      ArcadeButton(label: 'RESUME', onPressed: onResume, autofocus: true),
      ArcadeButton(label: 'RESTART', onPressed: onRestart),
      ArcadeButton(label: 'SETTINGS', onPressed: onSettings),
      ArcadeButton(label: 'QUIT TO MENU', onPressed: onQuit),
      const SizedBox(height: 16),
      Text('P / ESC  resume    R  restart', style: ArcadeText.dim(8)),
    ],
  );
}

class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({
    super.key,
    required this.score,
    required this.level,
    required this.quip,
    required this.qualifies,
    required this.initialName,
    required this.onSubmitName,
    required this.onPlayAgain,
    required this.onMenu,
  });

  final int score;
  final int level;
  final String quip;
  final bool qualifies;
  final String initialName;

  /// Saves the score; returns the 0-based rank.
  final Future<int> Function(String name) onSubmitName;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  // Pre-selected so typing replaces the remembered initials.
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialName.length,
        );
  int? _rank;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || _rank != null) return;
    setState(() => _saving = true);
    final name = _name.text.trim().isEmpty ? '???' : _name.text.trim();
    final rank = await widget.onSubmitName(name.toUpperCase());
    if (mounted) {
      setState(() {
        _rank = rank;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entering = widget.qualifies && _rank == null;
    return OverlayCard(
      children: [
        Text(
          'GAME OVER',
          style: ArcadeText.title(26).copyWith(color: Palette.danger),
        ),
        const SizedBox(height: 12),
        Text(
          widget.quip,
          textAlign: TextAlign.center,
          style: ArcadeText.code(9),
        ),
        const SizedBox(height: 20),
        Text('SCORE ${widget.score}', style: ArcadeText.heading(14)),
        const SizedBox(height: 6),
        Text('REACHED LEVEL ${widget.level}', style: ArcadeText.dim(9)),
        const SizedBox(height: 20),
        if (entering) ...[
          Text('NEW HIGH SCORE! ENTER INITIALS', style: ArcadeText.body(9)),
          const SizedBox(height: 10),
          SizedBox(
            width: 140,
            child: TextField(
              controller: _name,
              autofocus: true,
              maxLength: 3,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9_]')),
                TextInputFormatter.withFunction(
                  (_, v) => v.copyWith(text: v.text.toUpperCase()),
                ),
              ],
              style: ArcadeText.heading(20),
              cursorColor: Palette.pythonYellow,
              decoration: const InputDecoration(
                counterText: '',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Palette.wall),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Palette.pythonYellow),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 8),
          ArcadeButton(
            label: _saving ? 'SAVING...' : 'SAVE SCORE',
            onPressed: _saving ? null : _submit,
          ),
        ] else if (_rank != null && _rank! >= 0)
          Text(
            'git commit -m "#${_rank! + 1} on the leaderboard"',
            textAlign: TextAlign.center,
            style: ArcadeText.code(9),
          ),
        const SizedBox(height: 8),
        ArcadeButton(
          label: 'PLAY AGAIN',
          onPressed: widget.onPlayAgain,
          autofocus: !entering,
        ),
        ArcadeButton(label: 'MAIN MENU', onPressed: widget.onMenu),
      ],
    );
  }
}

/// Slide-in banner shown when an achievement unlocks.
class AchievementToast extends StatelessWidget {
  const AchievementToast({super.key, required this.achievement});
  final Achievement? achievement;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    transitionBuilder: (child, anim) => SlideTransition(
      position: Tween(
        begin: const Offset(0, -1.2),
        end: Offset.zero,
      ).animate(anim),
      child: FadeTransition(opacity: anim, child: child),
    ),
    child: achievement == null
        ? const SizedBox.shrink()
        : Container(
            key: ValueKey(achievement),
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Palette.surface.withValues(alpha: 0.95),
              border: Border.all(color: Palette.pythonYellow),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(color: Color(0x66FFD43B), blurRadius: 12),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ACHIEVEMENT UNLOCKED',
                  style: ArcadeText.base.copyWith(
                    fontSize: 7,
                    color: Palette.console,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement!.title,
                  textAlign: TextAlign.center,
                  style: ArcadeText.heading(10),
                ),
              ],
            ),
          ),
  );
}

/// Subtle CRT scanlines + vignette (optional setting / Easter egg).
class CrtOverlay extends StatelessWidget {
  const CrtOverlay({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: RepaintBoundary(child: CustomPaint(painter: _CrtPainter())),
  );
}

class _CrtPainter extends CustomPainter {
  const _CrtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = const Color(0x22000000);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.2), line);
    }
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00000000), Color(0x66000000)],
          stops: [0.65, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_CrtPainter oldDelegate) => false;
}
