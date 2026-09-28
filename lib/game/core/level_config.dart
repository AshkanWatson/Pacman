/// Per-level tuning, modelled on the arcade tables documented in
/// "The Pac-Man Dossier" (Jamey Pittman).
///
/// Speeds are fractions of the arcade's 100% speed, which is
/// 75.75757625 px/s on an 8px tile, i.e. ~9.47 tiles per second.
class LevelConfig {
  const LevelConfig({
    required this.bonus,
    required this.playerSpeed,
    required this.playerFrightSpeed,
    required this.ghostSpeed,
    required this.ghostTunnelSpeed,
    required this.ghostFrightSpeed,
    required this.elroy1Dots,
    required this.elroy1Speed,
    required this.elroy2Dots,
    required this.elroy2Speed,
    required this.frightSeconds,
    required this.frightFlashes,
    required this.modeSchedule,
  });

  final BonusItem bonus;
  final double playerSpeed;
  final double playerFrightSpeed;
  final double ghostSpeed;
  final double ghostTunnelSpeed;
  final double ghostFrightSpeed;
  final int elroy1Dots;
  final double elroy1Speed;
  final int elroy2Dots;
  final double elroy2Speed;
  final double frightSeconds;
  final int frightFlashes;

  /// Alternating scatter/chase durations in seconds, starting with scatter.
  /// After the list is exhausted, ghosts chase forever.
  final List<double> modeSchedule;

  /// Arcade 100% speed in tiles per second.
  static const double baseTilesPerSecond = 75.75757625 / 8;

  /// Duration of one white/blue flash cycle while TypeScript wears off.
  static const double flashCycle = 0.4;

  /// How long before the end of a power-up the ghosts start flashing.
  double get flashWindow => frightFlashes * flashCycle;

  static LevelConfig forLevel(int level) {
    final l = level < 1 ? 1 : level;
    final bonus = BonusItem.forLevel(l);

    final (
      double pac,
      double pacFright,
      double ghost,
      double tunnel,
      double ghostFright,
    ) = switch (l) {
      1 => (0.80, 0.90, 0.75, 0.40, 0.50),
      <= 4 => (0.90, 0.95, 0.85, 0.45, 0.55),
      <= 20 => (1.00, 1.00, 0.95, 0.50, 0.60),
      _ => (0.90, 0.90, 0.95, 0.50, 0.60),
    };

    const elroyTable = <(int, double, int, double)>[
      (20, 0.80, 10, 0.85), // 1
      (30, 0.90, 15, 0.95), // 2
      (40, 0.90, 20, 0.95), // 3
      (40, 0.90, 20, 0.95), // 4
      (40, 1.00, 20, 1.05), // 5
      (50, 1.00, 25, 1.05), // 6
      (50, 1.00, 25, 1.05), // 7
      (50, 1.00, 25, 1.05), // 8
      (60, 1.00, 30, 1.05), // 9
      (60, 1.00, 30, 1.05), // 10
      (60, 1.00, 30, 1.05), // 11
      (80, 1.00, 40, 1.05), // 12
      (80, 1.00, 40, 1.05), // 13
      (80, 1.00, 40, 1.05), // 14
      (100, 1.00, 50, 1.05), // 15
      (100, 1.00, 50, 1.05), // 16
      (100, 1.00, 50, 1.05), // 17
      (100, 1.00, 50, 1.05), // 18
    ];
    final elroy = l <= elroyTable.length
        ? elroyTable[l - 1]
        : (120, 1.00, 60, 1.05);

    const frightTable = <(double, int)>[
      (6, 5), (5, 5), (4, 5), (3, 5), (2, 5), (5, 5), (2, 5), (2, 5), //
      (1, 3), (5, 5), (2, 5), (1, 3), (1, 3), (3, 5), (1, 3), (1, 3), //
      (0, 0), (1, 3),
    ];
    final fright = l <= frightTable.length ? frightTable[l - 1] : (0.0, 0);

    final schedule = switch (l) {
      1 => const <double>[7, 20, 7, 20, 5, 20, 5],
      <= 4 => const <double>[7, 20, 7, 20, 5, 1033, 1 / 60],
      _ => const <double>[5, 20, 5, 20, 5, 1037, 1 / 60],
    };

    return LevelConfig(
      bonus: bonus,
      playerSpeed: pac,
      playerFrightSpeed: pacFright,
      ghostSpeed: ghost,
      ghostTunnelSpeed: tunnel,
      ghostFrightSpeed: ghostFright,
      elroy1Dots: elroy.$1,
      elroy1Speed: elroy.$2,
      elroy2Dots: elroy.$3,
      elroy2Speed: elroy.$4,
      frightSeconds: fright.$1,
      frightFlashes: fright.$2,
      modeSchedule: schedule,
    );
  }
}

/// The bonus "fruit" of each level: a family of curly-bracket snacks.
enum BonusItem {
  emptyObject('{ }', 'empty object', 100, 0xFFFF5370),
  block('{;}', 'code block', 300, 0xFFFF79C6),
  arrayInObject('{[]}', 'array literal', 500, 0xFFFFB86C),
  callInObject('{()}', 'function call', 700, 0xFF50FA7B),
  spread('{...}', 'spread operator', 1000, 0xFF8BE9FD),
  template(r'${}', 'template literal', 2000, 0xFFBD93F9),
  mustache('{{}}', 'mustache', 3000, 0xFFF1FA8C),
  lambda('{=>}', 'lambda', 5000, 0xFFFFFFFF);

  const BonusItem(this.glyph, this.label, this.points, this.color);

  final String glyph;
  final String label;
  final int points;
  final int color;

  static BonusItem forLevel(int level) => switch (level) {
    <= 1 => emptyObject,
    2 => block,
    3 || 4 => arrayInObject,
    5 || 6 => callInObject,
    7 || 8 => spread,
    9 || 10 => template,
    11 || 12 => mustache,
    _ => lambda,
  };
}
