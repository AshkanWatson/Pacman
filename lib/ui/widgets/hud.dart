import 'package:flutter/material.dart';

import '../../game/core/level_config.dart';
import '../theme.dart';
import 'sprite_icon.dart';

/// Immutable snapshot of what the HUD shows; compared each frame so the
/// HUD only rebuilds when a value actually changes.
@immutable
class HudData {
  const HudData({
    required this.score,
    required this.high,
    required this.lives,
    required this.level,
  });

  final int score;
  final int high;
  final int lives;
  final int level;

  @override
  bool operator ==(Object other) =>
      other is HudData &&
      other.score == score &&
      other.high == high &&
      other.lives == lives &&
      other.level == level;

  @override
  int get hashCode => Object.hash(score, high, lives, level);
}

class ScoreBlock extends StatelessWidget {
  const ScoreBlock({
    super.key,
    required this.label,
    required this.value,
    this.fontSize = 12,
    this.align = CrossAxisAlignment.start,
    this.blink = false,
  });

  final String label;
  final int value;
  final double fontSize;
  final CrossAxisAlignment align;
  final bool blink;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: align,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: ArcadeText.base.copyWith(
          fontSize: fontSize * 0.75,
          color: Palette.danger,
          height: 1.3,
        ),
      ),
      Text(
        value.toString(),
        style: ArcadeText.base.copyWith(fontSize: fontSize, height: 1.3),
      ),
    ],
  );
}

/// Spare lives as little Pythons.
class LivesRow extends StatelessWidget {
  const LivesRow({super.key, required this.spare, this.size = 18});
  final int spare;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shown = spare.clamp(0, 5);
    return Semantics(
      label: '$spare spare lives',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < shown; i++)
            Padding(
              padding: EdgeInsets.only(right: size * 0.25),
              child: PythonIcon(size: size),
            ),
          if (spare > 5)
            Text('+${spare - 5}', style: ArcadeText.dim(size * 0.45)),
        ],
      ),
    );
  }
}

/// Recent levels' bonus brackets, like the fruit row in the arcade.
class LevelRow extends StatelessWidget {
  const LevelRow({super.key, required this.level, this.size = 12});
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final first = (level - 6).clamp(1, level);
    return Semantics(
      label: 'Level $level',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var l = first; l <= level; l++)
            Padding(
              padding: EdgeInsets.only(left: size * 0.5),
              child: Text(
                BonusItem.forLevel(l).glyph,
                style: ArcadeText.base.copyWith(
                  fontSize: size,
                  color: Color(BonusItem.forLevel(l).color),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The one-line developer console under the maze.
class ConsoleLine extends StatelessWidget {
  const ConsoleLine({super.key, required this.message, this.fontSize = 9});
  final ValueNotifier<String> message;
  final double fontSize;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: message,
    builder: (context, value, _) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Text(
        value,
        key: ValueKey(value),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: ArcadeText.code(fontSize),
      ),
    ),
  );
}
