import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:baogan_craft_launcher/main.dart';

String _p(String base, String child) => '$base${Platform.pathSeparator}$child';

void main() {
  test('repair recognizes complete libraries and client jar by size', () async {
    final root = await Directory.systemTemp.createTemp('repair_test_');
    final versionDir = _p(
      root.path,
      'versions${Platform.pathSeparator}RepairTest',
    );
    await Directory(versionDir).create(recursive: true);
    final libraryPath = _p(
      root.path,
      'libraries${Platform.pathSeparator}org${Platform.pathSeparator}'
      'example${Platform.pathSeparator}test${Platform.pathSeparator}'
      '1.0${Platform.pathSeparator}test-1.0.jar',
    );
    await Directory(File(libraryPath).parent.path).create(recursive: true);
    await File(libraryPath).writeAsBytes(<int>[1, 2, 3]);
    await File(_p(versionDir, 'RepairTest.jar'))
        .writeAsBytes(<int>[1, 2, 3, 4]);
    await File(_p(versionDir, 'RepairTest.json')).writeAsString(
      jsonEncode(<String, Object?>{
        'id': 'RepairTest',
        'downloads': <String, Object?>{
          'client': <String, Object?>{
            'url': 'https://example.invalid/client.jar',
            'size': 4,
          },
        },
        'libraries': <Object?>[
          <String, Object?>{
            'name': 'org.example:test:1.0',
            'downloads': <String, Object?>{
              'artifact': <String, Object?>{
                'path': 'org/example/test/1.0/test-1.0.jar',
                'url': 'https://example.invalid/test-1.0.jar',
                'size': 3,
              },
            },
          },
        ],
      }),
    );

    var finalStatus = '';
    await const MinecraftDownloadService().repairVersion(
      minecraftDirectory: root.path,
      versionId: 'RepairTest',
      source: MinecraftDownloadSource.mojang,
      onProgress: (status) => finalStatus = status,
    );

    expect(finalStatus, '版本文件完整，无需补全。');
    await root.delete(recursive: true);
  });
}
