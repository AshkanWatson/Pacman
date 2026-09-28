import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../game/achievements.dart';
import 'storage.dart';

/// How touch input is offered.
enum TouchControls {
  /// Swipe anywhere; the on-screen joystick shows on touch devices.
  auto('Auto'),
  swipe('Swipe only'),
  dpad('D-pad + swipe');

  const TouchControls(this.label);
  final String label;
}

/// User preferences and unlocked achievements, persisted locally.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store) {
    final json = readJson(_store, _key);
    if (json is Map<String, dynamic>) {
      _sfx = json['sfx'] as bool? ?? _sfx;
      _music = json['music'] as bool? ?? _music;
      _volume = (json['volume'] as num?)?.toDouble() ?? _volume;
      _startingLives = json['lives'] as int? ?? _startingLives;
      _crt = json['crt'] as bool? ?? _crt;
      _reduceFlashing = json['reduceFlashing'] as bool? ?? _reduceFlashing;
      _showFps = json['fps'] as bool? ?? _showFps;
      _playerName = json['name'] as String? ?? _playerName;
      final touch = json['touch'] as String?;
      _touch = TouchControls.values.firstWhere(
        (t) => t.name == touch,
        orElse: () => TouchControls.auto,
      );
    }
    final ach = readJson(_store, _achievementsKey);
    if (ach is List) {
      for (final name in ach) {
        for (final a in Achievement.values) {
          if (a.name == name) _achievements.add(a);
        }
      }
    }
  }

  static const _key = 'settings_v1';
  static const _achievementsKey = 'achievements_v1';

  final KeyValueStore _store;

  bool _sfx = true;
  bool _music = true;
  double _volume = 0.8;
  int _startingLives = 3;
  bool _crt = false;
  bool _reduceFlashing = false;
  bool _showFps = false;
  String _playerName = 'DEV';
  TouchControls _touch = TouchControls.auto;
  final Set<Achievement> _achievements = {};

  bool get sfx => _sfx;
  bool get music => _music;
  double get volume => _volume;
  int get startingLives => _startingLives;
  bool get crt => _crt;
  bool get reduceFlashing => _reduceFlashing;
  bool get showFps => _showFps;
  String get playerName => _playerName;
  TouchControls get touch => _touch;
  Set<Achievement> get achievements => Set.unmodifiable(_achievements);

  set sfx(bool v) => _update(() => _sfx = v);
  set music(bool v) => _update(() => _music = v);
  set volume(double v) => _update(() => _volume = v.clamp(0.0, 1.0));
  set startingLives(int v) => _update(() => _startingLives = v.clamp(1, 9));
  set crt(bool v) => _update(() => _crt = v);
  set reduceFlashing(bool v) => _update(() => _reduceFlashing = v);
  set showFps(bool v) => _update(() => _showFps = v);
  set touch(TouchControls v) => _update(() => _touch = v);
  set playerName(String v) {
    final clean = v.toUpperCase().replaceAll(RegExp('[^A-Z0-9_]'), '');
    if (clean.isEmpty) return;
    _update(
      () => _playerName = clean.length > 3 ? clean.substring(0, 3) : clean,
    );
  }

  /// Records [earned] achievements; returns true if anything was new.
  bool unlock(Iterable<Achievement> earned) {
    final before = _achievements.length;
    _achievements.addAll(earned);
    if (_achievements.length == before) return false;
    _store.write(
      _achievementsKey,
      jsonEncode([for (final a in _achievements) a.name]),
    );
    notifyListeners();
    return true;
  }

  Future<void> resetAchievements() async {
    _achievements.clear();
    await _store.remove(_achievementsKey);
    notifyListeners();
  }

  void _update(void Function() change) {
    change();
    _store.write(
      _key,
      jsonEncode({
        'sfx': _sfx,
        'music': _music,
        'volume': _volume,
        'lives': _startingLives,
        'crt': _crt,
        'reduceFlashing': _reduceFlashing,
        'fps': _showFps,
        'name': _playerName,
        'touch': _touch.name,
      }),
    );
    notifyListeners();
  }
}
