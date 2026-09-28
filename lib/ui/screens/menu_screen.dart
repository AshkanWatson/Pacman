import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../game/achievements.dart';
import '../../game/core/direction.dart';
import '../../game/entities/js_ghost.dart';
import '../../services/audio_service.dart';
import '../render/sprites.dart';
import '../theme.dart';
import '../widgets/arcade_button.dart';
import '../widgets/overlays.dart';
import 'about_screen.dart';
import 'game_screen.dart';
import 'high_scores_screen.dart';
import 'how_to_play_screen.dart';
import 'settings_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _attract = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  static const _konami = [
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.keyA,
  ];
  int _konamiIndex = 0;
  Achievement? _toast;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).audio.loop(Loop.menuMusic);
    });
  }

  @override
  void dispose() {
    _attract.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == _konami[_konamiIndex]) {
      _konamiIndex++;
      if (_konamiIndex == _konami.length) {
        _konamiIndex = 0;
        _onKonami();
      }
    } else {
      _konamiIndex = key == _konami.first ? 1 : 0;
    }
    return KeyEventResult.ignored; // never swallow navigation keys
  }

  void _onKonami() {
    final services = AppScope.of(context);
    services.settings.crt = !services.settings.crt;
    final earned = AchievementTracker(services.settings.achievements)
        .onKonami();
    services.settings.unlock(earned);
    services.audio.play(Sfx.achievement);
    setState(() => _toast = earned.isEmpty ? null : earned.first);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Palette.surface,
          content: Text(
            services.settings.crt
                ? 'sudo mode: CRT scanlines enabled'
                : 'sudo mode: CRT scanlines disabled',
            style: ArcadeText.code(9),
          ),
        ),
      );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _open(Widget screen) async {
    final audio = AppScope.of(context).audio;
    final isGame = screen is GameScreen;
    if (isGame) audio.loop(null);
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => screen,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (mounted) {
      audio.loop(Loop.menuMusic);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Scaffold(
      body: Focus(
        onKeyEvent: _onKey,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final short = box.maxHeight < 560;
              final titleSize = (box.maxWidth / 9).clamp(
                28.0,
                short ? 44.0 : 64.0,
              );
              final buttonSize = (box.maxWidth / 34).clamp(11.0, 16.0);
              return Stack(
                children: [
                  if (services.settings.crt)
                    const Positioned.fill(child: CrtOverlay()),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('PY-MAN', style: ArcadeText.title(titleSize)),
                          const SizedBox(height: 12),
                          Text(
                            'PYTHON  vs  JAVASCRIPT',
                            textAlign: TextAlign.center,
                            style: ArcadeText.base.copyWith(
                              fontSize: (titleSize / 5).clamp(8.0, 12.0),
                              color: Palette.jsYellow,
                            ),
                          ),
                          SizedBox(height: short ? 12 : 24),
                          SizedBox(
                            width: math.min(box.maxWidth - 32, 560),
                            height: short ? 40 : 56,
                            child: AnimatedBuilder(
                              animation: _attract,
                              builder: (_, _) => CustomPaint(
                                painter: _AttractPainter(_attract.value),
                              ),
                            ),
                          ),
                          SizedBox(height: short ? 12 : 28),
                          FocusTraversalGroup(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ArcadeButton(
                                  label: 'START GAME',
                                  autofocus: true,
                                  fontSize: buttonSize,
                                  onPressed: () => _open(const GameScreen()),
                                ),
                                ArcadeButton(
                                  label: 'HOW TO PLAY',
                                  fontSize: buttonSize,
                                  onPressed: () =>
                                      _open(const HowToPlayScreen()),
                                ),
                                ArcadeButton(
                                  label: 'HIGH SCORES',
                                  fontSize: buttonSize,
                                  onPressed: () =>
                                      _open(const HighScoresScreen()),
                                ),
                                ArcadeButton(
                                  label: 'SETTINGS',
                                  fontSize: buttonSize,
                                  onPressed: () =>
                                      _open(const SettingsScreen()),
                                ),
                                ArcadeButton(
                                  label: 'ABOUT',
                                  fontSize: buttonSize,
                                  onPressed: () => _open(const AboutScreen()),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: short ? 12 : 28),
                          ListenableBuilder(
                            listenable: services.highScores,
                            builder: (context, _) => Text(
                              'HI-SCORE  ${services.highScores.best}',
                              style: ArcadeText.base.copyWith(
                                fontSize: 10,
                                color: Palette.danger,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '// undefined is not a function',
                            textAlign: TextAlign.center,
                            style: ArcadeText.code(8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: AchievementToast(achievement: _toast),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Attract-mode animation: Python is chased by JavaScript ghosts, eats a
/// power brace, and turns the tables on the (now TypeScript) ghosts.
class _AttractPainter extends CustomPainter {
  _AttractPainter(this.t);
  final double t;

  static final SpriteKit _sprites = SpriteKit();
  static final Paint _dot = Paint()..color = Palette.semicolon;
  static final TextPainter _brace = TextPainter(
    text: const TextSpan(
      text: '{}',
      style: TextStyle(
        fontFamily: arcadeFont,
        fontSize: 0.8,
        color: Palette.brace,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  static const _points = [200, 400, 800, 1600];
  static final List<TextPainter> _popups = [
    for (final p in _points)
      TextPainter(
        text: TextSpan(
          text: '$p',
          style: const TextStyle(
            fontFamily: arcadeFont,
            fontSize: 0.5,
            color: Palette.tsBlue,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final ts = size.height / 2;
    final w = size.width / ts; // lane width in tiles
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(ts);
    const y = 1.0;
    final wobble = (t * 60).floor().isEven;

    if (t < 0.5) {
      // Python flees left, ghosts in pursuit.
      final q = t / 0.5;
      final px = w + 1 - q * w;
      for (var x = 3; x < w - 1; x += 1) {
        if (x + 0.5 < px) addSemicolon(canvas, _dot, x + 0.5, y);
      }
      if ((t * 8).floor().isEven) {
        _brace.paint(
          canvas,
          Offset(1.2 - _brace.width / 2, y - _brace.height / 2),
        );
      }
      for (final g in GhostKind.values) {
        final gx = px + 2.6 + g.index * 1.8;
        _sprites.drawGhost(canvas, gx, y, g, Direction.left, wobble: wobble);
      }
      _sprites.drawPython(
        canvas,
        px,
        y,
        Direction.left,
        mouth: 0.1 + 0.6 * (math.sin(q * 60)).abs(),
      );
    } else {
      // Power brace eaten: TypeScript ghosts flee, Python gives chase.
      final q = (t - 0.5) / 0.5;
      final px = 1.0 + q * w * 1.2;
      for (final g in GhostKind.values) {
        final g0 = 1 + 2.6 + g.index * 1.8;
        final gx = g0 + q * w * 0.35;
        final eatenAt = (g0 - 1) / (w * 1.2 - w * 0.35);
        if (q < eatenAt) {
          _sprites.drawGhost(
            canvas,
            gx,
            y,
            g,
            Direction.right,
            typescript: true,
            flashWhite: q > 0.7 && wobble,
            wobble: wobble,
          );
        } else if (q < eatenAt + 0.12) {
          final tp = _popups[g.index];
          tp.paint(canvas, Offset(gx - tp.width / 2, y - tp.height / 2));
        }
      }
      _sprites.drawPython(
        canvas,
        px,
        y,
        Direction.right,
        mouth: 0.1 + 0.6 * (math.sin(q * 60)).abs(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AttractPainter old) => old.t != t;
}
