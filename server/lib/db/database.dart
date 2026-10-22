import 'package:postgres/postgres.dart';

import '../config.dart';
import 'migrations.dart';

class Database {
  Database._(this.connection);
  final Connection connection;

  static Future<Database> open(Config config) async {
    final uri = Uri.parse(config.databaseUrl);
    final database = Database._(
      await Connection.open(
        Endpoint(
          host: uri.host,
          port: uri.port == 0 ? 5432 : uri.port,
          database: uri.pathSegments.first,
          username: uri.userInfo.split(':').first,
          password: uri.userInfo.contains(':')
              ? uri.userInfo.split(':').last
              : null,
        ),
        settings: const ConnectionSettings(sslMode: SslMode.disable),
      ),
    );
    await MigrationRunner(database.connection).run();
    return database;
  }

  Future<void> close() => connection.close();
}
