import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// One-shot sound effects.
enum Sfx {
  chompA('chomp_a', 2),
  chompB('chomp_b', 2),
  power('power', 1),
  eatGhost('eat_ghost', 2),
  eyes('eyes', 1),
  bonus('bonus', 1),
  death('death', 1),
  extraLife('extra_life', 1),
  levelComplete('level_complete', 1),
  start('start', 1),
  gameOver('game_over', 1),
  click('click', 2),
  achievement('achievement', 1);

  const Sfx(this.file, this.voices);
  final String file;
  final int voices;
}

/// Looping background layers. Only one plays at a time.
enum Loop {
  menuMusic('menu_music'),
  siren('siren_loop'),
  fright('fright_loop');

  const Loop(this.file);
  final String file;
}

/// Game-facing audio API. Implementations must never throw: sound is
/// polish, never a reason to crash.
abstract class AudioService {
  bool sfxEnabled = true;
  bool musicEnabled = true;
  double volume = 0.8;

  /// Applies user settings.
  void configure({
    required bool sfx,
    required bool music,
    required double volume,
  }) {
    sfxEnabled = sfx;
    musicEnabled = music;
    this.volume = volume;
  }

  Future<void> init();
  void play(Sfx sfx);

  /// Switches the looping layer (null stops it).
  void loop(Loop? loop);
  void dispose();
}

/// Used by tests and whenever audio is unavailable.
class SilentAudioService extends AudioService {
  final List<Sfx> played = [];
  Loop? current;

  @override
  Future<void> init() async {}

  @override
  void play(Sfx sfx) {
    if (sfxEnabled) played.add(sfx);
  }

  @override
  void loop(Loop? loop) => current = musicEnabled ? loop : null;

  @override
  void configure({
    required bool sfx,
    required bool music,
    required double volume,
  }) {
    super.configure(sfx: sfx, music: music, volume: volume);
    if (!music) current = null;
  }

  @override
  void dispose() {}
}

/// Real audio backed by `package:audioplayers`.
class ArcadeAudioService extends AudioService {
  final Map<Sfx, AudioPool> _pools = {};
  AudioPlayer? _loopPlayer;
  Loop? _requestedLoop;
  Loop? _playingLoop;
  bool _ready = false;
  Future<void> _loopQueue = Future.value();

  static const _prefix = 'audio/';

  @override
  Future<void> init() async {
    try {
      _loopPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await Future.wait([
        for (final s in Sfx.values)
          AudioPool.createFromAsset(
            path: '$_prefix${s.file}.wav',
            maxPlayers: s.voices,
          ).then((pool) => _pools[s] = pool),
      ]);
      _ready = true;
      _applyLoop();
    } catch (e) {
      debugPrint('Audio unavailable: $e');
    }
  }

  @override
  void play(Sfx sfx) {
    if (!sfxEnabled || !_ready) return;
    final pool = _pools[sfx];
    if (pool == null) return;
    unawaited(pool.start(volume: volume).then<void>((_) {}, onError: _log));
  }

  @override
  void loop(Loop? loop) {
    _requestedLoop = loop;
    _applyLoop();
  }

  @override
  void configure({
    required bool sfx,
    required bool music,
    required double volume,
  }) {
    super.configure(sfx: sfx, music: music, volume: volume);
    _applyLoop(force: true);
  }

  void _applyLoop({bool force = false}) {
    final player = _loopPlayer;
    if (player == null || !_ready) return;
    final target = musicEnabled ? _requestedLoop : null;
    final changed = target != _playingLoop;
    if (!changed && !force) return;
    _playingLoop = target;
    // Serialise loop changes so rapid switches never interleave.
    _loopQueue = _loopQueue.then((_) async {
      try {
        if (target == null) {
          await player.stop();
          return;
        }
        await player.setVolume(
          target == Loop.menuMusic ? volume * 0.7 : volume,
        );
        if (!changed) return;
        await player.stop();
        await player.play(AssetSource('$_prefix${target.file}.wav'));
      } catch (e) {
        _log(e);
      }
    });
  }

  static void _log(Object e) => debugPrint('Audio error: $e');

  @override
  void dispose() {
    for (final pool in _pools.values) {
      unawaited(pool.dispose().catchError(_log));
    }
    _pools.clear();
    unawaited(_loopPlayer?.dispose().catchError(_log));
    _loopPlayer = null;
  }
}
