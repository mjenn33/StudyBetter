import 'package:flutter/material.dart';
import 'package:quiz_core/quiz_core.dart';

export 'issue_index.dart';

/// Whether a quiz can be played and exported. Invalid quizzes can be saved
/// as drafts, but not played or shared.
extension QuizReadiness on Quiz {
  List<ValidationIssue> get problems => validateQuiz(this);

  bool get isPlayable => problems.isEmpty;
}

/// "1 problem" / "3 problems".
String problemCount(int count) =>
    '$count ${count == 1 ? 'problem' : 'problems'}';

/// Snack bar text for an action (play, export) blocked by [count] problems.
String blockedMessage(String action, int count) =>
    'This quiz has ${problemCount(count)}. Fix them in the editor to $action it.';

/// A warning box listing a quiz's problems.
class QuizProblemsCard extends StatelessWidget {
  const QuizProblemsCard({
    super.key,
    required this.problems,
    required this.message,
    this.maxShown = 3,
  });

  final List<ValidationIssue> problems;
  final String message;
  final int maxShown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = problems.take(maxShown).toList();
    final hidden = problems.length - shown.length;
    return Card(
      color: scheme.errorContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: scheme.onErrorContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: scheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(child: Text(message)),
                ],
              ),
              const SizedBox(height: 8),
              for (final p in shown) Text('• ${p.message}'),
              if (hidden > 0) Text('• and $hidden more'),
            ],
          ),
        ),
      ),
    );
  }
}

/// A validation message in the error color.
class ErrorText extends StatelessWidget {
  const ErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
