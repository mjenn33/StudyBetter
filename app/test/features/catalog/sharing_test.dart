import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_better/app/router.dart';
import 'package:study_better/data/remote/api_client.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';
import 'package:study_better/features/quizzes/quiz_routes.dart';
import '../../helpers.dart';

class FakeApi extends ApiClient {
  FakeApi(this.respond, {this.signedIn = true})
    : super('https://example.test/api/v1');
  final bool signedIn;
  final Future<Object?> Function(
    String,
    String,
    Object?,
    Map<String, dynamic>?,
    int?,
  )
  respond;
  @override
  Future<bool> get isSignedIn async => signedIn;
  @override
  Future<Object?> request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    int? version,
    bool authenticated = true,
  }) => respond(method, path, data, query, version);
}

void main() {
  testWidgets(
    'publishes first upload and stores authoritative remote version',
    (tester) async {
      final db = testDatabase();
      addTearDown(db.close);
      final repository = QuizRepository(db);
      final quiz = await repository.save(testQuiz());
      var uploaded = false;
      final api = FakeApi((method, path, data, query, version) async {
        expect(method, 'POST');
        expect(path, '/quizzes');
        expect(version, isNull);
        expect((data as Map)['visibility'], 'public');
        uploaded = true;
        return {'id': quiz.id, 'version': 1};
      });
      addTearDown(api.close);
      final container = await pumpApp(
        tester,
        db: db,
        size: const Size(800, 1000),
        overrides: [apiClientProvider.overrideWith((_) async => api)],
      );
      container.read(routerProvider).go(QuizPaths.detail(quiz.id));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Publish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('public'));
      await tester.pumpAndSettle();
      expect(uploaded, true);
      expect((await repository.getById(quiz.id))!.remoteId, quiz.id);
      expect((await repository.getById(quiz.id))!.remoteVersion, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final keepMine in [false, true]) {
    testWidgets(
      'conflict choice ${keepMine ? 'overwrites with latest If-Match' : 'takes server content'}',
      (tester) async {
        final db = testDatabase();
        addTearDown(db.close);
        final repository = QuizRepository(db);
        final quiz = await repository.save(testQuiz());
        await repository.markPublished(quiz.id, quiz.id, 1);
        var puts = 0;
        final server =
            jsonDecode(
                  jsonEncode(
                    quiz.copyWith(title: 'Server title', version: 2).toJson(),
                  ),
                )
                as Map<String, dynamic>;
        final api = FakeApi((method, path, data, query, version) async {
          if (method == 'GET') return server;
          puts++;
          if (puts == 1) {
            expect(version, 1);
            throw const ApiFailure(ApiErrorKind.conflict, 'Conflict');
          }
          expect(version, 2);
          return {'id': quiz.id, 'version': 3};
        });
        addTearDown(api.close);
        final container = await pumpApp(
          tester,
          db: db,
          size: const Size(800, 1000),
          overrides: [apiClientProvider.overrideWith((_) async => api)],
        );
        container.read(routerProvider).go(QuizPaths.detail(quiz.id));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Publish'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('private'));
        await tester.pumpAndSettle();
        expect(find.text('Version conflict'), findsOneWidget);
        await tester.tap(
          find.text(keepMine ? 'Keep mine (overwrite)' : 'Take server version'),
        );
        await tester.pumpAndSettle();
        final entry = (await repository.getById(quiz.id))!;
        expect(entry.remoteVersion, keepMine ? 3 : 2);
        expect(entry.document.title, keepMine ? quiz.title : 'Server title');
        expect(entry.isOwnedByMe, true);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final owned in [false, true]) {
    testWidgets('catalog download owned=$owned preserves permissions', (
      tester,
    ) async {
      final db = testDatabase();
      addTearDown(db.close);
      final quiz = testQuiz();
      final json =
          jsonDecode(jsonEncode(quiz.toJson())) as Map<String, dynamic>;
      final api = FakeApi((method, path, data, query, version) async {
        if (path == '/me') return {'id': 'owner'};
        if (path == '/quizzes') {
          return {
            'page': 1,
            'hasMore': false,
            'items': [
              {
                'id': quiz.id,
                'title': quiz.title,
                'description': 'Shared quiz',
                'ownerName': 'sam',
                'ownerId': 'owner',
                'version': 1,
                'itemCount': 1,
                'downloadCount': 0,
                'tags': <String>[],
              },
            ],
          };
        }
        return json;
      }, signedIn: owned);
      addTearDown(api.close);
      final container = await pumpApp(
        tester,
        db: db,
        overrides: [apiClientProvider.overrideWith((_) async => api)],
      );
      container.read(routerProvider).go('/catalog');
      await tester.pumpAndSettle();
      await tester.tap(find.text(quiz.title));
      await tester.pumpAndSettle();
      expect(find.text('Shared quiz'), findsOneWidget);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      final entry = (await QuizRepository(db).getById(quiz.id))!;
      expect(entry.isReadOnly, !owned);
      expect(entry.ownerName, 'sam');
      expect(entry.remoteVersion, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
