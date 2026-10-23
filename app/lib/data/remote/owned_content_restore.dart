import 'package:quiz_core/quiz_core.dart';

import '../repositories/deck_repository.dart';
import '../repositories/quiz_repository.dart';
import 'api_client.dart';

/// The outcome of bringing the signed-in user's published library onto this
/// device. A skipped item has local edits that were deliberately preserved.
class OwnedContentRestoreResult {
  const OwnedContentRestoreResult({
    required this.restored,
    required this.skipped,
    required this.failed,
  });

  final int restored;
  final int skipped;
  final int failed;
}

/// Downloads all quizzes and decks owned by the signed-in user.
///
/// Content is kept local-first: a local item is never overwritten when it has
/// changed since its last known remote version. Individual failed downloads do
/// not stop the remaining content from being restored.
Future<OwnedContentRestoreResult> restoreOwnedContent({
  required ApiClient api,
  required QuizRepository quizzes,
  required DeckRepository decks,
}) async {
  if (!await api.isSignedIn) {
    throw const ApiFailure(
      ApiErrorKind.unauthorized,
      'Sign in before restoring published content.',
    );
  }
  final profile = await api.request('GET', '/me') as Map<String, dynamic>;
  final ownerName = profile['username'] as String? ?? '';
  var restored = 0;
  var skipped = 0;
  var failed = 0;

  final quizSummaries =
      await api.request('GET', '/me/quizzes') as List<dynamic>;
  for (final summary in quizSummaries.cast<Map<String, dynamic>>()) {
    try {
      final json = await api.request('GET', '/quizzes/${summary['id']}')
          as Map<String, dynamic>;
      final document = parseDocument(json);
      if (document is! QuizDocument) throw StateError('Expected a quiz.');
      final stored = await quizzes.restoreOwnedRemote(
        document.quiz,
        remoteId: summary['id'] as String,
        remoteVersion: json['version'] as int,
        ownerName: ownerName,
      );
      stored ? restored++ : skipped++;
    } catch (_) {
      failed++;
    }
  }

  final deckSummaries = await api.request('GET', '/me/decks') as List<dynamic>;
  for (final summary in deckSummaries.cast<Map<String, dynamic>>()) {
    try {
      final json = await api.request('GET', '/decks/${summary['id']}')
          as Map<String, dynamic>;
      final document = parseDocument(json);
      if (document is! DeckDocument) throw StateError('Expected a deck.');
      final stored = await decks.restoreOwnedRemote(
        document.deck,
        remoteId: summary['id'] as String,
        remoteVersion: json['version'] as int,
        ownerName: ownerName,
      );
      stored ? restored++ : skipped++;
    } catch (_) {
      failed++;
    }
  }

  return OwnedContentRestoreResult(
    restored: restored,
    skipped: skipped,
    failed: failed,
  );
}
