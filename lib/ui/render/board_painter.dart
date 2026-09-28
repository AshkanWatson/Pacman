import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../game/game_engine.dart';
import '../theme.dart';
import 'sprites.dart';

/// Owns the expensive, cacheable parts of the board rendering: the wall
/// raster, the collectible picture and laid-out text.
class BoardRenderer {
  BoardRenderer(this.engine);

  final GameEngine engine;
  final SpriteKit sprites = SpriteKit();

  ui.Picture? _wallPicture;
  ui.Picture? _wallFlashPicture;
  ui.Image? _walls;
  ui.Image? _wallsFlash;
  Size _rasterSize = Size.zero;

  ui.Picture? _pellets;
  int _pelletVersion = -1;

  final Map<String, TextPainter> _text = {};

  final Paint _pelletPaint = Paint()..color = Palette.semicolon;
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _doorPaint = Paint()
    ..color = Palette.door
    ..strokeWidth = 0.18;
  final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.35);

  bool _wall(int col, int row) => engine.maze.isWall(Tile(col, row));

  ui.Image _rasterise(ui.Picture picture, Size px, double scale) {
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..scale(scale)
      ..drawPicture(picture);
    final pic = recorder.endRecording();
    final image = pic.toImageSync(px.width.ceil(), px.height.ceil());
    pic.dispose();
    return image;
  }

  void _ensureWalls(Size boardSize, double dpr, double tileSize) {
    final px = boardSize * dpr;
    if (_walls != null && _rasterSize == px) return;
    _wallPicture ??= buildWallPicture(
      _wall,
      engine.maze.width,
      engine.maze.height,
    );
    _wallFlashPicture ??= buildWallPicture(
      _wall,
      engine.maze.width,
      engine.maze.height,
      color: const Color(0xFFFFFFFF),
      glow: const Color(0xFFB8C7FF),
    );
    _walls?.dispose();
    _wallsFlash?.dispose();
    _walls = _rasterise(_wallPicture!, px, tileSize * dpr);
    _wallsFlash = _rasterise(_wallFlashPicture!, px, tileSize * dpr);
    _rasterSize = px;
  }

  ui.Picture _pelletPicture() {
    final maze = engine.maze;
    if (_pellets != null && _pelletVersion == maze.version) return _pellets!;
    _pellets?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var r = 0; r < maze.height; r++) {
      for (var c = 0; c < maze.width; c++) {
        if (maze.itemAt(Tile(c, r)) == Collectible.semicolon) {
          addSemicolon(canvas, _pelletPaint, c + 0.5, r + 0.5);
        }
      }
    }
    _pelletVersion = maze.version;
    return _pellets = recorder.endRecording();
  }

  TextPainter text(String s, Color color, double size) {
    final key = '$s|${color.toARGB32()}|$size';
    return _text.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: arcadeFont,
            fontSize: size,
            color: color,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  void _centered(Canvas canvas, TextPainter tp, double cx, double cy) =>
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

  void dispose() {
    _walls?.dispose();
    _wallsFlash?.dispose();
    _wallPicture?.dispose();
    _wallFlashPicture?.dispose();
    _pellets?.dispose();
    for (final t in _text.values) {
      t.dispose();
    }
    _text.clear();
    sprites.dispose();
  }

  /// Paints the whole board into [size] (which has the maze aspect ratio).
  void paint(
    Canvas canvas,
    Size size, {
    required double devicePixelRatio,
    required bool reduceFlashing,
  }) {
    final e = engine;
    final maze = e.maze;
    final ts = size.width / maze.width;
    _ensureWalls(size, devicePixelRatio, ts);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // Walls (raster) and the ghost-house door.
    final flash = e.levelFlashOn && !reduceFlashing;
    canvas.drawImageRect(
      flash ? _wallsFlash! : _walls!,
      Offset.zero & _rasterSize,
      Offset.zero & size,
      _imagePaint,
    );

    canvas.scale(ts);
    canvas.drawLine(const Offset(13, 12.6), const Offset(15, 12.6), _doorPaint);

    // Collectibles.
    canvas.drawPicture(_pelletPicture());
    _paintPowerBraces(canvas);
    _paintBonus(canvas);

    // Actors.
    final phase = e.phase;
    final hideGhosts =
        (phase == GamePhase.dying && e.deathProgress > 0) ||
        phase == GamePhase.levelComplete ||
        phase == GamePhase.gameOver;
    if (!hideGhosts) _paintGhosts(canvas, reduceFlashing);
    _paintPlayer(canvas);
    _paintPopups(canvas);
    _paintBanner(canvas);

    canvas.restore();
  }

  void _paintPowerBraces(Canvas canvas) {
    final e = engine;
    final blinkOn =
        e.phase != GamePhase.playing || (e.clock * 4).floor().isEven;
    if (!blinkOn) return;
    final tp = text('{}', Palette.brace, 0.78);
    for (final t in e.maze.powerBraceTiles) {
      if (e.maze.itemAt(t) != Collectible.powerBrace) continue;
      _glowPaint.color = Palette.brace.withValues(alpha: 0.35);
      canvas.drawCircle(Offset(t.col + 0.5, t.row + 0.5), 0.55, _glowPaint);
      _centered(canvas, tp, t.col + 0.55, t.row + 0.52);
    }
  }

  void _paintBonus(Canvas canvas) {
    final e = engine;
    if (!e.bonusVisible) return;
    final item = e.config.bonus;
    final color = Color(item.color);
    final bob = math.sin(e.clock * 5) * 0.08;
    _glowPaint.color = color.withValues(alpha: 0.35);
    canvas.drawCircle(
      const Offset(GameEngine.bonusX, GameEngine.bonusY),
      0.8,
      _glowPaint,
    );
    final tp = text(item.glyph, color, 0.62);
    _centered(canvas, tp, GameEngine.bonusX, GameEngine.bonusY + bob);
  }

  /// Last skin (TypeScript or not) each ghost was drawn with, and the
  /// engine clock when it changed; drives the JS <-> TS flip animation.
  final Map<GhostKind, (bool, double)> _skins = {};

  static const double _flipSeconds = 0.3;

  void _paintGhosts(Canvas canvas, bool reduceFlashing) {
    final e = engine;
    final wobble = (e.clock * 8).floor().isEven;
    final flashWhite = e.frightFlashWhite && !reduceFlashing;
    for (final g in e.ghosts.reversed) {
      if (e.phase == GamePhase.ghostEaten && g.kind == e.justEaten) continue;

      // Card-flip transition when a ghost changes language: squeeze to a
      // sliver showing the old logo, then open up showing the new one.
      final ts = g.frightened;
      final last = _skins[g.kind];
      var since = double.infinity;
      if (last == null || last.$1 != ts) {
        if (last != null && !g.isEyes && e.clock >= last.$2) {
          _skins[g.kind] = (ts, e.clock);
          since = 0;
        } else {
          _skins[g.kind] = (ts, double.negativeInfinity);
        }
      } else {
        since = e.clock - last.$2;
      }
      var skinTs = ts;
      var scaleX = 1.0;
      if (since >= 0 && since < _flipSeconds) {
        final p = since / _flipSeconds;
        scaleX = (math.cos(p * math.pi)).abs();
        if (p < 0.5) skinTs = !ts;
      }

      sprites.drawGhost(
        canvas,
        g.x,
        g.y,
        g.kind,
        g.dir,
        typescript: skinTs,
        flashWhite: skinTs && ts && flashWhite,
        eyesOnly: g.isEyes,
        wobble: wobble,
        scaleX: scaleX,
      );
    }
  }

  void _paintPlayer(Canvas canvas) {
    final e = engine;
    final p = e.player;
    if (e.phase == GamePhase.ghostEaten || e.phase == GamePhase.gameOver) {
      return;
    }
    if (e.phase == GamePhase.dying && e.deathProgress >= 1) return;
    final mouth = e.phase == GamePhase.ready
        ? 0.5
        : 0.08 + 0.72 * (math.sin(p.odometer * math.pi * 1.6)).abs();
    sprites.drawPython(
      canvas,
      p.x,
      p.y,
      p.dir,
      mouth: mouth,
      dying: e.deathProgress,
    );
  }

  void _paintPopups(Canvas canvas) {
    final e = engine;
    final gp = e.ghostPopup;
    if (gp != null && e.phase == GamePhase.ghostEaten) {
      _centered(
        canvas,
        text('${gp.points}', Palette.tsBlue.withValues(alpha: 1), 0.55),
        gp.x,
        gp.y,
      );
    }
    final bp = e.bonusPopup;
    if (bp != null) {
      _centered(canvas, text('${bp.points}', Palette.door, 0.55), bp.x, bp.y);
    }
  }

  void _paintBanner(Canvas canvas) {
    final e = engine;
    switch (e.phase) {
      case GamePhase.ready:
        _centered(canvas, text('READY!', Palette.ready, 0.9), 14, 17.5);
      case GamePhase.gameOver:
        _centered(canvas, text('GAME  OVER', Palette.danger, 0.9), 14, 17.5);
      default:
        break;
    }
  }
}

/// Repaints the board whenever [repaint] ticks (once per frame).
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.renderer,
    required this.devicePixelRatio,
    required this.reduceFlashing,
    required super.repaint,
  });

  final BoardRenderer renderer;
  final double devicePixelRatio;
  final bool reduceFlashing;

  @override
  void paint(Canvas canvas, Size size) => renderer.paint(
    canvas,
    size,
    devicePixelRatio: devicePixelRatio,
    reduceFlashing: reduceFlashing,
  );

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.renderer != renderer ||
      old.devicePixelRatio != devicePixelRatio ||
      old.reduceFlashing != reduceFlashing;
}
