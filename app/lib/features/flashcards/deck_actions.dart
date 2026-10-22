import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_core/quiz_core.dart';

import '../../data/repositories/providers.dart';
import '../quizzes/transfer/quiz_files.dart';
import 'deck_transfer.dart';

abstract final class DeckActions {
  static Future<void> export(
    BuildContext context,
    WidgetRef ref,
    FlashcardDeck deck,
  ) async {
    if (validateDeck(deck).isNotEmpty) return;
    final saved = await ref
        .read(quizFilesProvider)
        .saveJson(deckExportFileName(deck), exportDeckJson(deck));
    if (saved && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exported "${deck.title}"')));
    }
  }

  static Future<void> import(BuildContext context, WidgetRef ref) async {
    final file = await ref.read(quizFilesProvider).pickJson();
    if (file == null || !context.mounted) return;
    final FlashcardDeck deck;
    final List<ValidationIssue> problems;
    try {
      (deck, problems) = readDeckFile(file.contents);
    } on DeckImportException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    if (problems.isNotEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Can\'t import: ${problems.first.message}')),
        );
      }
      return;
    }
    final importer = DeckImporter(ref.read(deckRepositoryProvider));
    final existing = await importer.existing(deck);
    final saved = await importer.import(
      deck,
      choice: existing == null
          ? null
          : (existing.canReplace
                ? DeckImportChoice.replace
                : DeckImportChoice.copy),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Imported "${saved.title}"')));
    }
  }
}
