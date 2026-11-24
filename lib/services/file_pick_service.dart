// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../models/file_item.dart';
import 'format_catalog.dart';

/// Files the user picked, all of one category, plus how many were left out.
class PickOutcome {
  final List<FileItem> files;

  /// Files dropped because they were unsupported or of a different category.
  final int skipped;

  /// Set when the picker could not open.
  final String? error;

  const PickOutcome({this.files = const [], this.skipped = 0, this.error});
}

class FilePickService {
  static List<String> get _allExtensions => [
    for (final c in FileCategory.values) ...FormatCatalog.inputExtensionsFor(c),
  ];

  /// Opens the system picker. With [category] null any supported file can be
  /// picked; the result keeps only the category of the first supported file.
  static Future<PickOutcome> pick({
    FileCategory? category,
    void Function(bool loading)? onLoading,
  }) async {
    final type = switch (category) {
      FileCategory.image => FileType.image,
      FileCategory.video => FileType.video,
      FileCategory.audio => FileType.audio,
      _ => FileType.custom,
    };
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        type: type,
        allowedExtensions: type == FileType.custom
            ? (category == null
                  ? _allExtensions
                  : FormatCatalog.inputExtensionsFor(category))
            : null,
        onFileLoading: (status) =>
            onLoading?.call(status == FilePickerStatus.picking),
      );
    } on PlatformException catch (e) {
      return PickOutcome(error: 'Could not open the file picker: ${e.message}');
    } finally {
      onLoading?.call(false);
    }

    final items = [
      for (final p in picked)
        if (p.path != null) FileItem.fromFile(File(p.path!)),
    ];
    return sortByCategory(items, category);
  }

  /// Keeps files of [category], or of the first supported file's category
  /// when [category] is null. Everything else counts as skipped.
  static PickOutcome sortByCategory(
    List<FileItem> items,
    FileCategory? category,
  ) {
    final keep =
        category ??
        items
            .map((f) => f.category)
            .firstWhere(
              (c) => c != FileCategory.unknown,
              orElse: () => FileCategory.unknown,
            );
    final files = [
      for (final f in items)
        if (f.category == keep && keep != FileCategory.unknown) f,
    ];
    return PickOutcome(files: files, skipped: items.length - files.length);
  }
}
