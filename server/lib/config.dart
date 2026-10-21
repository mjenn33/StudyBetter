import 'dart:convert';
import 'dart:math';

/// Server settings, read from environment variables.
///
/// | Variable       | Default                                                    |
/// |----------------|------------------------------------------------------------|
/// | `PORT`         | `8080`                                                     |
/// | `DATABASE_URL` | `postgres://studybetter:studybetter@localhost:5432/studybetter` |
/// | `JWT_SECRET`   | random per process (tokens stop working after a restart)  |
class Config {
  const Config({
    required this.port,
    required this.databaseUrl,
    required this.jwtSecret,
    required this.jwtSecretIsGenerated,
  });

  factory Config.fromEnvironment(Map<String, String> env) {
    final portValue = env['PORT'];
    final port = portValue == null ? defaultPort : int.tryParse(portValue);
    if (port == null || port < 0 || port > 65535) {
      throw FormatException('PORT must be a number from 0 to 65535', portValue);
    }

    final secret = env['JWT_SECRET'];
    final hasSecret = secret != null && secret.isNotEmpty;

    return Config(
      port: port,
      databaseUrl: env['DATABASE_URL'] ?? defaultDatabaseUrl,
      jwtSecret: hasSecret ? secret : _randomSecret(),
      jwtSecretIsGenerated: !hasSecret,
    );
  }

  static const defaultPort = 8080;
  static const defaultDatabaseUrl =
      'postgres://studybetter:studybetter@localhost:5432/studybetter';

  final int port;
  final String databaseUrl;
  final String jwtSecret;

  /// True when `JWT_SECRET` was not set and a random one was generated.
  final bool jwtSecretIsGenerated;

  static String _randomSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}
