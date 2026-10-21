import 'package:quiz_core/quiz_core.dart';
import 'package:test/test.dart';

void main() {
  test('current schema version is 1', () {
    expect(currentSchemaVersion, 1);
  });

  group('DocumentKind.fromWireName', () {
    test('round-trips every kind', () {
      for (final kind in DocumentKind.values) {
        expect(DocumentKind.fromWireName(kind.wireName), kind);
      }
    });

    test('returns null for an unknown kind', () {
      expect(DocumentKind.fromWireName('poll'), isNull);
    });
  });
}
