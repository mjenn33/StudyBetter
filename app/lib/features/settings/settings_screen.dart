import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/providers.dart';

/// Personal study preferences stored on this device.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(newCardsPerDayProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: switch (limit) {
        AsyncData(:final value) => ListView(
          children: [
            ListTile(
              title: const Text('New cards per day'),
              subtitle: const Text(
                'Maximum new cards included in due study sessions.',
              ),
              trailing: DropdownButton<int>(
                value: value,
                items: [10, 20, 30, 50, 100]
                    .map(
                      (number) => DropdownMenuItem(
                        value: number,
                        child: Text('$number'),
                      ),
                    )
                    .toList(),
                onChanged: (number) async {
                  if (number == null) return;
                  await ref
                      .read(settingsRepositoryProvider)
                      .setNewCardsPerDay(number);
                  ref.invalidate(newCardsPerDayProvider);
                },
              ),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
