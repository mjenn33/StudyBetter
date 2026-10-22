import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_core/quiz_core.dart';

import '../../../data/repositories/library_repository.dart';
import '../quiz_routes.dart';
import 'quiz_editor_controller.dart';

/// Creates a quiz ([quizId] `null`) or edits an existing one: details,
/// settings and the list of questions.
class QuizEditorScreen extends ConsumerWidget {
  const QuizEditorScreen({super.key, this.quizId});

  final String? quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(quizEditorProvider(quizId));

    return switch (editor) {
      AsyncData(:final value) => _Editor(quizId: quizId, initial: value),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(switch (error) {
            ReadOnlyItemException() =>
              'This quiz was downloaded and is read-only. '
                  'Make a copy to edit it.',
            ItemNotFoundException() => 'This quiz no longer exists.',
            _ => 'Could not open the quiz: $error',
          }, textAlign: TextAlign.center),
        ),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.quizId, required this.initial});

  final String? quizId;

  /// State when the editor opened; text fields start from it.
  final QuizEditorState initial;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final _title = TextEditingController(text: widget.initial.draft.title);
  late final _description = TextEditingController(
    text: widget.initial.draft.description,
  );
  late final _language = TextEditingController(
    text: widget.initial.draft.language ?? '',
  );
  final _tag = TextEditingController();

  QuizEditorController get _controller =>
      ref.read(quizEditorProvider(widget.quizId).notifier);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _language.dispose();
    _tag.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final wasNew = ref.read(quizEditorProvider(widget.quizId)).value?.isNew;
    final saved = await _controller.save();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Quiz saved')));
    if (wasNew ?? false) context.go(QuizPaths.edit(saved.id));
  }

  Future<void> _confirmLeave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes to this quiz have not been saved.'),
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

  void _deleteQuestion(int index, Question question) {
    _controller.removeQuestion(question.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Question deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _controller.insertQuestion(index, question),
          ),
        ),
      );
  }

  /// Opens a question for editing. The question editor arrives in #18.
  void _editQuestion(Question question) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Editing questions is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quizEditorProvider(widget.quizId)).requireValue;
    final quiz = state.draft;

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.isNew ? 'New quiz' : 'Edit quiz'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: state.canSave ? _save : null,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.list(
                children: [
                  _section(context, 'Details'),
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _controller.setTitle,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _controller.setDescription,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _language,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      hintText: 'e.g. en, es',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _controller.setLanguage,
                  ),
                  const SizedBox(height: 12),
                  _TagEditor(
                    tags: quiz.tags,
                    input: _tag,
                    onAdd: (tag) {
                      _controller.addTag(tag);
                      _tag.clear();
                    },
                    onRemove: _controller.removeTag,
                  ),
                  const SizedBox(height: 24),
                  _section(context, 'Settings'),
                  _SettingsEditor(
                    settings: quiz.settings,
                    onChanged: _controller.setSettings,
                  ),
                  const SizedBox(height: 24),
                  _section(context, 'Questions (${quiz.questions.length})'),
                  if (quiz.questions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No questions yet.'),
                    ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverReorderableList(
                itemCount: quiz.questions.length,
                onReorderItem: _controller.moveQuestion,
                itemBuilder: (context, index) {
                  final question = quiz.questions[index];
                  return _QuestionTile(
                    key: ValueKey(question.id),
                    index: index,
                    question: question,
                    onTap: () => _editQuestion(question),
                    onDelete: () => _deleteQuestion(index, question),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _editQuestion(_controller.addQuestion()),
                    icon: const Icon(Icons.add),
                    label: const Text('Add question'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _TagEditor extends StatelessWidget {
  const _TagEditor({
    required this.tags,
    required this.input,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> tags;
  final TextEditingController input;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: input,
          decoration: InputDecoration(
            labelText: 'Add tag',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'Add tag',
              icon: const Icon(Icons.add),
              onPressed: () => onAdd(input.text),
            ),
          ),
          onSubmitted: onAdd,
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                InputChip(
                  label: Text(tag),
                  onDeleted: () => onRemove(tag),
                  deleteButtonTooltipMessage: 'Remove $tag',
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SettingsEditor extends StatelessWidget {
  const _SettingsEditor({required this.settings, required this.onChanged});

  final QuizSettings settings;
  final ValueChanged<QuizSettings> onChanged;

  static const _defaultLimitSeconds = 10 * 60;

  @override
  Widget build(BuildContext context) {
    final limit = settings.timeLimitSeconds;
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Shuffle questions'),
          value: settings.shuffleQuestions,
          onChanged: (v) => onChanged(settings.copyWith(shuffleQuestions: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Shuffle options'),
          value: settings.shuffleOptions,
          onChanged: (v) => onChanged(settings.copyWith(shuffleOptions: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Time limit'),
          subtitle: limit == null ? const Text('No limit') : null,
          value: limit != null,
          onChanged: (on) => onChanged(
            settings.copyWith(
              timeLimitSeconds: on ? _defaultLimitSeconds : null,
            ),
          ),
        ),
        if (limit != null)
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 200,
              child: TextFormField(
                key: const ValueKey('timeLimitMinutes'),
                initialValue: '${(limit / 60).ceil()}',
                decoration: const InputDecoration(
                  labelText: 'Minutes',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (text) {
                  final minutes = int.tryParse(text);
                  if (minutes != null && minutes > 0) {
                    onChanged(
                      settings.copyWith(timeLimitSeconds: minutes * 60),
                    );
                  }
                },
              ),
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Passing score'),
          trailing: Text('${settings.passingScorePercent}%'),
        ),
        Slider(
          value: settings.passingScorePercent.toDouble(),
          max: 100,
          divisions: 20,
          label: '${settings.passingScorePercent}%',
          onChanged: (v) =>
              onChanged(settings.copyWith(passingScorePercent: v.round())),
        ),
      ],
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    super.key,
    required this.index,
    required this.question,
    required this.onTap,
    required this.onDelete,
  });

  final int index;
  final Question question;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final type = question.type == QuestionType.single
        ? 'Single answer'
        : 'Multiple answers';
    final prompt = question.prompt.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_indicator, semanticLabel: 'Reorder'),
        ),
        title: Text(
          prompt.isEmpty ? 'Untitled question' : prompt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${index + 1}. $type · ${question.options.length} options',
        ),
        onTap: onTap,
        trailing: IconButton(
          tooltip: 'Delete question',
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
