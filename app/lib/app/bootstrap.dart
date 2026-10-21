import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Initializes bindings and starts the app inside a [ProviderScope].
///
/// Startup work that must finish before the first frame (opening the
/// database, reading settings) goes here.
void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: StudyBetterApp()));
}
