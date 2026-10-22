import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:study_better_server/config.dart';
import 'package:study_better_server/server.dart';

Future<void> main() async {
  final config = Config.fromEnvironment(Platform.environment);
  if (config.jwtSecretIsGenerated) {
    stderr.writeln(
      'Warning: JWT_SECRET is not set; using a random secret. '
      'Tokens will stop working when the server restarts.',
    );
  }

  final server = await shelf_io.serve(
    buildHandler(config),
    InternetAddress.anyIPv4,
    config.port,
  );
  print('Serving at http://${server.address.host}:${server.port}$apiBasePath');

  // Ctrl+C locally; SIGTERM from `docker stop` (not supported on Windows).
  final signals = [
    ProcessSignal.sigint.watch(),
    if (!Platform.isWindows) ProcessSignal.sigterm.watch(),
  ];
  for (final signal in signals) {
    signal.first.then((_) async {
      await server.close();
      exit(0);
    });
  }
}
