import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_core/quiz_core.dart';

import '../../data/repositories/providers.dart';
import '../../data/repositories/review_repository.dart';

/// Reviews scheduled cards, or lets the user cram a whole deck without
/// changing its schedule.
class FlashcardStudyScreen extends ConsumerStatefulWidget {
  const FlashcardStudyScreen({
    super.key,
    required this.deckId,
    required this.cram,
  });

  final String deckId;
  final bool cram;

  @override
  ConsumerState<FlashcardStudyScreen> createState() =>
      _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends ConsumerState<FlashcardStudyScreen> {
  FlashcardDeck? _deck;
  List<Flashcard> _cards = const [];
  Map<String, CardReviewState> _states = const {};
  var _index = 0;
  var _flipped = false;
  var _loading = true;
  final _grades = <Grade>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final deck = await ref.read(deckRepositoryProvider).getById(widget.deckId);
    if (deck == null || !mounted) return;
    final states = await ref
        .read(reviewRepositoryProvider)
        .statesForDeck(widget.deckId);
    final now = DateTime.now().toUtc();
    final cards = widget.cram
        ? deck.document.cards
        : deck.document.cards.where((card) {
            final state = states[card.id];
            return state == null || !state.dueAt.isAfter(now);
          }).toList();
    if (mounted) {
      setState(() {
        _deck = deck.document;
        _states = states;
        _cards = cards;
        _loading = false;
      });
    }
  }

  Future<void> _grade(Grade grade) async {
    if (_index >= _cards.length) return;
    final card = _cards[_index];
    if (!widget.cram) {
      final old = _states[card.id];
      final scheduled = next(
        ReviewState(
          easeFactor: old?.easeFactor ?? 2.5,
          intervalDays: old?.intervalDays ?? 0,
          repetitions: old?.repetitions ?? 0,
          dueAt: old?.dueAt,
          lastReviewedAt: old?.lastReviewedAt,
          lapses: old?.lapses ?? 0,
        ),
        grade,
        DateTime.now(),
      );
      final state = CardReviewState(
        deckId: widget.deckId,
        cardId: card.id,
        easeFactor: scheduled.easeFactor,
        intervalDays: scheduled.intervalDays,
        repetitions: scheduled.repetitions,
        dueAt: scheduled.dueAt!,
        lastReviewedAt: scheduled.lastReviewedAt,
        lapses: scheduled.lapses,
      );
      await ref
          .read(reviewRepositoryProvider)
          .recordReview(
            state: state,
            grade: grade,
            reviewedAt: scheduled.lastReviewedAt!,
          );
    }
    if (mounted) {
      setState(() {
        _grades.add(grade);
        _index += 1;
        _flipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final deck = _deck;
    if (deck == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This deck no longer exists.')),
      );
    }
    if (_index >= _cards.length) {
      return _Summary(deck: deck, cram: widget.cram, grades: _grades);
    }
    final card = _cards[_index];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            setState(() => _flipped = !_flipped),
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            _grade(Grade.again),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            _grade(Grade.hard),
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            _grade(Grade.good),
        const SingleActivator(LogicalKeyboardKey.digit4): () =>
            _grade(Grade.easy),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.cram ? 'Cram: ${deck.title}' : 'Study: ${deck.title}',
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('${_index + 1} of ${_cards.length}'),
                const SizedBox(height: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _flipped = !_flipped),
                    borderRadius: BorderRadius.circular(16),
                    child: Card(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _flipped ? card.back : card.front,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  _flipped
                      ? 'Tap or press Space to show the front'
                      : 'Tap or press Space to reveal the answer',
                ),
                const SizedBox(height: 16),
                if (_flipped)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _gradeButton('Again', '1', Grade.again),
                      _gradeButton('Hard', '2', Grade.hard),
                      _gradeButton('Good', '3', Grade.good),
                      _gradeButton('Easy', '4', Grade.easy),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gradeButton(String label, String key, Grade grade) => FilledButton(
    onPressed: () => _grade(grade),
    child: Text('$label ($key)'),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.deck,
    required this.cram,
    required this.grades,
  });
  final FlashcardDeck deck;
  final bool cram;
  final List<Grade> grades;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Session complete')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Session complete',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              '${grades.length} cards reviewed${cram ? '. Cram sessions do not change scheduling.' : '.'}',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/flashcards'),
              child: const Text('Back to decks'),
            ),
          ],
        ),
      ),
    ),
  );
}
