// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_converter/models/file_item.dart';
import 'package:universal_converter/models/tool_info.dart';
import 'package:universal_converter/services/file_pick_service.dart';
import 'package:universal_converter/services/tool_catalog.dart';

FileItem _file(String name) => FileItem(
  path: '/in/$name',
  name: name,
  extension: name.split('.').last,
  sizeInBytes: 1000,
  category: FileItem.detectCategory(name.split('.').last),
  modifiedAt: DateTime(2026),
);

void main() {
  test('images get the image tools', () {
    final ids = ToolCatalog.toolsFor([_file('a.jpg')]).map((t) => t.id);
    expect(ids, containsAll([ToolId.imageCrop, ToolId.convert]));
  });

  test('single-file tools are blocked for several files', () {
    final files = [_file('a.jpg'), _file('b.png')];
    final crop = ToolCatalog.toolsFor(
      files,
    ).firstWhere((t) => t.id == ToolId.imageCrop);
    expect(ToolCatalog.blockedReason(crop, files), isNotNull);
    expect(ToolCatalog.blockedReason(crop, files.take(1).toList()), isNull);
  });

  test('videos do not get image tools', () {
    final ids = ToolCatalog.toolsFor([_file('a.mp4')]).map((t) => t.id);
    expect(ids, isNot(contains(ToolId.imageCrop)));
    expect(ids, contains(ToolId.convert));
  });

  test('picking keeps the category of the first supported file', () {
    final outcome = FilePickService.sortByCategory([
      _file('x.zip'),
      _file('a.mp4'),
      _file('b.jpg'),
      _file('c.mov'),
    ], null);
    expect(outcome.files.map((f) => f.name), ['a.mp4', 'c.mov']);
    expect(outcome.skipped, 2);
  });
}
