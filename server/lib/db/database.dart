import 'package:postgres/postgres.dart';

import '../config.dart';
import 'migrations.dart';

class Database {
  Database._(this.connection);
  final Connection connection;

  static Future<Database> open(Config config) async {
    final database = Database._(
      // Let postgres parse the whole URL so its sslmode, encoded password,
      // certificate, timeout, and host settings are all preserved.
      await Connection.openFromUrl(config.databaseUrl),
    );
    await MigrationRunner(database.connection).run();
    return database;
  }

  Future<void> close() => connection.close();
}
