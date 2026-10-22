import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file the user picked, decoded as UTF-8.
class PickedFile {
  const PickedFile({required this.name, required this.contents});

  final String name;
  final String contents;
}

/// Opening and saving `.json` files through the platform dialogs. Behind an
/// interface so widget tests can replace the dialogs.
abstract interface class QuizFiles {
  /// Lets the user pick a `.json` file; `null` if they cancelled.
  Future<PickedFile?> pickJson();

  /// Lets the user choose where to save [contents] as [fileName]; returns
  /// false if they cancelled.
  Future<bool> saveJson(String fileName, String contents);
}

/// [QuizFiles] using the native dialogs: the Windows open/save dialogs, the
/// Android document picker / "save to" sheet, and the browser's file input and
/// download on the web.
class PlatformQuizFiles implements QuizFiles {
  const PlatformQuizFiles();

  @override
  Future<PickedFile?> pickJson() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import quiz',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    var contents = utf8.decode(bytes, allowMalformed: true);
    // Files saved by some editors start with a byte order mark.
    if (contents.startsWith('﻿')) contents = contents.substring(1);
    return PickedFile(name: file.name, contents: contents);
  }

  @override
  Future<bool> saveJson(String fileName, String contents) async {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Export quiz',
      fileName: fileName,
      bytes: utf8.encode(contents),
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    // On the web the file is downloaded directly and no Uri comes back.
    return kIsWeb || uri != null;
  }
}

final quizFilesProvider = Provider<QuizFiles>(
  (ref) => const PlatformQuizFiles(),
);
