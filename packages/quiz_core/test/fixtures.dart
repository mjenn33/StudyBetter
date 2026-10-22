import 'dart:convert';
import 'dart:io';

/// Reads `test/fixtures/<name>` as a JSON object.
///
/// Tests run with the package root as the working directory.
Map<String, dynamic> readFixture(String name) {
  final file = File('test/fixtures/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}
