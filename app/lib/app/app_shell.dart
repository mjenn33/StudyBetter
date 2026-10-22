import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'destinations.dart';

/// Window width from which the navigation rail replaces the bottom bar.
const wideLayoutBreakpoint = 600.0;

/// Scaffold around the top-level sections: a [NavigationRail] on wide
/// screens (desktop, tablets) and a [NavigationBar] on narrow ones.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // Tapping the current section again returns to its first page.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _help(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Keyboard shortcuts'),
      content: const SingleChildScrollView(
        child: Text(
          'Ctrl+1–5: switch sections\nF1: show this help\nTab / Shift+Tab: move focus\nEnter / Space: activate focused control\nEscape: close dialogs',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.f1): () => _help(context),
      for (var i = 0; i < appDestinations.length; i++)
        SingleActivator(
          [
            LogicalKeyboardKey.digit1,
            LogicalKeyboardKey.digit2,
            LogicalKeyboardKey.digit3,
            LogicalKeyboardKey.digit4,
            LogicalKeyboardKey.digit5,
          ][i],
          control: true,
        ): () =>
            _onDestinationSelected(i),
    },
    child: Focus(autofocus: true, child: _layout(context)),
  );

  Widget _layout(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;
    final selectedIndex = navigationShell.currentIndex;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              trailing: IconButton(
                tooltip: 'Keyboard shortcuts (F1)',
                onPressed: () => _help(context),
                icon: const Icon(Icons.help_outline),
              ),
              selectedIndex: selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in appDestinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          for (final d in appDestinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
