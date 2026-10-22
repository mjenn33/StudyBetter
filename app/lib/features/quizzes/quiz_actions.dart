import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_core/quiz_core.dart';

import '../../data/repositories/providers.dart';
import 'quiz_readiness.dart';
import 'quiz_routes.dart';
import 'transfer/quiz_files.dart';
import 'transfer/quiz_transfer.dart';

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

  /// Saves [quiz] to a `.json` file the user picks. Quizzes with problems
  /// can't be exported.
  static Future<void> export(
    BuildContext context,
    WidgetRef ref,
    Quiz quiz,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final problems = quiz.problems;
    if (problems.isNotEmpty) {
      _show(messenger, blockedMessage('export', problems.length));
      return;
    }
    final saved = await ref
        .read(quizFilesProvider)
        .saveJson(exportFileName(quiz), exportQuizJson(quiz));
    if (saved) _show(messenger, 'Exported "${quiz.title}"');
  }

  /// Imports a quiz from a `.json` file: reads it (upgrading older formats),
  /// shows its problems, and asks what to do when the quiz is already in the
  /// library.
  static Future<void> import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final file = await ref.read(quizFilesProvider).pickJson();
    if (file == null || !context.mounted) return;

    final Quiz quiz;
    final List<ValidationIssue> problems;
    try {
      (quiz, problems) = readQuizFile(file.contents);
    } on QuizImportException catch (e) {
      await _showError(context, 'Can\'t import ${file.name}', e.message);
      return;
    }

    if (problems.isNotEmpty) {
      if (!context.mounted) return;
      final proceed = await _confirmDraftImport(context, quiz, problems);
      if (!proceed) return;
    }

    final importer = QuizImporter(ref.read(quizRepositoryProvider));
    final existing = await importer.existing(quiz);
    ImportConflictChoice? choice;
    if (existing != null) {
      if (!context.mounted) return;
      choice = await _askConflict(context, existing);
      if (choice == null) return;
    }

    final stored = await importer.import(quiz, choice: choice);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Imported "${stored.title}"'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => router.go(QuizPaths.detail(stored.id)),
          ),
        ),
      );
  }

  static void _show(ScaffoldMessengerState messenger, String message) =>
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));

  static Future<void> _showError(
    BuildContext context,
    String title,
    String message,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  static Future<bool> _confirmDraftImport(
    BuildContext context,
    Quiz quiz,
    List<ValidationIssue> problems,
  ) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${quiz.title}" has ${problemCount(problems.length)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You can import it as a draft and fix it in the editor. '
                'It can\'t be played until then.',
              ),
              const SizedBox(height: 12),
              for (final p in problems.take(5)) Text('• ${p.message}'),
              if (problems.length > 5)
                Text('• and ${problems.length - 5} more'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import as draft'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  static Future<ImportConflictChoice?> _askConflict(
    BuildContext context,
    ExistingQuiz existing,
  ) => showDialog<ImportConflictChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Quiz already in your library'),
      content: Text(
        existing.canReplace
            ? 'This file is a version of "${existing.title}". Replace it with '
                  'the file, or import the file as a separate copy?'
            : 'This file is a version of "${existing.title}", which you '
                  'downloaded and can\'t change. Import the file as a '
                  'separate copy?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (existing.canReplace)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, ImportConflictChoice.replace),
            child: const Text('Replace'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, ImportConflictChoice.copy),
          child: const Text('Import as copy'),
        ),
      ],
    ),
  );
}
