import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_core/quiz_core.dart';
import '../../data/remote/api_client.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/providers.dart';
import '../../data/database/app_database.dart' show LibraryOrigin;

/// Publishing and conflict decisions shared by quizzes and flashcard decks.
Future<void> publishContent(
  BuildContext context,
  WidgetRef ref, {
  required String kind,
  required String id,
}) async {
  final visibility = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Publish visibility'),
      children: [
        for (final value in ['public', 'unlisted', 'private'])
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, value),
            child: Text(value),
          ),
      ],
    ),
  );
  if (visibility == null) return;
  try {
    final api = await ref.read(apiClientProvider.future);
    if (!await api.isSignedIn) {
      throw const ApiFailure(
        ApiErrorKind.unauthorized,
        'Sign in from Settings before publishing.',
      );
    }
    final quizRepository = ref.read(quizRepositoryProvider);
    final deckRepository = ref.read(deckRepositoryProvider);
    final LibraryEntry<Object>? entry = kind == 'quizzes'
        ? await quizRepository.getById(id)
        : await deckRepository.getById(id);
    if (entry == null) throw ItemNotFoundException(id);
    if (entry.isReadOnly) throw ReadOnlyItemException(id);
    final document = entry.document;
    final Map<String, dynamic> json;
    if (document is Quiz) {
      if (validateQuiz(document).isNotEmpty) {
        throw StateError('Fix the quiz validation errors before publishing.');
      }
      json = document.toJson();
    } else {
      final deck = document as FlashcardDeck;
      if (validateDeck(deck).isNotEmpty) {
        throw StateError('Fix the deck validation errors before publishing.');
      }
      json = deck.toJson();
    }
    Map<String, dynamic> saved;
    try {
      saved =
          await api.request(
                entry.remoteId == null ? 'POST' : 'PUT',
                '/$kind${entry.remoteId == null ? '' : '/${entry.remoteId}'}',
                data: {...json, 'visibility': visibility},
                version: entry.remoteVersion,
              )
              as Map<String, dynamic>;
    } on ApiFailure catch (error) {
      if (error.kind != ApiErrorKind.conflict || entry.remoteId == null) {
        rethrow;
      }
      final server =
          await api.request('GET', '/$kind/${entry.remoteId}')
              as Map<String, dynamic>;
      if (!context.mounted) return;
      final decision = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Version conflict'),
          content: const Text(
            'This item changed on the server. Choose which version to keep.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'server'),
              child: const Text('Take server version'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'mine'),
              child: const Text('Keep mine (overwrite)'),
            ),
          ],
        ),
      );
      if (decision == null) return;
      if (decision == 'server') {
        final parsed = parseDocument(server);
        if (parsed is QuizDocument) {
          await quizRepository.storeRemote(
            parsed.quiz,
            remoteId: entry.remoteId!,
            remoteVersion: server['version'] as int,
            ownerName: entry.ownerName ?? '',
            owned: true,
          );
        }
        if (parsed is DeckDocument) {
          await deckRepository.storeRemote(
            parsed.deck,
            remoteId: entry.remoteId!,
            remoteVersion: server['version'] as int,
            ownerName: entry.ownerName ?? '',
            owned: true,
          );
        }
        return;
      }
      saved =
          await api.request(
                'PUT',
                '/$kind/${entry.remoteId}',
                data: {...json, 'visibility': visibility},
                version: server['version'] as int,
              )
              as Map<String, dynamic>;
    }
    if (kind == 'quizzes') {
      await quizRepository.markPublished(
        id,
        saved['id'] as String,
        saved['version'] as int,
      );
    } else {
      await deckRepository.markPublished(
        id,
        saved['id'] as String,
        saved['version'] as int,
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Published')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

final remoteVersionProvider = FutureProvider.autoDispose
    .family<int?, (String, String)>((ref, key) async {
      final api = await ref.watch(apiClientProvider.future);
      final data =
          await api.request('GET', '/${key.$1}/${key.$2}')
              as Map<String, dynamic>;
      return data['version'] as int;
    });

class ContentUpdateButton extends ConsumerWidget {
  const ContentUpdateButton({
    super.key,
    required this.kind,
    required this.id,
    required this.remoteId,
    required this.version,
    required this.ownerName,
    this.owned = false,
  });
  final String kind;
  final String id;
  final String remoteId;
  final int version;
  final String ownerName;
  final bool owned;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = ref.watch(remoteVersionProvider((kind, remoteId))).value;
    if (remote == null || remote <= version) return const SizedBox.shrink();
    return TextButton.icon(
      icon: const Icon(Icons.system_update),
      label: const Text('Update available'),
      onPressed: () async {
        try {
          final api = await ref.read(apiClientProvider.future);
          final json =
              await api.request('GET', '/$kind/$remoteId')
                  as Map<String, dynamic>;
          final parsed = parseDocument(json);
          if (parsed is QuizDocument) {
            await ref
                .read(quizRepositoryProvider)
                .storeRemote(
                  parsed.quiz,
                  remoteId: remoteId,
                  remoteVersion: json['version'] as int,
                  ownerName: ownerName,
                  owned: owned,
                  origin: LibraryOrigin.downloaded,
                );
          }
          if (parsed is DeckDocument) {
            await ref
                .read(deckRepositoryProvider)
                .storeRemote(
                  parsed.deck,
                  remoteId: remoteId,
                  remoteVersion: json['version'] as int,
                  ownerName: ownerName,
                  owned: owned,
                  origin: LibraryOrigin.downloaded,
                );
          }
          ref.invalidate(remoteVersionProvider((kind, remoteId)));
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$error')));
          }
        }
      },
    );
  }
}
