import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_core/quiz_core.dart';

import '../../../data/repositories/library_repository.dart';
import '../../../data/repositories/providers.dart';
import '../quiz_actions.dart';
import '../quiz_readiness.dart';
import '../quiz_routes.dart';
import 'quiz_library_filter.dart';

/// The Quizzes tab: every quiz in the local library, with search and tag
/// filter.
class QuizLibraryScreen extends ConsumerWidget {
  const QuizLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(quizzesProvider);
    final filtered = ref.watch(filteredQuizzesProvider);
    final hasQuizzes = all.value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quizzes'),
        actions: [
          IconButton(
            tooltip: 'Import',
            icon: const Icon(Icons.file_open_outlined),
            onPressed: () => QuizActions.import(context),
          ),
        ],
      ),
      floatingActionButton: hasQuizzes
          ? FloatingActionButton.extended(
              onPressed: () => context.go(QuizPaths.create),
              icon: const Icon(Icons.add),
              label: const Text('New quiz'),
            )
          : null,
      body: switch (all) {
        AsyncError(:final error) => Center(
          child: Text('Could not load quizzes: $error'),
        ),
        AsyncData(:final value) when value.isEmpty => const _EmptyLibrary(),
        AsyncData(:final value) => Column(
          children: [
            _FilterBar(tags: tagsOf(value)),
            Expanded(child: _QuizList(entries: filtered.value ?? const [])),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No quizzes yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Create your first quiz or import one from a file.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => context.go(QuizPaths.create),
                  icon: const Icon(Icons.add),
                  label: const Text('Create quiz'),
                ),
                OutlinedButton.icon(
                  onPressed: () => QuizActions.import(context),
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Import'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(quizLibraryFilterProvider);
    final notifier = ref.read(quizLibraryFilterProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchBar(
            hintText: 'Search quizzes',
            leading: const Icon(Icons.search),
            onChanged: notifier.setQuery,
            elevation: const WidgetStatePropertyAll(0),
          ),
          if (tags.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  for (final tag in tags)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag),
                        selected: filter.tag == tag,
                        onSelected: (_) => notifier.toggleTag(tag),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuizList extends StatelessWidget {
  const _QuizList({required this.entries});

  final List<LibraryEntry<Quiz>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No quizzes match your search.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: entries.length,
      itemBuilder: (context, i) => QuizListTile(entry: entries[i]),
    );
  }
}

/// One quiz in the library list.
class QuizListTile extends ConsumerWidget {
  const QuizListTile({super.key, required this.entry});

  final LibraryEntry<Quiz> entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiz = entry.document;
    final localizations = MaterialLocalizations.of(context);
    final count = quiz.questions.length;
    final problems = quiz.problems;
    final updated = localizations.formatMediumDate(quiz.updatedAt.toLocal());

    return ListTile(
      title: Text(quiz.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count ${count == 1 ? 'question' : 'questions'} · Updated $updated',
          ),
          if (problems.isNotEmpty)
            ErrorText('Draft · ${problemCount(problems.length)}'),
          if (quiz.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final tag in quiz.tags)
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
      onTap: () => context.go(QuizPaths.detail(quiz.id)),
      trailing: PopupMenuButton<_Action>(
        tooltip: 'Actions',
        onSelected: (action) => switch (action) {
          _Action.play when problems.isNotEmpty =>
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(blockedMessage('play', problems.length)),
                ),
              ),
          _Action.play => context.go(QuizPaths.play(quiz.id)),
          _Action.edit => context.go(QuizPaths.edit(quiz.id)),
          _Action.duplicate => QuizActions.duplicate(context, ref, quiz),
          _Action.delete => QuizActions.delete(context, ref, quiz),
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: _Action.play, child: Text('Play')),
          if (!entry.isReadOnly)
            const PopupMenuItem(value: _Action.edit, child: Text('Edit')),
          const PopupMenuItem(
            value: _Action.duplicate,
            child: Text('Duplicate'),
          ),
          const PopupMenuItem(value: _Action.delete, child: Text('Delete')),
        ],
      ),
    );
  }
}

enum _Action { play, edit, duplicate, delete }
