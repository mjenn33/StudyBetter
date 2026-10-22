import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_better/data/repositories/statistics_repository.dart';
import 'package:study_better/features/stats/global_statistics_screen.dart';

import '../../helpers.dart';

void main() {
  testWidgets('shows global totals and thirty-day activity chart', (tester) async {
    final db = testDatabase();
    final firstDay = DateTime.utc(2026, 10, 1);
    await pumpApp(
      tester,
      db: db,
      overrides: [
        globalStatisticsProvider.overrideWith(
          (ref) async => GlobalStatistics(
            quizzesTaken: 3,
            questionsAnswered: 18,
            correctAnswers: 12,
            attemptsPerDay: [
              for (var day = 0; day < 30; day++)
                DailyAttemptCount(
                  date: firstDay.add(Duration(days: day)),
                  count: day == 0 ? 2 : 0,
                ),
            ],
          ),
        ),
      ],
    );

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Quizzes taken'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('Questions answered'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('Overall accuracy'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Flashcards'), findsWidgets);
  });
}
