import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyman/game/game_engine.dart';
import 'package:pyman/services/audio_service.dart';
import 'package:pyman/ui/screens/game_screen.dart';

import '../test_helpers.dart';

void main() {
  Future<GameEngine> startGame(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    SilentAudioService? audio,
    dynamic services,
  }) async {
    setScreen(tester, size);
    late GameEngine engine;
    await tester.pumpWidget(
      host(
        services ?? testServices(audio: audio),
        GameScreen(seed: 1, onEngineCreated: (e) => engine = e),
      ),
    );
    await tester.pump();
    return engine;
  }

  for (final size in const [
    Size(320, 568),
    Size(390, 844),
    Size(844, 390),
    Size(768, 1024),
    Size(1024, 768),
    Size(1920, 1080),
    Size(2560, 1080),
  ]) {
    testWidgets('renders and runs at $size without layout errors', (
      tester,
    ) async {
      final engine = await startGame(tester, size: size);
      await runFrames(tester, const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
      expect(engine.phase, isNot(GamePhase.ready));
      expect(find.text('1UP'), findsOneWidget);
    });
  }

  testWidgets('arrow keys steer Python', (tester) async {
    final engine = await startGame(tester);
    await runFrames(tester, const Duration(milliseconds: 4300));
    expect(engine.phase, GamePhase.playing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(engine.player.desired, Direction.right);
    await runFrames(tester, const Duration(milliseconds: 100));
    expect(engine.player.dir, Direction.right);
  });

  testWidgets('WASD and vim keys steer too', (tester) async {
    final engine = await startGame(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    expect(engine.player.desired, Direction.up);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    expect(engine.player.desired, Direction.down);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    expect(engine.player.desired, Direction.left);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    expect(engine.player.desired, Direction.right);
  });

  testWidgets('swipes steer Python', (tester) async {
    final engine = await startGame(tester, size: const Size(390, 844));
    await tester.dragFrom(const Offset(200, 400), const Offset(0, -80));
    await tester.pump();
    expect(engine.player.desired, Direction.up);
    await tester.dragFrom(const Offset(200, 400), const Offset(80, 0));
    await tester.pump();
    expect(engine.player.desired, Direction.right);
  });

  testWidgets('pause, resume and restart', (tester) async {
    final audio = SilentAudioService();
    final engine = await startGame(tester, audio: audio);
    await runFrames(tester, const Duration(milliseconds: 4500));
    expect(audio.current, Loop.siren);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(engine.paused, isTrue);
    expect(find.text('BREAKPOINT'), findsOneWidget);
    expect(audio.current, isNull, reason: 'siren stops while paused');

    final clock = engine.clock;
    await runFrames(tester, const Duration(milliseconds: 500));
    expect(engine.clock, clock, reason: 'time frozen while paused');

    await tester.tap(find.text('RESUME'));
    await tester.pump();
    expect(engine.paused, isFalse);
    expect(find.text('BREAKPOINT'), findsNothing);
    await runFrames(tester, const Duration(milliseconds: 200));
    expect(engine.clock, greaterThan(clock));

    engine.score = 500;
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(engine.paused, isFalse);
    expect(engine.score, 0);
    expect(engine.phase, GamePhase.ready);
  });

  testWidgets('pause button works with touch/mouse', (tester) async {
    final engine = await startGame(tester, size: const Size(390, 844));
    await tester.tap(find.byTooltip('Pause (P / Esc)'));
    await tester.pump();
    expect(engine.paused, isTrue);
    await tester.tap(find.text('RESTART'));
    await tester.pump();
    expect(engine.paused, isFalse);
  });

  testWidgets('game over offers initials entry and saves the score', (
    tester,
  ) async {
    final services = testServices();
    setScreen(tester, const Size(1280, 800));
    late GameEngine engine;
    await tester.pumpWidget(
      host(services, GameScreen(seed: 1, onEngineCreated: (e) => engine = e)),
    );
    await tester.pump();
    await runFrames(tester, const Duration(milliseconds: 4300));

    engine.lives = 1;
    engine.score = 4200;
    final ghost = engine.ghost(GhostKind.undefined);
    ghost.placeAt(engine.player.x, engine.player.y, Direction.left);
    await runFrames(tester, const Duration(seconds: 3));

    expect(engine.phase, GamePhase.gameOver);
    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.text('NEW HIGH SCORE! ENTER INITIALS'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'gvr');
    await tester.tap(find.text('SAVE SCORE'));
    await settle(tester);
    expect(services.highScores.entries.single.name, 'GVR');
    expect(services.highScores.entries.single.score, 4200);
    expect(find.textContaining('#1 on the leaderboard'), findsOneWidget);

    await tester.tap(find.text('PLAY AGAIN'));
    await tester.pump();
    expect(engine.phase, GamePhase.ready);
    expect(find.text('GAME OVER'), findsNothing);
  });

  testWidgets('game events trigger sounds', (tester) async {
    final audio = SilentAudioService();
    final engine = await startGame(tester, audio: audio);
    await runFrames(tester, const Duration(milliseconds: 100));
    expect(audio.played, contains(Sfx.start));
    await runFrames(tester, const Duration(milliseconds: 4600));
    expect(
      audio.played.where((s) => s == Sfx.chompA || s == Sfx.chompB),
      isNotEmpty,
    );
    expect(engine.score, greaterThan(0));
  });
}
