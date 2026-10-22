import 'package:quiz_core/quiz_core.dart';

import '../database/app_database.dart';
import 'library_repository.dart';

/// Quizzes in the local library.
class QuizRepository extends LibraryRepository<$QuizzesTable, Quiz> {
  QuizRepository(AppDatabase db, {super.clock, super.newId})
    : super(db, db.quizzes);

  @override
  Quiz decode(Map<String, dynamic> json) => Quiz.fromJson(json);

  @override
  Map<String, dynamic> encode(Quiz document) => document.toJson();

  @override
  String idOf(Quiz document) => document.id;

  @override
  String titleOf(Quiz document) => document.title;

  @override
  List<String> tagsOf(Quiz document) => document.tags;

  @override
  int versionOf(Quiz document) => document.version;

  @override
  DateTime updatedAtOf(Quiz document) => document.updatedAt;

  @override
  Quiz withRevision(
    Quiz document, {
    required int version,
    required DateTime at,
  }) => document.copyWith(version: version, updatedAt: at);

  @override
  Quiz asCopy(
    Quiz document, {
    required String id,
    required String title,
    required DateTime at,
  }) => document.copyWith(
    id: id,
    title: title,
    version: 1,
    createdAt: at,
    updatedAt: at,
  );
}
