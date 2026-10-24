import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:baogan_craft_launcher/services/network/modrinth_version_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(Object payload) =>
    Uint8List.fromList(utf8.encode(jsonEncode(payload)));

Map<String, Object?> _row(int index, {String? id}) => <String, Object?>{
  'id': id ?? 'version-$index',
  'name': 'JEI 1.21.1-$index',
  'version_type': 'release',
  'downloads': 1000 - index,
  'game_versions': <String>['1.21.1', '1.21.1-pre1'],
  'loaders': <String>['neoforge'],
  'files': <Object>[
    <String, Object?>{
      'filename': 'jei-$index.jar',
      'url': 'https://example.invalid/jei-$index.jar',
    },
  ],
};

void main() {
  test('isolate parses a full Modrinth page into sendable models', () async {
    final payload = _bytes(List<Object>.generate(60, _row));

    final versions = await Isolate.run(() => parseModrinthVersionPage(payload));

    expect(versions, hasLength(60));
    expect(versions.first.versionId, 'version-0');
    expect(versions.first.name, 'JEI 1.21.1-0');
    expect(versions.first.downloads, 1000);
    expect(versions.first.gameVersions, <String>['1.21.1']);
    expect(versions.first.loaders, <String>['neoforge']);
    expect(versions.first.files.single.filename, 'jei-0.jar');
  });

  test('version ids are deduplicated inside the parsed page', () {
    final payload = _bytes(<Object>[
      _row(1, id: 'same-id'),
      _row(2, id: 'same-id'),
      _row(3),
    ]);

    final versions = parseModrinthVersionPage(payload);

    expect(versions.map((version) => version.versionId), <String>[
      'same-id',
      'version-3',
    ]);
  });

  test('non-list responses fail with a format error', () {
    expect(
      () => parseModrinthVersionPage(_bytes(<String, Object?>{'error': 'x'})),
      throwsFormatException,
    );
  });
}
