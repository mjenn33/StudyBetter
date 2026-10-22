import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_core/quiz_core.dart';

import '../../../data/repositories/library_repository.dart';
import '../../../data/repositories/providers.dart';

/// Search text and selected tag of the quiz library.
class QuizLibraryFilter {
  const QuizLibraryFilter({this.query = '', this.tag});

  final String query;

  /// Only quizzes with this tag are shown; `null` shows all.
  final String? tag;

  bool get isActive => query.trim().isNotEmpty || tag != null;
}

class QuizLibraryFilterNotifier extends Notifier<QuizLibraryFilter> {
  @override
  QuizLibraryFilter build() => const QuizLibraryFilter();

  void setQuery(String query) =>
      state = QuizLibraryFilter(query: query, tag: state.tag);

  /// Selects [tag], or clears the tag filter when [tag] is already selected.
  void toggleTag(String tag) => state = QuizLibraryFilter(
    query: state.query,
    tag: state.tag == tag ? null : tag,
  );

  void clear() => state = const QuizLibraryFilter();
}

final quizLibraryFilterProvider =
    NotifierProvider<QuizLibraryFilterNotifier, QuizLibraryFilter>(
      QuizLibraryFilterNotifier.new,
    );

/// [entries] matching [filter]: title contains the query (ignoring case) and,
/// if a tag is selected, the quiz has that tag. Order is kept.
List<LibraryEntry<Quiz>> filterQuizzes(
  List<LibraryEntry<Quiz>> entries,
  QuizLibraryFilter filter,
) {
  final query = filter.query.trim().toLowerCase();
  return [
    for (final entry in entries)
      if ((query.isEmpty ||
              entry.document.title.toLowerCase().contains(query)) &&
          (filter.tag == null || entry.document.tags.contains(filter.tag)))
        entry,
  ];
}

/// Every tag used in [entries], sorted alphabetically.
List<String> tagsOf(List<LibraryEntry<Quiz>> entries) =>
    {for (final e in entries) ...e.document.tags}.toList()..sort();

/// The library after applying [quizLibraryFilterProvider].
final filteredQuizzesProvider = Provider<AsyncValue<List<LibraryEntry<Quiz>>>>((
  ref,
) {
  final filter = ref.watch(quizLibraryFilterProvider);
  return ref
      .watch(quizzesProvider)
      .whenData((entries) => filterQuizzes(entries, filter));
});

/// The quiz with [id] from the library, or `null` once it's deleted.
final quizEntryProvider =
    Provider.family<AsyncValue<LibraryEntry<Quiz>?>, String>((ref, id) {
      return ref.watch(quizzesProvider).whenData((entries) {
        for (final entry in entries) {
          if (entry.document.id == id) return entry;
        }
        return null;
      });
    });
