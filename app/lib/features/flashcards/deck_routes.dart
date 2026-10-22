import 'package:go_router/go_router.dart';

import 'deck_editor_screen.dart';

/// Paths of the flashcard-deck screens, under the Flashcards tab.
abstract final class DeckPaths {
  static const library = '/flashcards';
  static const create = '/flashcards/new';
  static String edit(String id) => '/flashcards/$id/edit';
}

/// Routes nested under [DeckPaths.library].
final deckRoutes = <RouteBase>[
  GoRoute(path: 'new', builder: (context, state) => const DeckEditorScreen()),
  GoRoute(
    path: ':id/edit',
    builder: (context, state) =>
        DeckEditorScreen(deckId: state.pathParameters['id']),
  ),
];
