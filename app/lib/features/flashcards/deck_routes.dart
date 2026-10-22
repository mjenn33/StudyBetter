import 'package:go_router/go_router.dart';

import 'deck_editor_screen.dart';
import 'flashcard_study_screen.dart';

/// Paths of the flashcard-deck screens, under the Flashcards tab.
abstract final class DeckPaths {
  static const library = '/flashcards';
  static const create = '/flashcards/new';
  static String edit(String id) => '/flashcards/$id/edit';
  static String study(String id, {bool cram = false}) =>
      '/flashcards/$id/study${cram ? '?mode=cram' : ''}';
}

/// Routes nested under [DeckPaths.library].
final deckRoutes = <RouteBase>[
  GoRoute(path: 'new', builder: (context, state) => const DeckEditorScreen()),
  GoRoute(
    path: ':id/edit',
    builder: (context, state) =>
        DeckEditorScreen(deckId: state.pathParameters['id']),
  ),
  GoRoute(
    path: ':id/study',
    builder: (context, state) => FlashcardStudyScreen(
      deckId: state.pathParameters['id']!,
      cram: state.uri.queryParameters['mode'] == 'cram',
    ),
  ),
];
