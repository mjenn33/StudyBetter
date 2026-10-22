import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_core/quiz_core.dart';

import '../../data/repositories/providers.dart';
import 'quiz_routes.dart';

/// Library actions shared by the library list and the detail screen.
abstract final class QuizActions {
  /// Makes an editable copy of [quiz] and offers to open it.
  static Future<void> duplicate(
    BuildContext context,
    WidgetRef ref,
    Quiz quiz,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final copy = await ref.read(quizRepositoryProvider).duplicate(quiz.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Created "${copy.title}"'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => router.go(QuizPaths.detail(copy.id)),
          ),
        ),
      );
  }

  /// Deletes [quiz] and shows a snack bar to undo it.
  static Future<void> delete(
    BuildContext context,
    WidgetRef ref,
    Quiz quiz,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(quizRepositoryProvider);
    await repository.delete(quiz.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${quiz.title}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repository.restore(quiz.id),
          ),
        ),
      );
  }

  /// Placeholder until file import lands (#20).
  static void import(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Importing quiz files is coming soon.')),
    );
  }
}
