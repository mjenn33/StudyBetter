import 'package:quiz_core/quiz_core.dart';

/// Validation issues grouped by their JSON path, for showing each one next
/// to the field it belongs to.
class IssueIndex {
  IssueIndex(this.issues);

  final List<ValidationIssue> issues;

  bool get isEmpty => issues.isEmpty;
  int get length => issues.length;

  /// Issues exactly at [path].
  List<ValidationIssue> at(String path) => [
    for (final i in issues)
      if (i.path == path) i,
  ];

  /// The first message exactly at [path], for a field's `errorText`.
  String? messageAt(String path) {
    final found = at(path);
    return found.isEmpty ? null : found.first.message;
  }

  /// Issues at [path] or anywhere inside it (`path.x`, `path[0]`).
  List<ValidationIssue> under(String path) => [
    for (final i in issues)
      if (i.path == path ||
          i.path.startsWith('$path.') ||
          i.path.startsWith('$path['))
        i,
  ];
}
