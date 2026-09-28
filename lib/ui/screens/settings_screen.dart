import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../services/settings.dart';
import '../theme.dart';
import '../widgets/arcade_button.dart';
import '../widgets/arcade_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final s = services.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => ArcadeScaffold(
        title: 'SETTINGS',
        subtitle: '~/.pyman/config.json',
        children: [
          ArcadePanel(
            title: 'AUDIO',
            child: Column(
              children: [
                _ToggleRow(
                  label: 'Sound effects',
                  value: s.sfx,
                  onChanged: (v) => s.sfx = v,
                ),
                _ToggleRow(
                  label: 'Music & siren',
                  value: s.music,
                  onChanged: (v) => s.music = v,
                ),
                _Row(
                  label: 'Volume',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Slider(
                      value: s.volume,
                      divisions: 10,
                      label: '${(s.volume * 100).round()}%',
                      onChanged: (v) => s.volume = v,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ArcadePanel(
            title: 'GAMEPLAY',
            child: Column(
              children: [
                _Row(
                  label: 'Starting lives',
                  child: _Segmented<int>(
                    values: const [3, 5],
                    labelOf: (v) => '$v',
                    selected: s.startingLives,
                    onSelected: (v) => s.startingLives = v,
                  ),
                ),
                _Row(
                  label: 'Touch controls',
                  child: _Segmented<TouchControls>(
                    values: TouchControls.values,
                    labelOf: (v) => v.label,
                    selected: s.touch,
                    onSelected: (v) => s.touch = v,
                  ),
                ),
              ],
            ),
          ),
          ArcadePanel(
            title: 'DISPLAY',
            child: Column(
              children: [
                _ToggleRow(
                  label: 'CRT scanlines',
                  value: s.crt,
                  onChanged: (v) => s.crt = v,
                ),
                _ToggleRow(
                  label: 'Reduce flashing',
                  value: s.reduceFlashing,
                  onChanged: (v) => s.reduceFlashing = v,
                ),
                _ToggleRow(
                  label: 'Show FPS (--verbose)',
                  value: s.showFps,
                  onChanged: (v) => s.showFps = v,
                ),
              ],
            ),
          ),
          ArcadePanel(
            title: 'DATA',
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                ArcadeButton(
                  label: 'RESET HIGH SCORES',
                  fontSize: 9,
                  color: Palette.danger,
                  onPressed: () => _confirm(
                    context,
                    'rm -rf high_scores?',
                    services.highScores.clear,
                  ),
                ),
                ArcadeButton(
                  label: 'RESET ACHIEVEMENTS',
                  fontSize: 9,
                  color: Palette.danger,
                  onPressed: () => _confirm(
                    context,
                    'git reset --hard achievements?',
                    s.resetAchievements,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    String question,
    Future<void> Function() action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.surface,
        title: Text(question, style: ArcadeText.heading(11)),
        content: Text('This cannot be undone.', style: ArcadeText.dim(9)),
        actions: [
          ArcadeButton(
            label: 'CANCEL',
            fontSize: 10,
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
          ),
          ArcadeButton(
            label: 'DELETE',
            fontSize: 10,
            color: Palette.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok ?? false) await action();
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(flex: 2, child: Text(label, style: ArcadeText.body(9))),
        const SizedBox(width: 12),
        Flexible(
          flex: 3,
          child: Align(alignment: Alignment.centerRight, child: child),
        ),
      ],
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Row(
      children: [
        Expanded(child: Text(label, style: ArcadeText.body(9))),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
  });

  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    alignment: WrapAlignment.end,
    children: [
      for (final v in values)
        ChoiceChip(
          label: Text(
            labelOf(v),
            style: ArcadeText.base.copyWith(
              fontSize: 8,
              color: v == selected ? Palette.background : Palette.text,
            ),
          ),
          selected: v == selected,
          showCheckmark: false,
          selectedColor: Palette.pythonYellow,
          backgroundColor: Palette.surfaceHigh,
          side: BorderSide(color: Palette.wall.withValues(alpha: 0.5)),
          onSelected: (_) => onSelected(v),
        ),
    ],
  );
}
