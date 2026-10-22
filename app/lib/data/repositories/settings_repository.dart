import '../database/app_database.dart';

/// Small persistent preferences stored locally with the study data.
class SettingsRepository {
  SettingsRepository(this._db);
  final AppDatabase _db;

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
