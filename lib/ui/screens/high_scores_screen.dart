import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../game/achievements.dart';
import '../theme.dart';
import '../widgets/arcade_scaffold.dart';

class HighScoresScreen extends StatelessWidget {
  const HighScoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([services.highScores, services.settings]),
      builder: (context, _) {
        final entries = services.highScores.entries;
        final unlocked = services.settings.achievements;
        return ArcadeScaffold(
          title: 'HIGH SCORES',
          subtitle: 'SELECT * FROM scores ORDER BY score DESC LIMIT 10;',
          children: [
            ArcadePanel(
              title: 'LEADERBOARD',
              child: entries.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '0 rows returned. Be the first!',
                        style: ArcadeText.dim(9),
                      ),
                    )
                  : Column(
                      children: [
                        _ScoreRow(
                          rank: 'RANK',
                          name: 'NAME',
                          score: 'SCORE',
                          level: 'LVL',
                          color: Palette.danger,
                        ),
                        const SizedBox(height: 6),
                        for (final (i, e) in entries.indexed)
                          _ScoreRow(
                            rank: '${i + 1}.',
                            name: e.name,
                            score: '${e.score}',
                            level: '${e.level}',
                            color: i == 0 ? Palette.pythonYellow : Palette.text,
                          ),
                      ],
                    ),
            ),
            ArcadePanel(
              title:
                  'ACHIEVEMENTS ${unlocked.length}/${Achievement.values.length}',
              child: Column(
                children: [
                  for (final a in Achievement.values)
                    _AchievementRow(
                      achievement: a,
                      unlocked: unlocked.contains(a),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.rank,
    required this.name,
    required this.score,
    required this.level,
    required this.color,
  });
  final String rank;
  final String name;
  final String score;
  final String level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = ArcadeText.base.copyWith(fontSize: 9, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(rank, style: style)),
          Expanded(child: Text(name, style: style)),
          Expanded(
            flex: 2,
            child: Text(score, style: style, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 48,
            child: Text(level, style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.achievement, required this.unlocked});
  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          unlocked ? '[x]' : '[ ]',
          style: ArcadeText.code(9)
              .copyWith(color: unlocked ? Palette.console : Palette.textDim),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unlocked ? achievement.title : '???',
                style: ArcadeText.base.copyWith(
                  fontSize: 9,
                  color: unlocked ? Palette.pythonYellow : Palette.textDim,
                ),
              ),
              const SizedBox(height: 4),
              Text(achievement.description, style: ArcadeText.dim(8)),
            ],
          ),
        ),
      ],
    ),
  );
}
