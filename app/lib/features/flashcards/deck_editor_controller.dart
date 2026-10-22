import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/library_repository.dart';
import '../../data/repositories/providers.dart';

/// The saved deck and its in-memory working copy.
class DeckEditorState {
  DeckEditorState({
    required this.saved,
    required this.draft,
    required this.isNew,
  });

  final FlashcardDeck saved;
  final FlashcardDeck draft;
  final bool isNew;

  bool get isDirty => draft != saved;
  bool get canSave => isDirty && draft.title.trim().isNotEmpty;
  bool get showIssues => !isNew || isDirty;
  late final List<ValidationIssue> issues = validateDeck(draft);

  DeckEditorState copyWith({
    FlashcardDeck? saved,
    FlashcardDeck? draft,
    bool? isNew,
  }) => DeckEditorState(
    saved: saved ?? this.saved,
    draft: draft ?? this.draft,
    isNew: isNew ?? this.isNew,
  );
}

/// Edits the deck with [deckId], or a blank new deck when it is null.
final deckEditorProvider = AsyncNotifierProvider.autoDispose
    .family<DeckEditorController, DeckEditorState, String?>(
      DeckEditorController.new,
      retry: (_, _) => null,
    );

class DeckEditorController extends AsyncNotifier<DeckEditorState> {
  DeckEditorController(this.deckId);

  final String? deckId;

  @override
  Future<DeckEditorState> build() async {
    final id = deckId;
    if (id == null) {
      final now = DateTime.now().toUtc();
      final deck = FlashcardDeck(
        id: const Uuid().v4(),
        title: '',
        createdAt: now,
        updatedAt: now,
      );
      return DeckEditorState(saved: deck, draft: deck, isNew: true);
    }

    final entry = await ref.read(deckRepositoryProvider).getById(id);
    if (entry == null) throw ItemNotFoundException(id);
    if (entry.isReadOnly) throw ReadOnlyItemException(id);
    return DeckEditorState(
      saved: entry.document,
      draft: entry.document,
      isNew: false,
    );
  }

  DeckEditorState get _current => state.requireValue;

  void _update(FlashcardDeck Function(FlashcardDeck deck) change) {
    state = AsyncData(_current.copyWith(draft: change(_current.draft)));
  }

  void setTitle(String title) => _update((deck) => deck.copyWith(title: title));

  void setDescription(String description) =>
      _update((deck) => deck.copyWith(description: description));

  void setLanguage(String language) => _update(
    (deck) => deck.copyWith(
      language: language.trim().isEmpty ? null : language.trim(),
    ),
  );

  void addTag(String tag) {
    final value = tag.trim();
    if (value.isEmpty || _current.draft.tags.contains(value)) return;
    _update((deck) => deck.copyWith(tags: [...deck.tags, value]));
  }

  void removeTag(String tag) => _update(
    (deck) =>
        deck.copyWith(tags: deck.tags.where((value) => value != tag).toList()),
  );

  void addCard() => _update(
    (deck) => deck.copyWith(
      cards: [
        ...deck.cards,
        Flashcard(id: const Uuid().v4(), front: '', back: ''),
      ],
    ),
  );

  void updateCard(Flashcard card) => _update(
    (deck) => deck.copyWith(
      cards: [
        for (final existing in deck.cards)
          existing.id == card.id ? card : existing,
      ],
    ),
  );

  void removeCard(String id) => _update(
    (deck) => deck.copyWith(
      cards: deck.cards.where((card) => card.id != id).toList(),
    ),
  );

  /// Moves a card using the indexes reported by [ReorderableListView].
  void moveCard(int oldIndex, int newIndex) => _update((deck) {
    final cards = [...deck.cards];
    if (newIndex > oldIndex) newIndex -= 1;
    cards.insert(newIndex, cards.removeAt(oldIndex));
    return deck.copyWith(cards: cards);
  });

  Future<FlashcardDeck> save() async {
    final current = _current;
    if (!current.canSave) return current.saved;
    final saved = await ref
        .read(deckRepositoryProvider)
        .save(current.draft.copyWith(title: current.draft.title.trim()));
    state = AsyncData(
      DeckEditorState(saved: saved, draft: saved, isNew: false),
    );
    return saved;
  }
}
