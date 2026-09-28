import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pyman/game/core/direction.dart';
import 'package:pyman/game/entities/js_ghost.dart';
import 'package:pyman/ui/render/logos.dart';
import 'package:pyman/ui/render/sprites.dart';

void main() {
  test('Python logo paths are normalised to a unit box around the origin', () {
    final all = Logos.pythonBlueSnake.getBounds().expandToInclude(
      Logos.pythonYellowSnake.getBounds(),
    );
    expect(all.left, greaterThanOrEqualTo(-0.51));
    expect(all.right, lessThanOrEqualTo(0.51));
    expect(all.top, greaterThanOrEqualTo(-0.51));
    expect(all.bottom, lessThanOrEqualTo(0.51));
    expect(all.width, greaterThan(0.9), reason: 'fills the sprite box');
    // The snakes' eyes are holes.
    expect(
      Logos.pythonBlueSnake.contains(const Offset(-0.135, -0.382)),
      isFalse,
    );
    expect(Logos.pythonBlueSnake.contains(const Offset(0.04, -0.145)), isTrue);
  });

  test('logo letters stay inside their glyph box', () {
    for (final p in [Logos.letterJ, Logos.letterS, Logos.letterT]) {
      final b = p.getBounds();
      expect(b.left, greaterThanOrEqualTo(0));
      expect(b.right, lessThanOrEqualTo(Logos.letterWidth));
      expect(b.top, greaterThanOrEqualTo(0));
      expect(b.bottom, lessThanOrEqualTo(1));
    }
  });

  test('every skin variant paints without errors', () {
    final kit = SpriteKit();
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    for (final d in Direction.values) {
      for (final mouth in [0.0, 0.4, 0.9]) {
        kit.drawPython(canvas, 1, 1, d, mouth: mouth);
      }
    }
    for (final t in [0.1, 0.5, 0.9, 1.0]) {
      kit.drawPython(canvas, 1, 1, Direction.left, dying: t);
    }
    for (final k in GhostKind.values) {
      for (final ts in [false, true]) {
        kit.drawGhost(canvas, 1, 1, k, Direction.up, typescript: ts);
        kit.drawGhost(
          canvas,
          1,
          1,
          k,
          Direction.up,
          typescript: ts,
          flashWhite: true,
          wobble: true,
        );
        kit.drawGhost(canvas, 1, 1, k, Direction.up, typescript: ts, scaleX: 0);
      }
      kit.drawGhost(canvas, 1, 1, k, Direction.left, eyesOnly: true);
    }
    recorder.endRecording().dispose();
  });
}
