import 'package:flutter/material.dart';

/// Arcade palette: an editor-dark background with Python and JS/TS brand
/// accents.
abstract final class Palette {
  static const background = Color(0xFF05070D);
  static const surface = Color(0xFF0D1220);
  static const surfaceHigh = Color(0xFF151C2E);
  static const wall = Color(0xFF3D7BFF);
  static const wallGlow = Color(0xFF1F4FD1);
  static const door = Color(0xFFFFA8E0);
  static const semicolon = Color(0xFFE9E2CF);
  static const brace = Color(0xFFFFD43B);
  static const pythonBlue = Color(0xFF3776AB);
  static const pythonBlueLight = Color(0xFF4B8BBE);
  static const pythonYellow = Color(0xFFFFD43B);
  static const jsYellow = Color(0xFFF7DF1E);
  static const tsBlue = Color(0xFF3178C6);
  static const text = Color(0xFFE6EDF3);
  static const textDim = Color(0xFF8B949E);
  static const console = Color(0xFF3FB950);
  static const danger = Color(0xFFFF5370);
  static const ready = Color(0xFFFFD43B);
}

const String arcadeFont = 'PressStart2P';

abstract final class ArcadeText {
  static const TextStyle base = TextStyle(
    fontFamily: arcadeFont,
    color: Palette.text,
    height: 1.5,
    letterSpacing: 0.5,
  );

  static TextStyle title(double size) => base.copyWith(
    fontSize: size,
    color: Palette.pythonYellow,
    height: 1.2,
    shadows: const [
      Shadow(color: Palette.pythonBlue, offset: Offset(3, 3)),
      Shadow(color: Color(0x88FFD43B), blurRadius: 18),
    ],
  );

  static TextStyle heading([double size = 14]) =>
      base.copyWith(fontSize: size, color: Palette.pythonYellow);

  static TextStyle body([double size = 10]) =>
      base.copyWith(fontSize: size, height: 1.9);

  static TextStyle dim([double size = 9]) =>
      base.copyWith(fontSize: size, color: Palette.textDim, height: 1.8);

  static TextStyle code([double size = 9]) =>
      base.copyWith(fontSize: size, color: Palette.console);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.pythonBlue,
    brightness: Brightness.dark,
    surface: Palette.surface,
    primary: Palette.pythonYellow,
    secondary: Palette.tsBlue,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.background,
    fontFamily: arcadeFont,
    splashFactory: NoSplash.splashFactory,
    focusColor: Palette.pythonYellow.withValues(alpha: 0.12),
    hoverColor: Palette.pythonYellow.withValues(alpha: 0.08),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Palette.pythonYellow,
      selectionColor: Palette.pythonBlue,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Palette.pythonYellow
            : Palette.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Palette.pythonBlue
            : Palette.surfaceHigh,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Palette.pythonYellow,
      thumbColor: Palette.pythonYellow,
      inactiveTrackColor: Palette.surfaceHigh,
    ),
  );
}
