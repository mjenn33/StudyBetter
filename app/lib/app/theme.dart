import 'package:flutter/material.dart';

const _seedColor = Colors.indigo;

/// Material 3 theme for the given [brightness].
ThemeData buildTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    ),
  );
}
