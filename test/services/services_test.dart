import 'package:flutter_test/flutter_test.dart';
import 'package:pyman/game/achievements.dart';
import 'package:pyman/services/audio_service.dart';
import 'package:pyman/services/high_scores.dart';
import 'package:pyman/services/settings.dart';
import 'package:pyman/services/storage.dart';

HighScoreEntry entry(String name, int score, [int level = 1]) => HighScoreEntry(
  name: name,
  score: score,
  level: level,
  date: DateTime(2026, 1, 1).add(Duration(minutes: score)),
);

void main() {
  group('HighScoreRepository', () {
    test('keeps the top 10 sorted and reports rank', () async {
      final repo = HighScoreRepository(MemoryStore());
      for (var i = 1; i <= 12; i++) {
        await repo.add(entry('P$i', i * 100));
      }
      expect(repo.entries, hasLength(10));
      expect(repo.best, 1200);
      expect(repo.entries.last.score, 300);
      expect(repo.qualifies(250), isFalse);
      expect(repo.qualifies(350), isTrue);
      expect(await repo.add(entry('TOP', 5000)), 0);
      expect(await repo.add(entry('LOW', 10)), -1);
    });

    test('persists across instances and survives corrupt data', () async {
      final store = MemoryStore();
      await HighScoreRepository(store).add(entry('GVR', 4242, 3));
      final reloaded = HighScoreRepository(store);
      expect(reloaded.entries.single.name, 'GVR');
      expect(reloaded.entries.single.level, 3);

      final broken = MemoryStore({'high_scores_v1': '{not json'});
      expect(HighScoreRepository(broken).entries, isEmpty);
    });

    test('zero never qualifies; clear empties the board', () async {
      final repo = HighScoreRepository(MemoryStore());
      expect(repo.qualifies(0), isFalse);
      await repo.add(entry('A', 10));
      await repo.clear();
      expect(repo.entries, isEmpty);
    });
  });

  group('SettingsController', () {
    test('defaults, persistence and validation', () {
      final store = MemoryStore();
      final s = SettingsController(store);
      expect(s.sfx, isTrue);
      expect(s.startingLives, 3);
      s
        ..sfx = false
        ..volume = 3
        ..startingLives = 5
        ..touch = TouchControls.dpad
        ..playerName = 'ada lovelace';
      final r = SettingsController(store);
      expect(r.sfx, isFalse);
      expect(r.volume, 1.0);
      expect(r.startingLives, 5);
      expect(r.touch, TouchControls.dpad);
      expect(r.playerName, 'ADA');
      r.playerName = '!!!';
      expect(r.playerName, 'ADA', reason: 'invalid names are ignored');
    });

    test('achievements are stored', () async {
      final store = MemoryStore();
      final s = SettingsController(store);
      expect(s.unlock([Achievement.helloWorld]), isTrue);
      expect(s.unlock([Achievement.helloWorld]), isFalse);
      expect(SettingsController(store).achievements, {Achievement.helloWorld});
      await s.resetAchievements();
      expect(SettingsController(store).achievements, isEmpty);
    });
  });

  group('SilentAudioService', () {
    test('respects enabled flags', () {
      final a = SilentAudioService();
      a.play(Sfx.power);
      a.loop(Loop.siren);
      expect(a.played, [Sfx.power]);
      expect(a.current, Loop.siren);
      a.configure(sfx: false, music: false, volume: 0.5);
      a.play(Sfx.death);
      a.loop(Loop.fright);
      expect(a.played, [Sfx.power]);
      expect(a.current, isNull);
    });
  });
}
