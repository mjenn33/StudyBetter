import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/providers.dart';
import '../../data/repositories/statistics_repository.dart';
import '../quizzes/library/quiz_library_filter.dart';
import '../quizzes/quiz_routes.dart';
import '../play/player_screen.dart';

final quizStatisticsProvider = FutureProvider.autoDispose
    .family<QuizStatistics, String>(
      (ref, quizId) => ref.read(statisticsRepositoryProvider).forQuiz(quizId),
    );

/// Score trend and attempt history for one quiz.
class QuizStatisticsScreen extends ConsumerWidget {
  const QuizStatisticsScreen({super.key, required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiz = ref.watch(quizEntryProvider(quizId));
    final statistics = ref.watch(quizStatisticsProvider(quizId));
    final entry = quiz.asData?.value;
    final title = entry?.document.title ?? 'Quiz statistics';
    final passingScore = entry?.document.settings.passingScorePercent ?? 70;

    return Scaffold(
      appBar: AppBar(title: Text('$title statistics')),
      body: switch (statistics) {
        AsyncData(:final value) => _StatisticsBody(
          quizId: quizId,
          statistics: value,
          passingScorePercent: passingScore,
          questionPrompts: {
            for (final question in entry?.document.questions ?? const [])
              question.id: question.prompt,
          },
        ),
        AsyncError(:final error) => Center(
          child: Text('Could not load statistics: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _StatisticsBody extends StatelessWidget {
  const _StatisticsBody({
    required this.quizId,
    required this.statistics,
    required this.passingScorePercent,
    required this.questionPrompts,
  });

  final String quizId;
  final QuizStatistics statistics;
  final int passingScorePercent;
  final Map<String, String> questionPrompts;

  @override
  Widget build(BuildContext context) {
    if (statistics.scores.isEmpty) {
      return const Center(
        child: Text('No attempts yet. Play this quiz to see statistics.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryTile(
              label: 'Attempts',
              value: '${statistics.attemptCount}',
              icon: Icons.format_list_numbered,
            ),
            _SummaryTile(
              label: 'Best',
              value: _percent(statistics.bestScore!.percent),
              icon: Icons.emoji_events_outlined,
            ),
            _SummaryTile(
              label: 'Average',
              value: _percent(statistics.averageScorePercent),
              icon: Icons.analytics_outlined,
            ),
            _SummaryTile(
              label: 'Last',
              value: _percent(statistics.lastScore!.percent),
              icon: Icons.flag_outlined,
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text('Score trend', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: _ScoreTrendChart(
            scores: statistics.scores,
            passingScorePercent: passingScorePercent,
          ),
        ),
        const SizedBox(height: 28),
        if (statistics.questionAccuracy.isNotEmpty) ...[
          Text(
            'Weakest questions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final accuracy in statistics.questionAccuracy)
            ListTile(
              title: Text(
                questionPrompts[accuracy.questionId] ??
                    'Removed question (${accuracy.questionId})',
              ),
              subtitle: Text(
                '${accuracy.correctCount} of ${accuracy.answerCount} correct',
              ),
              trailing: Text(_percent(accuracy.percent)),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => context.go(QuizPaths.practice(quizId)),
            icon: const Icon(Icons.school_outlined),
            label: const Text('Practice weakest questions'),
          ),
          const SizedBox(height: 28),
        ],
        Text('Attempt history', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final score in statistics.scores.reversed)
          Card(
            child: ListTile(
              leading: Icon(
                score.percent >= passingScorePercent
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
              ),
              title: Text(_percent(score.percent)),
              subtitle: Text(_formatDate(score.recordedAt)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.go(QuizPaths.review(quizId, score.attemptId)),
            ),
          ),
      ],
    );
  }

  static String _percent(double value) => '${value.round()}%';

  static String _formatDate(DateTime value) {
    final date = value.toLocal();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Starts a normal player session restricted to the five weakest current
/// questions. The player records this as a practice attempt.
class PracticeWeakestScreen extends ConsumerWidget {
  const PracticeWeakestScreen({super.key, required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statistics = ref.watch(quizStatisticsProvider(quizId));
    final entry = ref.watch(quizEntryProvider(quizId));
    return switch ((statistics, entry)) {
      (AsyncData(:final value), AsyncData(value: final quiz?)) => () {
        final currentIds = {
          for (final question in quiz.document.questions) question.id,
        };
        final ids = value.questionAccuracy
            .where((accuracy) => currentIds.contains(accuracy.questionId))
            .take(5)
            .map((accuracy) => accuracy.questionId)
            .toSet();
        return ids.isEmpty
            ? Scaffold(
                appBar: AppBar(title: const Text('Practice weakest questions')),
                body: const Center(
                  child: Text('No current questions have practice data yet.'),
                ),
              )
            : PlayerScreen(quizId: quizId, practiceQuestionIds: ids);
      }(),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 132,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _ScoreTrendChart extends StatelessWidget {
  const _ScoreTrendChart({
    required this.scores,
    required this.passingScorePercent,
  });

  final List<AttemptScore> scores;
  final int passingScorePercent;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return LineChart(
      LineChartData(
        minX: 1,
        maxX: scores.length.toDouble(),
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: passingScorePercent.toDouble(),
              color: Theme.of(context).colorScheme.secondary,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                labelResolver: (_) => 'Pass $passingScorePercent%',
              ),
            ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text('Attempt ${value.toInt()}'),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: 25,
              getTitlesWidget: (value, meta) => Text('${value.toInt()}%'),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final (index, score) in scores.indexed)
                FlSpot(index + 1.0, score.percent),
            ],
            color: color,
            barWidth: 3,
            isCurved: false,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}
