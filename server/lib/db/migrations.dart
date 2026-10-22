import 'dart:io';

import 'package:postgres/postgres.dart';

/// Applies each SQL migration exactly once, tracked in [schema_migrations].
class MigrationRunner {
  MigrationRunner(this.connection, {this.directory = 'server/migrations'});

  final Connection connection;
  final String directory;

  Future<void> run() async {
    await connection.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        name text PRIMARY KEY,
        applied_at timestamptz NOT NULL DEFAULT now()
      )
    ''');
    final applied = (await connection.execute(
      'SELECT name FROM schema_migrations',
    )).map((row) => row[0] as String).toSet();
    final migrations = Directory(directory).existsSync()
        ? Directory(directory)
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.sql'))
              .toList()
        : Directory('migrations')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.sql'))
              .toList();
    migrations.sort((a, b) => a.path.compareTo(b.path));
    for (final file in migrations) {
      final name = file.uri.pathSegments.last;
      if (applied.contains(name)) continue;
      await connection.runTx((session) async {
        await session.execute(await file.readAsString());
        await session.execute(
          Sql.named('INSERT INTO schema_migrations (name) VALUES (@name)'),
          parameters: {'name': name},
        );
      });
    }
  }
}
