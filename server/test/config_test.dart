import 'package:study_better_server/config.dart';
import 'package:test/test.dart';

void main() {
  test('uses defaults when the environment is empty', () {
    final config = Config.fromEnvironment(const {});

    expect(config.port, Config.defaultPort);
    expect(config.databaseUrl, Config.defaultDatabaseUrl);
    expect(config.databaseUrl, contains('sslmode=disable'));
    expect(config.jwtSecret, isNotEmpty);
    expect(config.jwtSecretIsGenerated, isTrue);
  });

  test('reads values from the environment', () {
    final config = Config.fromEnvironment(const {
      'PORT': '9090',
      'DATABASE_URL': 'postgres://u:p@db:5432/x?sslmode=require',
      'JWT_SECRET': 'secret',
    });

    expect(config.port, 9090);
    expect(config.databaseUrl, 'postgres://u:p@db:5432/x?sslmode=require');
    expect(config.jwtSecret, 'secret');
    expect(config.jwtSecretIsGenerated, isFalse);
  });

  test('generated secrets differ between instances', () {
    final a = Config.fromEnvironment(const {});
    final b = Config.fromEnvironment(const {});

    expect(a.jwtSecret, isNot(b.jwtSecret));
  });

  test('rejects an invalid PORT', () {
    expect(
      () => Config.fromEnvironment(const {'PORT': 'abc'}),
      throwsFormatException,
    );
    expect(
      () => Config.fromEnvironment(const {'PORT': '70000'}),
      throwsFormatException,
    );
  });
}
