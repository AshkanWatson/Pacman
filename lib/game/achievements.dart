import 'game_events.dart';

/// Unlockable developer achievements.
enum Achievement {
  helloWorld('Hello, World!', 'Eat your first semicolon.'),
  strictMode('"strict": true', 'Convert all 4 JS ghosts in one power-up.'),
  shipIt('Ship It!', 'Clear level 1.'),
  zeroBugs('Zero Bugs', 'Clear a level without losing a life.'),
  bracketMatcher('Bracket Matcher', 'Eat 3 bonus brackets in one game.'),
  garbageCollector('Garbage Collector', 'Collect 12 ghosts in one game.'),
  stackOverflow('Stack Overflow', 'Score 10,000 points and earn a life.'),
  majorVersion('v5.0.0', 'Reach level 5.'),
  rubberDuck('Rubber Duck', 'Hit the breakpoint (pause) 5 times in one game.'),
  sudo('sudo !!', 'Enter the Konami code on the main menu.');

  const Achievement(this.title, this.description);

  final String title;
  final String description;
}

/// Watches game events and reports achievements the moment they are earned.
///
/// Pure Dart so it is trivially testable; persistence lives elsewhere.
class AchievementTracker {
  AchievementTracker([Set<Achievement>? unlocked]) : unlocked = {...?unlocked};

  final Set<Achievement> unlocked;

  int _ghostsThisGame = 0;
  int _bonusThisGame = 0;
  int _pausesThisGame = 0;

  void startGame() {
    _ghostsThisGame = 0;
    _bonusThisGame = 0;
    _pausesThisGame = 0;
  }

  /// Returns the achievements newly unlocked by [event].
  List<Achievement> onEvent(GameEvent event) {
    final earned = <Achievement>[];
    void check(Achievement a, bool condition) {
      if (condition && unlocked.add(a)) earned.add(a);
    }

    switch (event) {
      case SemicolonEaten():
        check(Achievement.helloWorld, true);
      case GhostEaten(:final chain):
        _ghostsThisGame++;
        check(Achievement.strictMode, chain >= 4);
        check(Achievement.garbageCollector, _ghostsThisGame >= 12);
      case BonusEaten():
        _bonusThisGame++;
        check(Achievement.bracketMatcher, _bonusThisGame >= 3);
      case ExtraLifeAwarded():
        check(Achievement.stackOverflow, true);
      case LevelCleared(:final level, :final deathless):
        check(Achievement.shipIt, level >= 1);
        check(Achievement.zeroBugs, deathless);
      case LevelStarted(:final level):
        check(Achievement.majorVersion, level >= 5);
      default:
        break;
    }
    return earned;
  }

  List<Achievement> onPause() {
    _pausesThisGame++;
    if (_pausesThisGame >= 5 && unlocked.add(Achievement.rubberDuck)) {
      return const [Achievement.rubberDuck];
    }
    return const [];
  }

  List<Achievement> onKonami() =>
      unlocked.add(Achievement.sudo) ? const [Achievement.sudo] : const [];
}
