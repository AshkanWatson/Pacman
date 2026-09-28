import 'dart:math';

import 'entities/js_ghost.dart';
import 'game_events.dart';

/// The small "console" line under the maze: developer jokes reacting to
/// what happens in the game.
class DevMessages {
  DevMessages([Random? random]) : _random = random ?? Random();

  final Random _random;

  String _pick(List<String> options) =>
      options[_random.nextInt(options.length)];

  static const ready = [
    '>>> import pyman',
    '>>> python3 main.py',
    '\$ pip install --upgrade courage',
    '>>> from maze import semicolons',
    '\$ git checkout -b fix/javascript',
  ];

  static const pauseQuips = [
    'Breakpoint hit. Take your time.',
    'Explaining the bug to a rubber duck...',
    'Paused. Unlike prod, which never sleeps.',
    'Debugger attached. Inspect freely.',
    'Coffee break? We\'ll keep the stack warm.',
  ];

  static const gameOverQuips = [
    'Process finished with exit code 1',
    'Segmentation fault (core dumped)',
    'FATAL: undefined is not a function',
    'Build failed. Have you tried turning it off and on again?',
    'Uncaught TypeError: python.lives is 0',
  ];

  String readyLine() => _pick(ready);
  String pauseQuip() => _pick(pauseQuips);
  String gameOverQuip() => _pick(gameOverQuips);

  /// A message for [event], or null when the event is too minor to report.
  String? forEvent(GameEvent event) {
    switch (event) {
      case LevelStarted(:final level, :final firstOfGame):
        return firstOfGame ? readyLine() : '>>> level_$level.run()';
      case PowerBraceEaten():
        return _pick(const [
          '\$ tsc --init  # JS -> TS',
          'Types added. JavaScript is now TypeScript!',
          '{ } acquired: "strict": true',
          'npm i -D typescript',
        ]);
      case GhostEaten(:final ghost, :final chain):
        if (chain == 4) return 'All ghosts typed. --strict mode achieved!';
        return switch (ghost) {
          GhostKind.undefined => 'Caught: undefined -> never',
          GhostKind.nan => 'Caught: NaN -> number',
          GhostKind.nullGhost => 'Caught: null -> strictNullChecks',
          GhostKind.looseEquals => 'Caught: == -> ===',
        };
      case FrightEnded():
        return 'Type checking disabled. Beware of JS.';
      case BonusSpawned(:final item):
        return 'A wild ${item.glyph} ${item.label} appeared!';
      case BonusEaten(:final item):
        return '${item.glyph} ${item.label} parsed: +${item.points}';
      case BonusExpired():
        return 'Bonus garbage collected.';
      case PlayerCaught(:final by):
        return switch (by) {
          GhostKind.undefined =>
            'TypeError: Cannot read properties of undefined',
          GhostKind.nan => 'NaN !== NaN. Neither is your life.',
          GhostKind.nullGhost => 'NullPointerException (wrong language?)',
          GhostKind.looseEquals => "'' == 0 // true. Game logic: false.",
        };
      case ExtraLifeAwarded():
        return 'Found the answer on Stack Overflow: +1 life';
      case LevelCleared(:final deathless):
        return deathless
            ? '[OK] All tests passed. Zero bugs shipped.'
            : _pick(const [
                '[OK] Build passed.',
                '[OK] Merged to main.',
                '[OK] Deployed on a Friday.',
                '[OK] LGTM, ship it.',
              ]);
      case GameOver():
        return gameOverQuip();
      default:
        return null;
    }
  }
}
