import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/providers.dart';
import '../../data/repositories/statistics_repository.dart';

final globalStatisticsProvider = FutureProvider.autoDispose<GlobalStatistics>(
  (ref) => ref.read(statisticsRepositoryProvider).global(),
);

/// The app-wide quiz metrics dashboard.
class GlobalStatisticsScreen extends ConsumerWidget {
  const GlobalStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: switch (ref.watch(globalStatisticsProvider)) {
        AsyncData(:final value) => _Dashboard(statistics: value),
        AsyncError(:final error) => Center(
          child: Text('Could not load statistics: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.statistics});

  final GlobalStatistics statistics;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricTile(
            label: 'Quizzes taken',
            value: '${statistics.quizzesTaken}',
            icon: Icons.quiz_outlined,
          ),
          _MetricTile(
            label: 'Questions answered',
            value: '${statistics.questionsAnswered}',
            icon: Icons.question_answer_outlined,
          ),
          _MetricTile(
            label: 'Overall accuracy',
            value: '${statistics.overallAccuracy.round()}%',
            icon: Icons.check_circle_outline,
          ),
        ],
      ),
      const SizedBox(height: 28),
      Text('Activity', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(
        'Quiz attempts in the last 30 days',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 220,
        child: _ActivityChart(days: statistics.attemptsPerDay),
      ),
      const SizedBox(height: 28),
      Text('Flashcards', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      const Text('Flashcard review metrics will appear here as you study.'),
    ],
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 148,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.days});

  final List<DailyAttemptCount> days;

  @override
  Widget build(BuildContext context) {
    final maxCount = days.fold(
      0,
      (max, day) => day.count > max ? day.count : max,
    );
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxCount + 1).toDouble(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
            ),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barGroups: [
          for (final (index, day) in days.indexed)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: day.count.toDouble(),
                  color: Theme.of(context).colorScheme.primary,
                  width: 5,
                  borderRadius: BorderRadius.zero,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
