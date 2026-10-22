import 'package:quiz_core/quiz_core.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  final valid = FlashcardDeck.fromJson(readFixture('deck_v1.json'));
  final card = valid.cards.first;

  List<(String, ValidationCode)> check(FlashcardDeck deck) => [
    for (final issue in validateDeck(deck)) (issue.path, issue.code),
  ];

  test('the sample deck is valid', () {
    expect(validateDeck(valid), isEmpty);
  });

  test('id must be a UUID', () {
    expect(check(valid.copyWith(id: 'c3d1...')), [
      ('id', ValidationCode.invalidId),
    ]);
  });

  test('title must not be blank', () {
    expect(check(valid.copyWith(title: '')), [
      ('title', ValidationCode.emptyText),
    ]);
  });

  test('version must be at least 1', () {
    expect(check(valid.copyWith(version: 0)), [
      ('version', ValidationCode.outOfRange),
    ]);
  });

  test('at least one card', () {
    expect(check(valid.copyWith(cards: [])), [
      ('cards', ValidationCode.noCards),
    ]);
  });

  test('card ids must be unique and non-empty', () {
    final deck = valid.copyWith(
      cards: [
        card,
        card,
        card.copyWith(id: ''),
      ],
    );
    expect(check(deck), [
      ('cards[1].id', ValidationCode.duplicateId),
      ('cards[2].id', ValidationCode.emptyId),
    ]);
  });

  test('front and back must not be blank', () {
    final deck = valid.copyWith(
      cards: [card.copyWith(front: ' ', back: '')],
    );
    expect(check(deck), [
      ('cards[0].front', ValidationCode.emptyText),
      ('cards[0].back', ValidationCode.emptyText),
    ]);
  });

  test('the hint is optional and may be empty', () {
    final deck = valid.copyWith(cards: [card.copyWith(hint: '')]);
    expect(validateDeck(deck), isEmpty);
  });
}
