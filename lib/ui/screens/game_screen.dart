import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../game/achievements.dart';
import '../../game/dev_messages.dart';
import '../../game/game_engine.dart';
import '../../services/audio_service.dart';
import '../../services/high_scores.dart';
import '../../services/settings.dart';
import '../render/board_painter.dart';
import '../theme.dart';
import '../widgets/hud.dart';
import '../widgets/overlays.dart';
import '../widgets/touch_controls.dart';
import 'settings_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.seed, this.onEngineCreated});

  /// Optional RNG seed (tests / reproducible runs).
  final int? seed;

  /// Exposes the engine to tests.
  @visibleForTesting
  final ValueChanged<GameEngine>? onEngineCreated;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final AppServices _services = AppScope.of(context);
  SettingsController get _settings => _services.settings;
  AudioService get _audio => _services.audio;
  HighScoreRepository get _scores => _services.highScores;

  late final GameEngine _engine = GameEngine(
    startingLives: _settings.startingLives,
    seed: widget.seed,
  );
  late final BoardRenderer _renderer = BoardRenderer(_engine);
  late final AchievementTracker _tracker = AchievementTracker(
    _settings.achievements,
  );
  final DevMessages _messages = DevMessages();

  late final Ticker _ticker = createTicker(_onTick);
  final FocusNode _focus = FocusNode(debugLabel: 'game');
  late final AppLifecycleListener _lifecycle;

  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final ValueNotifier<HudData> _hud = ValueNotifier(_hudSnapshot());
  final ValueNotifier<String> _console = ValueNotifier('');
  final ValueNotifier<Achievement?> _toast = ValueNotifier(null);
  final ValueNotifier<int> _fps = ValueNotifier(0);

  final List<Achievement> _toastQueue = [];
  Timer? _toastTimer;

  Duration _lastTick = Duration.zero;
  int _framesThisSecond = 0;
  double _fpsClock = 0;

  bool _chompToggle = false;
  Loop? _loop;
  String _pauseQuip = '';
  bool _gameOver = false;
  String _gameOverQuip = '';

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onInactive: _autoPause,
      onHide: _autoPause,
      onPause: _autoPause,
    );
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    _tracker.startGame();
    widget.onEngineCreated?.call(_engine);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _lifecycle.dispose();
    _toastTimer?.cancel();
    _audio.loop(null);
    _focus.dispose();
    _frame.dispose();
    _hud.dispose();
    _console.dispose();
    _toast.dispose();
    _fps.dispose();
    _renderer.dispose();
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Loop
  // ------------------------------------------------------------------

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    _engine.update(dt);
    _handleEvents(_engine.drainEvents());
    _syncLoop();

    final hud = _hudSnapshot();
    if (hud != _hud.value) _hud.value = hud;
    _frame.value++;

    if (_settings.showFps) {
      _framesThisSecond++;
      _fpsClock += dt;
      if (_fpsClock >= 1) {
        _fps.value = (_framesThisSecond / _fpsClock).round();
        _framesThisSecond = 0;
        _fpsClock = 0;
      }
    }
  }

  HudData _hudSnapshot() => HudData(
    score: _engine.score,
    high: math.max(_scores.best, _engine.score),
    lives: _engine.lives,
    level: _engine.level,
  );

  void _syncLoop() {
    final phase = _engine.phase;
    Loop? wanted;
    if (!_engine.paused &&
        (phase == GamePhase.playing || phase == GamePhase.ghostEaten)) {
      wanted = _engine.isFrightened ? Loop.fright : Loop.siren;
    }
    if (wanted != _loop) {
      _loop = wanted;
      _audio.loop(wanted);
    }
  }

  void _handleEvents(List<GameEvent> events) {
    for (final e in events) {
      switch (e) {
        case LevelStarted(:final firstOfGame):
          if (firstOfGame) _audio.play(Sfx.start);
        case SemicolonEaten():
          _chompToggle = !_chompToggle;
          _audio.play(_chompToggle ? Sfx.chompA : Sfx.chompB);
        case PowerBraceEaten():
          _audio.play(Sfx.power);
        case GhostEaten():
          _audio.play(Sfx.eatGhost);
        case BonusEaten():
          _audio.play(Sfx.bonus);
        case DeathAnimationStarted():
          _audio.play(Sfx.death);
        case ExtraLifeAwarded():
          _audio.play(Sfx.extraLife);
        case LevelCleared():
          _audio.play(Sfx.levelComplete);
        default:
          break;
      }
      final msg = _messages.forEvent(e);
      if (msg != null) _console.value = msg;
      if (e is GameOver) {
        _audio.play(Sfx.gameOver);
        _showGameOver(msg ?? _messages.gameOverQuip());
      }
      _unlock(_tracker.onEvent(e));
    }
  }

  void _unlock(List<Achievement> earned) {
    if (earned.isEmpty) return;
    _settings.unlock(earned);
    _toastQueue.addAll(earned);
    if (_toastTimer == null) _nextToast();
  }

  void _nextToast() {
    if (_toastQueue.isEmpty) {
      _toast.value = null;
      _toastTimer = null;
      return;
    }
    _toast.value = _toastQueue.removeAt(0);
    _audio.play(Sfx.achievement);
    _toastTimer = Timer(const Duration(milliseconds: 2600), _nextToast);
  }

  // ------------------------------------------------------------------
  // Controls
  // ------------------------------------------------------------------

  static final Map<LogicalKeyboardKey, Direction> _keyDirections = {
    LogicalKeyboardKey.arrowUp: Direction.up,
    LogicalKeyboardKey.arrowDown: Direction.down,
    LogicalKeyboardKey.arrowLeft: Direction.left,
    LogicalKeyboardKey.arrowRight: Direction.right,
    LogicalKeyboardKey.keyW: Direction.up,
    LogicalKeyboardKey.keyS: Direction.down,
    LogicalKeyboardKey.keyA: Direction.left,
    LogicalKeyboardKey.keyD: Direction.right,
    // Vim users feel at home.
    LogicalKeyboardKey.keyK: Direction.up,
    LogicalKeyboardKey.keyJ: Direction.down,
    LogicalKeyboardKey.keyH: Direction.left,
    LogicalKeyboardKey.keyL: Direction.right,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_gameOver) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      if (event is KeyDownEvent) _togglePause();
      return KeyEventResult.handled;
    }
    if (_engine.paused) {
      if (key == LogicalKeyboardKey.keyR && event is KeyDownEvent) {
        _restart();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored; // let focus traversal handle arrows
    }
    final dir = _keyDirections[key];
    if (dir != null) {
      _engine.steer(dir);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM && event is KeyDownEvent) {
      final mute = _settings.sfx || _settings.music;
      _settings
        ..sfx = !mute
        ..music = !mute;
      _console.value = mute ? '>>> audio.mute()' : '>>> audio.unmute()';
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _steer(Direction d) {
    if (!_engine.paused && !_gameOver) _engine.steer(d);
  }

  void _autoPause() {
    if (!mounted || _engine.paused || _gameOver) return;
    _togglePause();
  }

  void _togglePause() {
    if (_gameOver) return;
    setState(() {
      _engine.togglePause();
      if (_engine.paused) {
        _pauseQuip = _messages.pauseQuip();
        _unlock(_tracker.onPause());
      }
    });
    _syncLoop();
    if (_engine.paused) {
      // Nothing moves while paused: stop the ticker to save battery.
      _ticker.stop();
    } else {
      _lastTick = Duration.zero;
      _ticker.start();
      _focus.requestFocus();
    }
  }

  void _restart() {
    setState(() {
      _gameOver = false;
      _engine.restart();
      _tracker.startGame();
      _console.value = '';
    });
    _lastTick = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
    _focus.requestFocus();
  }

  void _quit() => Navigator.of(context).maybePop();

  Future<void> _openSettings() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    if (mounted) setState(() {});
  }

  void _showGameOver(String quip) {
    setState(() {
      _gameOverQuip = quip;
      _gameOver = true;
    });
  }

  Future<int> _saveScore(String name) {
    _settings.playerName = name;
    return _scores.add(
      HighScoreEntry(
        name: name,
        score: _engine.score,
        level: _engine.level,
        date: DateTime.now(),
      ),
    );
  }

  bool get _showPad => switch (_settings.touch) {
    TouchControls.dpad => true,
    TouchControls.swipe => false,
    TouchControls.auto =>
      defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS,
  };

  // ------------------------------------------------------------------
  // Layout
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SwipeControls(
        onDirection: _steer,
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Stack(
            children: [
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) => box.maxWidth > box.maxHeight * 1.05
                      ? _landscape(box)
                      : _portrait(box),
                ),
              ),
              if (_engine.paused && !_gameOver)
                PauseOverlay(
                  quip: _pauseQuip,
                  onResume: _togglePause,
                  onRestart: _restart,
                  onSettings: _openSettings,
                  onQuit: _quit,
                ),
              if (_gameOver)
                GameOverOverlay(
                  score: _engine.score,
                  level: _engine.level,
                  quip: _gameOverQuip,
                  qualifies: _scores.qualifies(_engine.score),
                  initialName: _settings.playerName,
                  onSubmitName: _saveScore,
                  onPlayAgain: _restart,
                  onMenu: _quit,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pauseButton(double size) => ExcludeFocus(
    child: IconButton(
      onPressed: _togglePause,
      tooltip: 'Pause (P / Esc)',
      iconSize: size,
      color: Palette.text,
      icon: const Icon(Icons.pause_rounded, semanticLabel: 'Pause'),
    ),
  );

  Widget _portrait(BoxConstraints box) {
    final w = box.maxWidth;
    final padSize = _showPad ? (w * 0.42).clamp(120.0, 190.0) : 0.0;
    final font = (w / 32).clamp(9.0, 16.0);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 0),
          child: ValueListenableBuilder<HudData>(
            valueListenable: _hud,
            builder: (context, hud, _) => Row(
              children: [
                Expanded(
                  child: ScoreBlock(
                    label: '1UP',
                    value: hud.score,
                    fontSize: font,
                  ),
                ),
                Expanded(
                  child: ScoreBlock(
                    label: 'HIGH SCORE',
                    value: hud.high,
                    fontSize: font,
                    align: CrossAxisAlignment.center,
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _pauseButton(font * 2.2),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, inner) {
              // Everything below the maze has a fixed height, so the maze
              // takes what is left and spare space collects above the pad.
              final rowHeight = font * 1.6 + 8;
              final consoleHeight = font * 2.6;
              final padHeight = _showPad ? padSize + 16 : 0.0;
              final boardHeight = math.max(
                0.0,
                math.min(
                  inner.maxWidth * 31 / 28,
                  inner.maxHeight - rowHeight - consoleHeight - padHeight,
                ),
              );
              return Column(
                children: [
                  if (!_showPad) const Spacer(),
                  SizedBox(height: boardHeight, child: _board()),
                  SizedBox(
                    height: rowHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: ValueListenableBuilder<HudData>(
                        valueListenable: _hud,
                        builder: (context, hud, _) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            LivesRow(spare: hud.lives - 1, size: font * 1.6),
                            LevelRow(level: hud.level, size: font * 0.9),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: consoleHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        child: ConsoleLine(
                          message: _console,
                          fontSize: font * 0.72,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_showPad)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 4),
                      child: DirectionPad(onDirection: _steer, size: padSize),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _landscape(BoxConstraints box) {
    final h = box.maxHeight;
    final sideWidth = (box.maxWidth - h * 28 / 31) / 2;
    final panelWidth = sideWidth.clamp(120.0, 320.0);
    final font = (panelWidth / 16).clamp(8.0, 15.0);
    final padSize = _showPad ? (panelWidth * 0.8).clamp(110.0, h * 0.6) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: panelWidth,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ValueListenableBuilder<HudData>(
              valueListenable: _hud,
              builder: (context, hud, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScoreBlock(label: '1UP', value: hud.score, fontSize: font),
                  SizedBox(height: font * 1.4),
                  ScoreBlock(
                    label: 'HIGH SCORE',
                    value: hud.high,
                    fontSize: font,
                  ),
                  SizedBox(height: font * 1.4),
                  Text('LEVEL ${hud.level}', style: ArcadeText.dim(font * 0.8)),
                  SizedBox(height: font * 0.6),
                  LevelRow(level: hud.level, size: font * 0.8),
                  const Spacer(),
                  LivesRow(spare: hud.lives - 1, size: font * 1.7),
                  SizedBox(height: font),
                  ConsoleLine(message: _console, fontSize: font * 0.7),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _board()),
        SizedBox(
          width: panelWidth,
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: _pauseButton(font * 2.4),
              ),
              const Spacer(),
              if (_showPad) DirectionPad(onDirection: _steer, size: padSize),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _board() => LayoutBuilder(
    builder: (context, box) {
      final maze = _engine.maze;
      final ts = math.min(
        box.maxWidth / maze.width,
        box.maxHeight / maze.height,
      );
      final size = Size(ts * maze.width, ts * maze.height);
      return Center(
        child: SizedBox.fromSize(
          size: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  isComplex: true,
                  painter: BoardPainter(
                    renderer: _renderer,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                    reduceFlashing: _settings.reduceFlashing,
                    repaint: _frame,
                  ),
                ),
              ),
              if (_settings.crt) const CrtOverlay(),
              Align(
                alignment: Alignment.topCenter,
                child: ValueListenableBuilder<Achievement?>(
                  valueListenable: _toast,
                  builder: (context, a, _) => AchievementToast(achievement: a),
                ),
              ),
              if (_settings.showFps)
                Align(
                  alignment: Alignment.bottomRight,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _fps,
                    builder: (context, fps, _) => Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text('$fps FPS', style: ArcadeText.code(8)),
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
