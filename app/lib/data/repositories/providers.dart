import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_core/quiz_core.dart';

import '../database/database_provider.dart';
import 'attempt_repository.dart';
import 'deck_repository.dart';
import 'library_repository.dart';
import 'quiz_repository.dart';
import 'review_repository.dart';
import 'statistics_repository.dart';
import 'settings_repository.dart';

final attemptRepositoryProvider = Provider<AttemptRepository>(
  (ref) => AttemptRepository(ref.watch(appDatabaseProvider)),
);

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(ref.watch(appDatabaseProvider)),
);

final quizRepositoryProvider = Provider<QuizRepository>(
  (ref) => QuizRepository(ref.watch(appDatabaseProvider)),
);

final deckRepositoryProvider = Provider<DeckRepository>(
  (ref) => DeckRepository(ref.watch(appDatabaseProvider)),
);

final statisticsRepositoryProvider = Provider<StatisticsRepository>(
  (ref) => StatisticsRepository(ref.watch(appDatabaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

final newCardsPerDayProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.read(settingsRepositoryProvider).newCardsPerDay(),
);

/// Quizzes in the library (not deleted), most recently updated first.
final quizzesProvider = StreamProvider<List<LibraryEntry<Quiz>>>(
  (ref) => ref.watch(quizRepositoryProvider).watchAll(),
);

/// Decks in the library (not deleted), most recently updated first.
final decksProvider = StreamProvider<List<LibraryEntry<FlashcardDeck>>>(
  (ref) => ref.watch(deckRepositoryProvider).watchAll(),
);

/// The number of reviewed flashcards currently due in a deck.
final deckDueCountProvider = FutureProvider.autoDispose.family<int, String>(
  (ref, deckId) => ref.read(reviewRepositoryProvider).dueCount(deckId),
);
