import 'package:go_router/go_router.dart';

import '../../app/placeholder_page.dart';
import 'detail/quiz_detail_screen.dart';
import 'editor/quiz_editor_screen.dart';

/// Paths of the quiz screens, under the Quizzes tab.
abstract final class QuizPaths {
  static const library = '/quizzes';
  static const create = '/quizzes/new';
  static String detail(String id) => '/quizzes/$id';
  static String edit(String id) => '/quizzes/$id/edit';
  static String play(String id) => '/quizzes/$id/play';
}

/// Routes nested under [QuizPaths.library].
final quizRoutes = <RouteBase>[
  GoRoute(path: 'new', builder: (context, state) => const QuizEditorScreen()),
  GoRoute(
    path: ':id',
    builder: (context, state) =>
        QuizDetailScreen(quizId: state.pathParameters['id']!),
    routes: [
      GoRoute(
        path: 'edit',
        builder: (context, state) =>
            QuizEditorScreen(quizId: state.pathParameters['id']),
      ),
      // TODO(#22): quiz player.
      GoRoute(
        path: 'play',
        builder: (context, state) => const PlaceholderPage(title: 'Play'),
      ),
    ],
  ),
];
