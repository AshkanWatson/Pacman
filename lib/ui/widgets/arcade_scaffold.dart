import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'arcade_button.dart';

/// Shared layout for the secondary screens: a title, scrollable content
/// constrained to a readable width, and a BACK button (Esc also works).
class ArcadeScaffold extends StatelessWidget {
  const ArcadeScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    void back() => Navigator.of(context).maybePop();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): back,
        const SingleActivator(LogicalKeyboardKey.backspace): back,
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final compact = box.maxWidth < 420;
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, compact ? 16 : 28, 16, 8),
                    child: Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: ArcadeText.title(compact ? 20 : 28),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            subtitle!,
                            textAlign: TextAlign.center,
                            style: ArcadeText.code(compact ? 8 : 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: ListView(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 16 : 24,
                            vertical: 12,
                          ),
                          children: children,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 4),
                    child: ArcadeButton(
                      label: 'BACK',
                      fontSize: 12,
                      autofocus: true,
                      onPressed: back,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A titled panel used on the secondary screens.
class ArcadePanel extends StatelessWidget {
  const ArcadePanel({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Palette.surface,
      border: Border.all(color: Palette.wall.withValues(alpha: 0.45)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ArcadeText.heading(11)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}
