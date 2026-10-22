import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/library_repository.dart';
import '../quizzes/quiz_routes.dart';
import 'attempt_summary.dart';

/// Score and statistics of one finished attempt.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({
    super.key,
    required this.quizId,
    required this.attemptId,
  });

  final String quizId;
  final String attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(attemptSummaryProvider(attemptId))) {
      AsyncData(:final value) => _Results(
        quizId: quizId,
        attemptId: attemptId,
        summary: value,
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: Center(
          child: Text(
            error is ItemNotFoundException
                ? 'This attempt no longer exists.'
                : 'Could not load the results: $error',
          ),
        ),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.quizId,
    required this.attemptId,
    required this.summary,
  });

  final String quizId;
  final String attemptId;
  final AttemptSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final verdictColor = s.passed ? scheme.primary : scheme.error;

    return Scaffold(
      appBar: AppBar(title: Text(s.quizTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                Icon(
                  s.passed ? Icons.emoji_events_outlined : Icons.flag_outlined,
                  size: 56,
                  color: verdictColor,
                ),
                const SizedBox(height: 8),
                Text(
                  s.passed ? 'Passed' : 'Not passed',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: verdictColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.percent.round()}%',
                  style: theme.textTheme.displayMedium,
                  semanticsLabel: 'Score ${s.percent.round()} percent',
                ),
                Text(
                  '${s.points} / ${s.maxPoints} points · '
                  'pass mark ${s.passingScorePercent}%',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _Stat(label: 'Correct', value: '${s.correct}', icon: Icons.check),
              _Stat(
                label: 'Incorrect',
                value: '${s.incorrect}',
                icon: Icons.close,
              ),
              _Stat(label: 'Skipped', value: '${s.skipped}', icon: Icons.redo),
              _Stat(
                label: 'Total time',
                value: formatDuration(s.totalTime),
                icon: Icons.timer_outlined,
              ),
              _Stat(
                label: 'Per question',
                value: formatDuration(s.averageTimePerQuestion),
                icon: Icons.av_timer,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    context.go(QuizPaths.review(quizId, attemptId)),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review answers'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.replace(QuizPaths.play(quizId)),
                icon: const Icon(Icons.replay),
                label: const Text('Retry'),
              ),
              TextButton(
                onPressed: () => context.go(QuizPaths.library),
                child: const Text('Back to library'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 132,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.titleLarge),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
