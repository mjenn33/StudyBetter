import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/library_repository.dart';
import 'answer_review.dart';

/// Shows every saved answer alongside the correct answer and explanation.
class AnswerReviewScreen extends ConsumerStatefulWidget {
  const AnswerReviewScreen({
    super.key,
    required this.quizId,
    required this.attemptId,
  });

  final String quizId;
  final String attemptId;

  @override
  ConsumerState<AnswerReviewScreen> createState() => _AnswerReviewScreenState();
}

class _AnswerReviewScreenState extends ConsumerState<AnswerReviewScreen> {
  var _showIncorrectOnly = false;

  @override
  Widget build(BuildContext context) {
    return switch (ref.watch(answerReviewProvider(widget.attemptId))) {
      AsyncData(:final value) => _Review(
        review: value,
        showIncorrectOnly: _showIncorrectOnly,
        onFilterChanged: (incorrectOnly) =>
            setState(() => _showIncorrectOnly = incorrectOnly),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: const Text('Answer review')),
        body: Center(
          child: Text(
            error is ItemNotFoundException
                ? 'This attempt no longer exists.'
                : 'Could not load the answer review: $error',
          ),
        ),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _Review extends StatelessWidget {
  const _Review({
    required this.review,
    required this.showIncorrectOnly,
    required this.onFilterChanged,
  });

  final AnswerReview review;
  final bool showIncorrectOnly;
  final ValueChanged<bool> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final answers = showIncorrectOnly
        ? review.answers.where((item) => !item.answer.isCorrect).toList()
        : review.answers;

    return Scaffold(
      appBar: AppBar(title: Text('${review.quizTitle} review')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('All')),
              ButtonSegment(value: true, label: Text('Incorrect only')),
            ],
            selected: {showIncorrectOnly},
            onSelectionChanged: (selected) => onFilterChanged(selected.single),
          ),
          const SizedBox(height: 16),
          if (answers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No incorrect answers. Great work!')),
            ),
          for (final (index, item) in answers.indexed)
            _AnswerCard(number: index + 1, item: item),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.number, required this.item});

  final int number;
  final ReviewedAnswer item;

  @override
  Widget build(BuildContext context) {
    final question = item.question;
    final answer = item.answer;
    final scheme = Theme.of(context).colorScheme;
    final isCorrect = answer.isCorrect;

    if (question == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text('Question $number is no longer in this quiz'),
          subtitle: const Text('The question was removed after this attempt.'),
        ),
      );
    }

    String optionsFor(List<String> ids) {
      final byId = {
        for (final option in question.options) option.id: option.text,
      };
      return ids.map((id) => byId[id] ?? id).join(', ');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$number. ${question.prompt}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? scheme.primary : scheme.error,
                  semanticLabel: isCorrect ? 'Correct' : 'Incorrect',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AnswerLine(
              label: 'Your answer',
              value: answer.isSkipped
                  ? 'Skipped'
                  : optionsFor(answer.selectedOptionIds),
              color: isCorrect ? scheme.primary : scheme.error,
            ),
            const SizedBox(height: 8),
            _AnswerLine(
              label: 'Correct answer',
              value: optionsFor(question.correctOptionIds),
              color: scheme.primary,
            ),
            if (question.explanation case final explanation?) ...[
              const SizedBox(height: 12),
              Text(
                'Explanation',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 2),
              Text(explanation),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: RichText(
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: color),
          ),
        ],
      ),
    ),
  );
}
