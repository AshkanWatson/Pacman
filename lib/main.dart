import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'app_scope.dart';
import 'services/audio_service.dart';
import 'services/high_scores.dart';
import 'services/settings.dart';
import 'services/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  KeyValueStore store;
  try {
    store = await SharedPrefsStore.open();
  } catch (e) {
    debugPrint('Persistent storage unavailable, using memory: $e');
    store = MemoryStore();
  }

  final audio = ArcadeAudioService();
  unawaited(audio.init());

  runApp(
    PyManApp(
      services: AppServices(
        settings: SettingsController(store),
        highScores: HighScoreRepository(store),
        audio: audio,
      ),
    ),
  );
}
