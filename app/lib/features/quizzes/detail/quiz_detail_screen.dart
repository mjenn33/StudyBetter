import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_core/quiz_core.dart';

import '../library/quiz_library_filter.dart';
import '../quiz_actions.dart';
import '../quiz_routes.dart';

/// Overview of one quiz with its main actions. Stats are added in #28.
class QuizDetailScreen extends ConsumerWidget {
  const QuizDetailScreen({super.key, required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(quizEntryProvider(quizId));

    return switch (entry) {
      AsyncData(value: final entry?) => Scaffold(
        appBar: AppBar(
          title: Text(entry.document.title),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) async {
                if (value == 'duplicate') {
                  await QuizActions.duplicate(context, ref, entry.document);
                } else if (value == 'delete') {
                  final router = GoRouter.of(context);
                  await QuizActions.delete(context, ref, entry.document);
                  router.go(QuizPaths.library);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (entry.document.description.isNotEmpty) ...[
              Text(entry.document.description),
              const SizedBox(height: 16),
            ],
            _Facts(
              questions: entry.document.questions.length,
              settings: entry.document.settings,
            ),
            if (entry.document.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in entry.document.tags) Chip(label: Text(tag)),
                ],
              ),
            ],
            if (entry.isReadOnly) ...[
              const SizedBox(height: 16),
              Text(
                'Downloaded from ${entry.ownerName ?? 'the catalog'}. '
                'Make a copy to edit it.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: entry.document.questions.isEmpty
                      ? null
                      : () => context.go(QuizPaths.play(quizId)),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                ),
                if (entry.isReadOnly)
                  OutlinedButton.icon(
                    onPressed: () =>
                        QuizActions.duplicate(context, ref, entry.document),
                    icon: const Icon(Icons.copy),
                    label: const Text('Make a copy'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => context.go(QuizPaths.edit(quizId)),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
              ],
            ),
          ],
        ),
      ),
      AsyncData() => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This quiz no longer exists.')),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Could not load the quiz: $error')),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.questions, required this.settings});

  final int questions;
  final QuizSettings settings;

  @override
  Widget build(BuildContext context) {
    final limit = settings.timeLimitSeconds;
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      children: [
        _Fact(
          icon: Icons.help_outline,
          text: '$questions ${questions == 1 ? 'question' : 'questions'}',
        ),
        _Fact(
          icon: Icons.timer_outlined,
          text: limit == null ? 'No time limit' : _formatDuration(limit),
        ),
        _Fact(
          icon: Icons.flag_outlined,
          text: 'Pass at ${settings.passingScorePercent}%',
        ),
      ],
    );
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes == 0) return '$rest s';
    return rest == 0 ? '$minutes min' : '$minutes min $rest s';
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(text)],
    );
  }
}
