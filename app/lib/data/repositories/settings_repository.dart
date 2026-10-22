import '../database/app_database.dart';

/// Small persistent preferences stored locally with the study data.
class SettingsRepository {
  SettingsRepository(this._db);
  final AppDatabase _db;

  Future<String> read(String key, String fallback) async {
    final row = await (_db.select(
      _db.settings,
    )..where((row) => row.key.equals(key))).getSingleOrNull();
    return row?.value ?? fallback;
  }

  Future<void> write(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  static const newCardsPerDayKey = 'flashcards.newCardsPerDay';

  Future<int> newCardsPerDay() async {
    final row = await (_db.select(
      _db.settings,
    )..where((row) => row.key.equals(newCardsPerDayKey))).getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? 20;
  }

  Future<void> setNewCardsPerDay(int value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: newCardsPerDayKey,
          value: value.clamp(1, 999).toString(),
        ),
      );
}
