import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../services/audio_service.dart';
import '../theme.dart';

/// A keyboard-, mouse- and touch-friendly arcade menu entry.
///
/// Shows a blinking `>` cursor when focused or hovered, activates with
/// Enter/Space, click or tap.
class ArcadeButton extends StatefulWidget {
  const ArcadeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.autofocus = false,
    this.fontSize = 14,
    this.color = Palette.text,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool autofocus;
  final double fontSize;
  final Color color;
  final FocusNode? focusNode;

  @override
  State<ArcadeButton> createState() => _ArcadeButtonState();
}

class _ArcadeButtonState extends State<ArcadeButton> {
  bool _focused = false;
  bool _hovered = false;

  void _activate() {
    if (widget.onPressed == null) return;
    AppScope.of(context).audio.play(Sfx.click);
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    final enabled = widget.onPressed != null;
    final color = !enabled
        ? Palette.textDim
        : active
        ? Palette.pythonYellow
        : widget.color;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onFocusChange: (v) => setState(() => _focused = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _activate,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(
              vertical: widget.fontSize * 0.75,
              horizontal: widget.fontSize,
            ),
            decoration: BoxDecoration(
              color: active
                  ? Palette.pythonYellow.withValues(alpha: 0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: widget.fontSize * 1.6,
                  child: active ? _BlinkingCursor(size: widget.fontSize) : null,
                ),
                Flexible(
                  child: Text(
                    widget.label,
                    style: ArcadeText.base.copyWith(
                      fontSize: widget.fontSize,
                      color: color,
                    ),
                  ),
                ),
                SizedBox(width: widget.fontSize * 1.6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({required this.size});
  final double size;

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Opacity(
      opacity: _c.value < 0.6 ? 1 : 0,
      child: Text(
        '>',
        style: ArcadeText.base.copyWith(
          fontSize: widget.size,
          color: Palette.pythonYellow,
        ),
      ),
    ),
  );
}
