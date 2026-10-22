import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/providers.dart';

final themeModeProvider = FutureProvider<ThemeMode>((ref) async {
  final value = await ref
      .watch(settingsRepositoryProvider)
      .read('themeMode', 'system');
  return ThemeMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ThemeMode.system,
  );
});
