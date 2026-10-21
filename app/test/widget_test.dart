import 'package:flutter_test/flutter_test.dart';
import 'package:study_better/app/app.dart';

void main() {
  testWidgets('app starts and shows its name', (tester) async {
    await tester.pumpWidget(const StudyBetterApp());

    expect(find.text('StudyBetter'), findsOneWidget);
  });
}
