import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/arcade_scaffold.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const version = '1.0.0';

  @override
  Widget build(BuildContext context) => ArcadeScaffold(
    title: 'ABOUT',
    subtitle: 'pyman --version  ->  $version',
    children: [
      ArcadePanel(
        title: 'PY-MAN',
        child: Text(
          'An open-source arcade maze game for developers, built with '
          'Flutter. Python munches semicolons while JavaScript ghosts give '
          'chase - until a power brace adds types and turns them into '
          'TypeScript.\n\n'
          'Ghost behaviour follows the original arcade: scatter/chase '
          'waves, per-ghost targeting, frightened wandering, tunnel '
          'slow-down, Cruise Elroy and the ghost-house dot counters.',
          style: ArcadeText.body(8),
        ),
      ),
      ArcadePanel(
        title: 'CREDITS',
        child: Text(
          '- Font: "Press Start 2P" by CodeMan38, SIL Open Font License '
          '1.1.\n'
          '- Sound & music: synthesised from scratch by '
          'tool/generate_audio.dart (no third-party samples).\n'
          '- Gameplay research: "The Pac-Man Dossier" by Jamey Pittman.\n'
          '- Character skins: the Python, JavaScript and TypeScript logos, '
          'redrawn as vector sprites. Python is a trademark of the PSF, '
          'TypeScript of Microsoft; the JS logo is a community logo. Used '
          'for non-commercial parody.\n'
          '- Pac-Man is a trademark of Bandai Namco. This is an unaffiliated '
          'fan tribute.',
          style: ArcadeText.body(8),
        ),
      ),
      ArcadePanel(
        title: 'LICENSE',
        child: Text(
          'MIT License. Fork it, mod it, ship it. PRs welcome.',
          style: ArcadeText.body(8),
        ),
      ),
      Center(
        child: Text(
          '// no semicolons were harmed in the making of this game.\n'
          '// ok, 244 per level were.',
          textAlign: TextAlign.center,
          style: ArcadeText.code(8),
        ),
      ),
    ],
  );
}
