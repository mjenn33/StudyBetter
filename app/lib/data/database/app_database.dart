import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quiz_core/quiz_core.dart' show Grade;

import 'converters.dart';
import 'library_item_row.dart';
import 'tables.dart';

export 'library_item_row.dart';
export 'tables.dart' show LibraryItemColumns, LibraryOrigin;

part 'app_database.g.dart';

/// The app's local SQLite database: the source of truth on the device.
@DriftDatabase(
  tables: [
    Quizzes,
    Attempts,
    AttemptAnswers,
    Decks,
    CardReviews,
    ReviewLog,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens [executor]; use [AppDatabase.open] in the app and an in-memory
  /// executor in tests.
  AppDatabase(super.executor);

  /// Opens the on-device database file `study_better.sqlite` in the app
  /// support directory (`%APPDATA%\com.studybetter\StudyBetter` on Windows,
  /// app-private storage on Android). drift_flutter's default is the
  /// documents directory, which on Windows is the user's Documents folder.
  ///
  /// On the web it runs sqlite3 compiled to WebAssembly, storing the database
  /// in the browser (OPFS or IndexedDB); `sqlite3.wasm` and `drift_worker.js`
  /// are served from `web/` and must match the resolved `sqlite3` and `drift`
  /// package versions.
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'study_better',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  /// Bump when a table changes, then:
  /// 1. `dart run drift_dev make-migrations` (from `app/`) to export the new
  ///    schema to `drift_schemas/` and generate step helpers and tests;
  /// 2. add the step to [migration]'s `onUpgrade` (`stepByStep(...)`);
  /// 3. run the generated migration tests.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
