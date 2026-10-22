import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// The app's database, opened on first use and closed with the provider
/// scope. Tests override it with an in-memory database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});
