import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_core/quiz_core.dart';

import '../../data/repositories/library_repository.dart';
import '../../data/repositories/providers.dart';
import 'deck_routes.dart';
import 'deck_actions.dart';

/// The library of locally stored flashcard decks.
class DeckLibraryScreen extends ConsumerWidget {
  const DeckLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decks = ref.watch(decksProvider);
    final hasDecks = decks.value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        actions: [
          IconButton(
            tooltip: 'Import',
            icon: const Icon(Icons.file_open_outlined),
            onPressed: () => DeckActions.import(context, ref),
          ),
        ],
      ),
      floatingActionButton: hasDecks
          ? FloatingActionButton.extended(
              onPressed: () => context.go(DeckPaths.create),
              icon: const Icon(Icons.add),
              label: const Text('New deck'),
            )
          : null,
      body: switch (decks) {
        AsyncError(:final error) => Center(
          child: Text('Could not load decks: $error'),
        ),
        AsyncData(:final value) when value.isEmpty => const _EmptyDeckLibrary(),
        AsyncData(:final value) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: value.length,
          itemBuilder: (context, index) => DeckListTile(entry: value[index]),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EmptyDeckLibrary extends StatelessWidget {
  const _EmptyDeckLibrary();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.style_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No flashcard decks yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a deck to start organizing your flashcards.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go(DeckPaths.create),
            icon: const Icon(Icons.add),
            label: const Text('Create deck'),
          ),
        ],
      ),
    ),
  );
}

/// One deck in the library list, including its stored-card and due counts.
class DeckListTile extends ConsumerWidget {
  const DeckListTile({super.key, required this.entry});

  final LibraryEntry<FlashcardDeck> entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = entry.document;
    final dueCount = ref.watch(deckDueCountProvider(deck.id));
    final cardCount = deck.cards.length;
    final dueText = dueCount.when(
      data: (count) => '$count due',
      error: (_, _) => 'Due count unavailable',
      loading: () => 'Checking due cards…',
    );

    return ListTile(
      title: Text(deck.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$cardCount ${cardCount == 1 ? 'card' : 'cards'} · $dueText'),
          if (deck.description.trim().isNotEmpty)
            Text(
              deck.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (deck.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final tag in deck.tags)
                    Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),
        ],
      ),
      onTap: entry.isReadOnly
          ? null
          : () => context.go(DeckPaths.edit(deck.id)),
      trailing: PopupMenuButton<_DeckAction>(
        tooltip: 'Actions',
        onSelected: (action) => _handleAction(context, ref, action),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _DeckAction.studyDue,
            child: Text('Study due cards'),
          ),
          const PopupMenuItem(
            value: _DeckAction.cram,
            child: Text('Cram all cards'),
          ),
          if (!entry.isReadOnly)
            const PopupMenuItem(value: _DeckAction.edit, child: Text('Edit')),
          const PopupMenuItem(
            value: _DeckAction.duplicate,
            child: Text('Duplicate'),
          ),
          const PopupMenuItem(value: _DeckAction.export, child: Text('Export')),
          const PopupMenuItem(value: _DeckAction.delete, child: Text('Delete')),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _DeckAction action,
  ) async {
    final deck = entry.document;
    switch (action) {
      case _DeckAction.studyDue:
        context.go(DeckPaths.study(deck.id));
      case _DeckAction.cram:
        context.go(DeckPaths.study(deck.id, cram: true));
      case _DeckAction.edit:
        context.go(DeckPaths.edit(deck.id));
      case _DeckAction.duplicate:
        final copy = await ref.read(deckRepositoryProvider).duplicate(deck.id);
        if (context.mounted) {
          context.go(DeckPaths.edit(copy.id));
        }
      case _DeckAction.export:
        await DeckActions.export(context, ref, deck);
      case _DeckAction.delete:
        final delete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete ${deck.title}?'),
            content: const Text('Review history will be kept.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (delete == true) {
          await ref.read(deckRepositoryProvider).delete(deck.id);
        }
    }
  }
}

enum _DeckAction { studyDue, cram, edit, duplicate, export, delete }
