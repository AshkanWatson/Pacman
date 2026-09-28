import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_scope.dart';
import 'ui/screens/menu_screen.dart';
import 'ui/theme.dart';

class PyManApp extends StatefulWidget {
  const PyManApp({super.key, required this.services});

  final AppServices services;

  @override
  State<PyManApp> createState() => _PyManAppState();
}

class _PyManAppState extends State<PyManApp> {
  @override
  void initState() {
    super.initState();
    widget.services.settings.addListener(_applyAudioSettings);
    _applyAudioSettings();
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_applyAudioSettings);
    super.dispose();
  }

  void _applyAudioSettings() {
    final s = widget.services.settings;
    widget.services.audio.configure(
      sfx: s.sfx,
      music: s.music,
      volume: s.volume,
    );
  }

  @override
  Widget build(BuildContext context) => AppScope(
    services: widget.services,
    child: MaterialApp(
      title: 'PY-MAN',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Arrow keys move between menu entries on every platform (the web
      // defaults map them to scrolling instead).
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            const DirectionalFocusIntent(TraversalDirection.up),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            const DirectionalFocusIntent(TraversalDirection.down),
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            const DirectionalFocusIntent(TraversalDirection.left),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            const DirectionalFocusIntent(TraversalDirection.right),
      },
      home: const MenuScreen(),
    ),
  );
}
