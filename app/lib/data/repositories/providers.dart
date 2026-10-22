import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_core/quiz_core.dart';

import '../database/database_provider.dart';
import 'deck_repository.dart';
import 'library_repository.dart';
import 'quiz_repository.dart';

final quizRepositoryProvider = Provider<QuizRepository>(
  (ref) => QuizRepository(ref.watch(appDatabaseProvider)),
);

final deckRepositoryProvider = Provider<DeckRepository>(
  (ref) => DeckRepository(ref.watch(appDatabaseProvider)),
);

/// Quizzes in the library (not deleted), most recently updated first.
final quizzesProvider = StreamProvider<List<LibraryEntry<Quiz>>>(
  (ref) => ref.watch(quizRepositoryProvider).watchAll(),
);

/// Decks in the library (not deleted), most recently updated first.
final decksProvider = StreamProvider<List<LibraryEntry<FlashcardDeck>>>(
  (ref) => ref.watch(deckRepositoryProvider).watchAll(),
);
