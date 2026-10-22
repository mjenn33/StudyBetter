import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_core/quiz_core.dart';

import 'question_edits.dart';

/// Opens [question] in a full-screen editor and returns the edited question,
/// or `null` if the user cancelled.
Future<Question?> editQuestion(
  BuildContext context,
  Question question, {
  bool isNew = false,
}) {
  return Navigator.of(context).push<Question>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => QuestionEditorScreen(question: question, isNew: isNew),
    ),
  );
}

/// Edits one question: prompt, type, options and correct answers,
/// explanation and points.
class QuestionEditorScreen extends StatefulWidget {
  const QuestionEditorScreen({
    super.key,
    required this.question,
    this.isNew = false,
  });

  final Question question;
  final bool isNew;

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  late Question _question = widget.question;
  late final _prompt = TextEditingController(text: _question.prompt);
  late final _explanation = TextEditingController(
    text: _question.explanation ?? '',
  );
  late final _points = TextEditingController(text: '${_question.points}');

  /// One text controller per option id, created as options are added.
  final _optionText = <String, TextEditingController>{};

  bool get _isDirty => _question != widget.question;

  TextEditingController _optionController(Option option) => _optionText
      .putIfAbsent(option.id, () => TextEditingController(text: option.text));

  @override
  void dispose() {
    _prompt.dispose();
    _explanation.dispose();
    _points.dispose();
    for (final controller in _optionText.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _edit(Question Function(Question q) change) =>
      setState(() => _question = change(_question));

  Future<void> _setType(QuestionType type) async {
    if (type == _question.type) return;
    if (type == QuestionType.single && _question.needsCorrectChoiceForSingle) {
      final keep = await _askWhichCorrectToKeep();
      if (keep == null) return;
      _edit((q) => q.withType(type, keepCorrectId: keep));
    } else {
      _edit((q) => q.withType(type));
    }
  }

  Future<String?> _askWhichCorrectToKeep() {
    final correct = [
      for (final o in _question.options)
        if (_question.isCorrect(o.id)) o,
    ];
    return showDialog<String>(
      context: context,
      builder: (context) {
        String? selected = correct.first.id;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Keep which answer?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A single-answer question has exactly one correct option. '
                  'Choose the one to keep:',
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (v) => setDialogState(() => selected = v),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final o in correct)
                        RadioListTile<String>(
                          value: o.id,
                          title: Text(
                            o.text.isEmpty ? '(empty option)' : o.text,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('Keep'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes to this question will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final q = _question;
    final isSingle = q.type == QuestionType.single;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? 'New question' : 'Edit question'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_question),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _prompt,
              decoration: const InputDecoration(
                labelText: 'Question',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (text) => _edit((q) => q.copyWith(prompt: text)),
            ),
            const SizedBox(height: 16),
            SegmentedButton<QuestionType>(
              segments: const [
                ButtonSegment(
                  value: QuestionType.single,
                  label: Text('Single answer'),
                  icon: Icon(Icons.radio_button_checked),
                ),
                ButtonSegment(
                  value: QuestionType.multiple,
                  label: Text('Multiple answers'),
                  icon: Icon(Icons.check_box_outlined),
                ),
              ],
              selected: {q.type},
              onSelectionChanged: (selection) => _setType(selection.single),
            ),
            const SizedBox(height: 16),
            Text(
              isSingle
                  ? 'Options — select the correct one'
                  : 'Options — check every correct one',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: isSingle && q.correctOptionIds.isNotEmpty
                  ? q.correctOptionIds.first
                  : null,
              onChanged: (id) {
                if (id != null) _edit((q) => q.withCorrectToggled(id));
              },
              child: Column(
                children: [
                  for (final (i, option) in q.options.indexed)
                    _OptionRow(
                      key: ValueKey(option.id),
                      index: i,
                      option: option,
                      isSingle: isSingle,
                      isCorrect: q.isCorrect(option.id),
                      controller: _optionController(option),
                      canRemove: q.canRemoveOption,
                      onTextChanged: (text) =>
                          _edit((q) => q.withOptionText(option.id, text)),
                      onToggleCorrect: () =>
                          _edit((q) => q.withCorrectToggled(option.id)),
                      onRemove: () =>
                          _edit((q) => q.withOptionRemoved(option.id)),
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: q.canAddOption
                    ? () => _edit((q) => q.withOptionAdded())
                    : null,
                icon: const Icon(Icons.add),
                label: Text(
                  q.canAddOption
                      ? 'Add option'
                      : 'Add option (max $maxOptions)',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _explanation,
              decoration: const InputDecoration(
                labelText: 'Explanation (optional)',
                helperText: 'Shown when reviewing answers.',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (text) => _edit(
                (q) =>
                    q.copyWith(explanation: text.trim().isEmpty ? null : text),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 160,
                child: TextField(
                  controller: _points,
                  decoration: const InputDecoration(
                    labelText: 'Points',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (text) {
                    final points = int.tryParse(text);
                    if (points != null && points > 0) {
                      _edit((q) => q.copyWith(points: points));
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.index,
    required this.option,
    required this.isSingle,
    required this.isCorrect,
    required this.controller,
    required this.canRemove,
    required this.onTextChanged,
    required this.onToggleCorrect,
    required this.onRemove,
  });

  final int index;
  final Option option;
  final bool isSingle;
  final bool isCorrect;
  final TextEditingController controller;
  final bool canRemove;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onToggleCorrect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final label = 'Option ${index + 1}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Tooltip(
            message: 'Mark $label correct',
            child: isSingle
                ? Radio<String>(value: option.id)
                : Checkbox(
                    value: isCorrect,
                    onChanged: (_) => onToggleCorrect(),
                  ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
              onChanged: onTextChanged,
            ),
          ),
          IconButton(
            tooltip: 'Remove $label',
            icon: const Icon(Icons.close),
            onPressed: canRemove ? onRemove : null,
          ),
        ],
      ),
    );
  }
}
