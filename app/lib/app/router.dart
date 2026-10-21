import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import 'destinations.dart';
import 'placeholder_page.dart';

/// The app router: one navigation branch per [appDestinations] entry,
/// wrapped in [AppShell].
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: appDestinations.first.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          for (final destination in appDestinations)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: destination.path,
                  builder: (context, state) =>
                      PlaceholderPage(title: destination.label),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
