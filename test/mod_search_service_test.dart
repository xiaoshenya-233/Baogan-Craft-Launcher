import 'dart:io';

import 'package:baogan_craft_launcher/services/translation/mod_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('releases the bundled dictionary and never overwrites it', () async {
    final directory = await Directory.systemTemp.createTemp('dictionary-');
    addTearDown(() => directory.delete(recursive: true));

    final first = await ModSearchService.instance.ensureDatabaseExtracted(
      dataDirectory: directory.path,
    );
    expect(first, isNotNull);
    final file = File(first!);
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(0));

    // Player-collected translations must survive the next launch.
    await file.writeAsBytes(<int>[1, 2, 3], flush: true);
    final second = await ModSearchService.instance.ensureDatabaseExtracted(
      dataDirectory: directory.path,
    );
    expect(second, first);
    expect(await file.length(), 3);
  });

  test('returns null when the data directory is unavailable', () async {
    expect(
      await ModSearchService.instance.ensureDatabaseExtracted(
        dataDirectory: '   ',
      ),
      isNull,
    );
  });
}
