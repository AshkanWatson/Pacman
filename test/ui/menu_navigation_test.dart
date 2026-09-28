import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyman/game/achievements.dart';
import 'package:pyman/services/audio_service.dart';

import '../test_helpers.dart';

void main() {
  testWidgets('main menu shows every entry', (tester) async {
    setScreen(tester, const Size(1280, 800));
    await pumpApp(tester, testServices());
    for (final label in [
      'START GAME',
      'HOW TO PLAY',
      'HIGH SCORES',
      'SETTINGS',
      'ABOUT',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('PY-MAN'), findsOneWidget);
  });

  testWidgets('menu plays music and navigates to each screen and back', (
    tester,
  ) async {
    setScreen(tester, const Size(1280, 800));
    final audio = SilentAudioService();
    await pumpApp(tester, testServices(audio: audio));
    expect(audio.current, Loop.menuMusic);

    const screens = {
      'HOW TO PLAY': 'THE MISSION',
      'HIGH SCORES': 'LEADERBOARD',
      'SETTINGS': 'AUDIO',
      'ABOUT': 'CREDITS',
    };
    for (final MapEntry(key: button, value: marker) in screens.entries) {
      await tester.tap(find.text(button));
      await settle(tester);
      expect(find.text(marker), findsOneWidget, reason: button);
      await tester.tap(find.text('BACK'));
      await settle(tester);
      expect(find.text('START GAME'), findsOneWidget);
    }
  });

  testWidgets('keyboard: Esc closes a secondary screen', (tester) async {
    setScreen(tester, const Size(1280, 800));
    await pumpApp(tester, testServices());
    await tester.tap(find.text('ABOUT'));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('START GAME'), findsOneWidget);
  });

  testWidgets('keyboard: Enter on the focused entry starts the game', (
    tester,
  ) async {
    setScreen(tester, const Size(1280, 800));
    await pumpApp(tester, testServices());
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.text('HIGH SCORE'), findsOneWidget);
  });

  testWidgets('Konami code unlocks sudo and toggles CRT', (tester) async {
    setScreen(tester, const Size(1280, 800));
    final services = testServices();
    await pumpApp(tester, services);
    for (final k in [
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
    ]) {
      await tester.sendKeyEvent(k);
      await tester.pump();
    }
    expect(services.settings.achievements, contains(Achievement.sudo));
    expect(services.settings.crt, isTrue);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('settings toggles persist through the controller', (
    tester,
  ) async {
    setScreen(tester, const Size(1280, 900));
    final services = testServices();
    await pumpApp(tester, services);
    await tester.tap(find.text('SETTINGS'));
    await settle(tester);
    expect(services.settings.sfx, isTrue);
    await tester.tap(find.byType(Switch).first);
    await settle(tester);
    expect(services.settings.sfx, isFalse);
    expect(services.audio.sfxEnabled, isFalse);
  });

  for (final size in const [
    Size(320, 568), // small phone
    Size(390, 844), // phone
    Size(844, 390), // phone landscape
    Size(1024, 1366), // tablet portrait
    Size(1920, 1080), // desktop
  ]) {
    testWidgets('secondary screens fit at $size', (tester) async {
      setScreen(tester, size);
      await pumpApp(tester, testServices());
      for (final button in [
        'HOW TO PLAY',
        'HIGH SCORES',
        'SETTINGS',
        'ABOUT',
      ]) {
        await tester.ensureVisible(find.text(button));
        await tester.tap(find.text(button));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('BACK'));
        await settle(tester);
      }
    });
  }
}
