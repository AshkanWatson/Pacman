import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyman/app.dart';
import 'package:pyman/app_scope.dart';
import 'package:pyman/services/audio_service.dart';
import 'package:pyman/services/high_scores.dart';
import 'package:pyman/services/settings.dart';
import 'package:pyman/services/storage.dart';
import 'package:pyman/ui/theme.dart';

AppServices testServices({KeyValueStore? store, SilentAudioService? audio}) {
  final s = store ?? MemoryStore();
  return AppServices(
    settings: SettingsController(s),
    highScores: HighScoreRepository(s),
    audio: audio ?? SilentAudioService(),
  );
}

/// Sets a logical screen size for the test.
void setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpApp(WidgetTester tester, AppServices services) async {
  await tester.pumpWidget(PyManApp(services: services));
  await tester.pump();
}

/// Wraps [child] with the app scope and theme, without the menu.
Widget host(AppServices services, Widget child) => AppScope(
  services: services,
  child: MaterialApp(theme: buildTheme(), home: child),
);

/// Advances real frames (so the game ticker sees small time steps).
Future<void> runFrames(WidgetTester tester, Duration total) async {
  const frame = Duration(milliseconds: 16);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(frame);
    elapsed += frame;
  }
}

/// Like pumpAndSettle, but tolerant of the endless arcade animations
/// (attract mode, blinking cursors, the game loop).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
