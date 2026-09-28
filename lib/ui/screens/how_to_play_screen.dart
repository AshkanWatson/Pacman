import 'package:flutter/material.dart';

import '../../game/core/level_config.dart';
import '../../game/entities/js_ghost.dart';
import '../theme.dart';
import '../widgets/arcade_scaffold.dart';
import '../widgets/sprite_icon.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) => ArcadeScaffold(
    title: 'HOW TO PLAY',
    subtitle: '\$ man pyman',
    children: [
      ArcadePanel(
        title: 'THE MISSION',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PythonIcon(size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'You are Python. Python never needed semicolons, so eat '
                'every last one in the maze to clear the level - while '
                'four JavaScript ghosts try to catch you.',
                style: ArcadeText.body(9),
              ),
            ),
          ],
        ),
      ),
      ArcadePanel(
        title: 'CONTROLS',
        child: Column(
          children: const [
            _KeyRow('ARROWS / WASD', 'Move (turns are buffered)'),
            _KeyRow('H J K L', 'Move, for vim users'),
            _KeyRow('SWIPE', 'Move on touch screens'),
            _KeyRow('D-PAD', 'On-screen joystick (touch)'),
            _KeyRow('P / ESC', 'Pause (breakpoint)'),
            _KeyRow('R', 'Restart while paused'),
            _KeyRow('M', 'Mute / unmute'),
          ],
        ),
      ),
      ArcadePanel(
        title: 'COLLECTIBLES',
        child: Column(
          children: [
            _ItemRow(
              glyph: ';',
              color: Palette.semicolon,
              title: 'Semicolon',
              text: '10 pts. Python does not need them.',
            ),
            _ItemRow(
              glyph: '{}',
              color: Palette.brace,
              title: 'Power brace',
              text:
                  '50 pts. Adds types: every ghost compiles to TypeScript '
                  'for a few seconds. TS ghosts are slow and edible: '
                  '200, 400, 800, 1600 pts in a row.',
            ),
            _ItemRow(
              glyph: BonusItem.emptyObject.glyph,
              color: Color(BonusItem.emptyObject.color),
              title: 'Bonus brackets',
              text:
                  'Appear twice per level below the ghost house. Worth '
                  '100 to 5000 pts:',
            ),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                for (final b in BonusItem.values)
                  Text(
                    '${b.glyph} ${b.points}',
                    style: ArcadeText.base.copyWith(
                      fontSize: 8,
                      color: Color(b.color),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      ArcadePanel(
        title: 'THE GHOSTS (JAVASCRIPT)',
        child: Column(
          children: [
            for (final g in GhostKind.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    GhostIcon(kind: g, size: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.label,
                            style: ArcadeText.base.copyWith(
                              fontSize: 10,
                              color: Color(g.color),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(g.blurb, style: ArcadeText.dim(8)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                const GhostIcon(
                  kind: GhostKind.undefined,
                  typescript: true,
                  size: 34,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'After a power brace the JS logos flip to TypeScript. When they '
                    'flash, the types are about to wear off!',
                    style: ArcadeText.dim(8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ArcadePanel(
        title: 'RULES & TIPS',
        child: Text(
          '- Ghosts alternate between scattering to their corners and '
          'chasing you, just like the arcade.\n'
          '- Ghosts slow down in the side tunnels. Use them.\n'
          '- When few semicolons remain, undefined speeds up.\n'
          '- Extra life at 10,000 pts (found on Stack Overflow).\n'
          '- Each level gets faster. There is no end. Like tech debt.',
          style: ArcadeText.body(8),
        ),
      ),
    ],
  );
}

class _KeyRow extends StatelessWidget {
  const _KeyRow(this.keys, this.action);
  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 130, child: Text(keys, style: ArcadeText.code(8))),
        Expanded(child: Text(action, style: ArcadeText.body(8))),
      ],
    ),
  );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.glyph,
    required this.color,
    required this.title,
    required this.text,
  });
  final String glyph;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              glyph,
              maxLines: 1,
              softWrap: false,
              style: ArcadeText.base.copyWith(fontSize: 16, color: color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ArcadeText.base.copyWith(fontSize: 9, color: color),
              ),
              const SizedBox(height: 4),
              Text(text, style: ArcadeText.dim(8)),
            ],
          ),
        ),
      ],
    ),
  );
}
