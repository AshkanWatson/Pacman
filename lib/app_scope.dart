import 'package:flutter/widgets.dart';

import 'services/audio_service.dart';
import 'services/high_scores.dart';
import 'services/settings.dart';

/// App-wide services, created once in `main` (or a test) and handed down
/// the tree. Keeps the UI free of global singletons.
class AppServices {
  AppServices({
    required this.settings,
    required this.highScores,
    required this.audio,
  });

  final SettingsController settings;
  final HighScoreRepository highScores;
  final AudioService audio;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing from the widget tree');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.services != services;
}
