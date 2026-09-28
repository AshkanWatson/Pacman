import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pyman/game/achievements.dart';
import 'package:pyman/game/dev_messages.dart';
import 'package:pyman/game/game_engine.dart';

void main() {
  group('AchievementTracker', () {
    test('first semicolon unlocks Hello, World! once', () {
      final t = AchievementTracker();
      expect(t.onEvent(const SemicolonEaten(243)), [Achievement.helloWorld]);
      expect(t.onEvent(const SemicolonEaten(242)), isEmpty);
    });

    test('four ghosts in one power-up unlocks strict mode', () {
      final t = AchievementTracker();
      for (var i = 1; i <= 3; i++) {
        expect(
          t.onEvent(GhostEaten(GhostKind.nan, 200 << (i - 1), i)),
          isEmpty,
        );
      }
      expect(t.onEvent(const GhostEaten(GhostKind.nan, 1600, 4)), [
        Achievement.strictMode,
      ]);
    });

    test('garbage collector counts ghosts across a game', () {
      final t = AchievementTracker()..startGame();
      final earned = <Achievement>[];
      for (var i = 0; i < 12; i++) {
        earned.addAll(t.onEvent(const GhostEaten(GhostKind.nan, 200, 1)));
      }
      expect(earned, contains(Achievement.garbageCollector));
    });

    test('level based achievements', () {
      final t = AchievementTracker();
      expect(t.onEvent(const LevelCleared(1, deathless: true)), [
        Achievement.shipIt,
        Achievement.zeroBugs,
      ]);
      expect(t.onEvent(const LevelStarted(4, firstOfGame: false)), isEmpty);
      expect(t.onEvent(const LevelStarted(5, firstOfGame: false)), [
        Achievement.majorVersion,
      ]);
    });

    test('bonus, extra life, pauses and konami', () {
      final t = AchievementTracker()..startGame();
      expect(t.onEvent(const BonusEaten(BonusItem.block)), isEmpty);
      expect(t.onEvent(const BonusEaten(BonusItem.block)), isEmpty);
      expect(t.onEvent(const BonusEaten(BonusItem.block)), [
        Achievement.bracketMatcher,
      ]);
      expect(t.onEvent(const ExtraLifeAwarded(4)), [Achievement.stackOverflow]);
      for (var i = 0; i < 4; i++) {
        expect(t.onPause(), isEmpty);
      }
      expect(t.onPause(), [Achievement.rubberDuck]);
      expect(t.onKonami(), [Achievement.sudo]);
      expect(t.onKonami(), isEmpty);
    });

    test('already unlocked achievements are not reported again', () {
      final t = AchievementTracker({Achievement.helloWorld});
      expect(t.onEvent(const SemicolonEaten(1)), isEmpty);
    });
  });

  group('DevMessages', () {
    final m = DevMessages(Random(1));

    test('reacts to the important events', () {
      expect(m.forEvent(const PowerBraceEaten()), isNotNull);
      expect(
        m.forEvent(const PlayerCaught(GhostKind.undefined)),
        contains('undefined'),
      );
      expect(
        m.forEvent(const GhostEaten(GhostKind.looseEquals, 200, 1)),
        contains('==='),
      );
      expect(
        m.forEvent(const GhostEaten(GhostKind.nan, 1600, 4)),
        contains('strict'),
      );
      expect(
        m.forEvent(const BonusEaten(BonusItem.emptyObject)),
        contains('100'),
      );
      expect(
        m.forEvent(const LevelCleared(1, deathless: true)),
        contains('Zero bugs'),
      );
    });

    test('stays quiet for frequent minor events', () {
      expect(m.forEvent(const SemicolonEaten(10)), isNull);
    });

    test('only uses glyphs available in the arcade font', () {
      final all = [
        ...DevMessages.ready,
        ...DevMessages.pauseQuips,
        ...DevMessages.gameOverQuips,
        for (final b in BonusItem.values) b.glyph,
      ];
      for (final s in all) {
        expect(s.runes.every((r) => r < 128), isTrue, reason: s);
      }
    });
  });

  group('LevelConfig', () {
    test('speeds and fright times follow the arcade tables', () {
      final l1 = LevelConfig.forLevel(1);
      expect(l1.playerSpeed, 0.80);
      expect(l1.ghostSpeed, 0.75);
      expect(l1.frightSeconds, 6);
      expect(l1.bonus, BonusItem.emptyObject);
      final l5 = LevelConfig.forLevel(5);
      expect(l5.playerSpeed, 1.0);
      expect(l5.modeSchedule.first, 5);
      expect(LevelConfig.forLevel(17).frightSeconds, 0);
      expect(LevelConfig.forLevel(21).playerSpeed, 0.9);
      expect(LevelConfig.forLevel(99).bonus, BonusItem.lambda);
    });

    test('bonus values escalate', () {
      final points = BonusItem.values.map((b) => b.points).toList();
      final sorted = [...points]..sort();
      expect(points, sorted);
    });
  });
}
