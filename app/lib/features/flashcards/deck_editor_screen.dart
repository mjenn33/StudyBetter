import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_core/quiz_core.dart';

import '../../data/repositories/library_repository.dart';
import 'deck_editor_controller.dart';
import 'deck_routes.dart';

/// Creates a deck or edits its details and ordered card list.
class DeckEditorScreen extends ConsumerWidget {
  const DeckEditorScreen({super.key, this.deckId});

  final String? deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(deckEditorProvider(deckId));
    return switch (editor) {
      AsyncData(:final value) => _DeckEditor(deckId: deckId, initial: value),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(switch (error) {
            ReadOnlyItemException() =>
              'This deck was downloaded and is read-only. Make a copy to edit it.',
            ItemNotFoundException() => 'This deck no longer exists.',
            _ => 'Could not open the deck: $error',
          }, textAlign: TextAlign.center),
        ),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _DeckEditor extends ConsumerStatefulWidget {
  const _DeckEditor({required this.deckId, required this.initial});

  final String? deckId;
  final DeckEditorState initial;

  @override
  ConsumerState<_DeckEditor> createState() => _DeckEditorState();
}

class _DeckEditorState extends ConsumerState<_DeckEditor> {
  late final _title = TextEditingController(text: widget.initial.draft.title);
  late final _description = TextEditingController(
    text: widget.initial.draft.description,
  );
  late final _language = TextEditingController(
    text: widget.initial.draft.language ?? '',
  );
  final _tag = TextEditingController();

  DeckEditorController get _controller =>
      ref.read(deckEditorProvider(widget.deckId).notifier);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _language.dispose();
    _tag.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = ref.read(deckEditorProvider(widget.deckId)).requireValue;
    final problems = validateDeck(state.draft);
    if (problems.any((issue) => issue.path != 'title')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a front and back for every card before saving.'),
        ),
      );
      return;
    }
    final wasNew = state.isNew;
    final saved = await _controller.save();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Deck saved')));
    if (wasNew) context.go(DeckPaths.edit(saved.id));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deckEditorProvider(widget.deckId)).requireValue;
    final deck = state.draft;
    final issues = state.showIssues ? state.issues : const <ValidationIssue>[];
    final titleError = _messageAt(issues, 'title');

    return Scaffold(
      appBar: AppBar(
        title: Text(state.isNew ? 'New deck' : 'Edit deck'),
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
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: const OutlineInputBorder(),
                    errorText: titleError,
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
                  tags: deck.tags,
                  input: _tag,
                  onAdd: (tag) {
                    _controller.addTag(tag);
                    _tag.clear();
                  },
                  onRemove: _controller.removeTag,
                ),
                const SizedBox(height: 24),
                _section(context, 'Cards (${deck.cards.length})'),
                if (_messageAt(issues, 'cards') case final message?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverReorderableList(
              itemCount: deck.cards.length,
              onReorderItem: _controller.moveCard,
              itemBuilder: (context, index) {
                final card = deck.cards[index];
                return _CardTile(
                  key: ValueKey(card.id),
                  index: index,
                  card: card,
                  frontError: _messageAt(issues, 'cards[$index].front'),
                  backError: _messageAt(issues, 'cards[$index].back'),
                  onChanged: _controller.updateCard,
                  onDelete: () => _controller.removeCard(card.id),
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
                  onPressed: _controller.addCard,
                  icon: const Icon(Icons.add),
                  label: const Text('Add card'),
                ),
              ),
            ),
          ),
        ],
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
  Widget build(BuildContext context) => Column(
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

class _CardTile extends StatelessWidget {
  const _CardTile({
    super.key,
    required this.index,
    required this.card,
    required this.frontError,
    required this.backError,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final Flashcard card;
  final String? frontError;
  final String? backError;
  final ValueChanged<Flashcard> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(
                  Icons.drag_indicator,
                  semanticLabel: 'Reorder',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('Card ${index + 1}')),
              IconButton(
                tooltip: 'Delete card',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('${card.id}-front'),
            initialValue: card.front,
            decoration: InputDecoration(
              labelText: 'Front',
              border: const OutlineInputBorder(),
              errorText: frontError,
            ),
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (front) => onChanged(card.copyWith(front: front)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('${card.id}-back'),
            initialValue: card.back,
            decoration: InputDecoration(
              labelText: 'Back',
              border: const OutlineInputBorder(),
              errorText: backError,
            ),
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (back) => onChanged(card.copyWith(back: back)),
          ),
        ],
      ),
    ),
  );
}

String? _messageAt(List<ValidationIssue> issues, String path) {
  for (final issue in issues) {
    if (issue.path == path) return issue.message;
  }
  return null;
}
