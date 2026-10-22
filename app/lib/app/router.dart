import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/flashcards/deck_library_screen.dart';
import '../features/flashcards/deck_routes.dart';
import '../features/quizzes/library/quiz_library_screen.dart';
import '../features/quizzes/quiz_routes.dart';
import '../features/stats/global_statistics_screen.dart';
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
                  builder: (context, state) => _sectionPage(destination),
                  routes: _sectionRoutes(destination),
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

/// The root page of a section; sections not built yet show a placeholder.
Widget _sectionPage(AppDestination destination) => switch (destination.path) {
  QuizPaths.library => const QuizLibraryScreen(),
  DeckPaths.library => const DeckLibraryScreen(),
  '/stats' => const GlobalStatisticsScreen(),
  _ => PlaceholderPage(title: destination.label),
};

List<RouteBase> _sectionRoutes(AppDestination destination) =>
    switch (destination.path) {
      QuizPaths.library => quizRoutes,
      DeckPaths.library => deckRoutes,
      _ => const [],
    };
