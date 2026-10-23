import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baogan_craft_launcher/services/installer/game_installer.dart';

void main() {
  test('parses the CurseForge manifest example', () {
    final json = jsonEncode({
      'minecraft': {
        'version': '1.20.1',
        'modLoaders': [
          {'id': 'forge-47.2.0', 'primary': true},
        ],
      },
      'manifestType': 'minecraftModpack',
      'manifestVersion': 1,
      'name': 'Test Pack',
      'version': '1.0.0',
      'author': 'Tester',
      'files': [
        {'projectID': 238222, 'fileID': 4584123, 'required': true},
        {'projectID': 306770, 'fileID': 4398123, 'required': false},
      ],
      'overrides': 'overrides',
    });

    final manifest = parseCurseForgeManifest(json);
    expect(manifest.name, 'Test Pack');
    expect(manifest.version, '1.0.0');
    expect(manifest.author, 'Tester');
    expect(manifest.minecraftVersion, '1.20.1');
    expect(manifest.manifestType, 'minecraftModpack');
    expect(manifest.manifestVersion, 1);
    expect(manifest.primaryModLoaderId, 'forge-47.2.0');
    expect(manifest.loader, 'forge');
    expect(manifest.loaderVersion, '47.2.0');
    expect(manifest.overridesDirectory, 'overrides');
    expect(manifest.files, hasLength(2));
    expect(manifest.requiredFiles, hasLength(1));
    expect(manifest.files.first.projectId, 238222);
    expect(manifest.files.first.fileId, 4584123);
  });

  test('parses common loader id variants', () {
    expect(
      parseCurseForgeManifestMap({
        'minecraft': {
          'version': '1.21.1',
          'modLoaders': [
            {'id': 'neoforge-21.1.248', 'primary': true},
          ],
        },
        'files': [],
      }).loader,
      'neoforge',
    );
    expect(
      parseCurseForgeManifestMap({
        'minecraft': {
          'version': '1.20.1',
          'modLoaders': [
            {'id': 'fabric-loader-0.15.11', 'primary': true},
          ],
        },
        'files': [],
      }).loader,
      'fabric',
    );
  });

  test('rejects invalid manifest JSON', () {
    expect(
      () => parseCurseForgeManifest('{not json'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseCurseForgeManifest('{}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('detects a CurseForge ZIP and uses its overrides directory', () async {
    final directory = await Directory.systemTemp.createTemp('modpack-detect');
    final file = File('${directory.path}${Platform.pathSeparator}pack.zip');
    final manifestBytes = utf8.encode(
      jsonEncode({
        'minecraft': {
          'version': '1.21.1',
          'modLoaders': [
            {'id': 'neoforge-21.1.248', 'primary': true},
          ],
        },
        'manifestType': 'minecraftModpack',
        'manifestVersion': 1,
        'name': 'CF Pack',
        'version': '2.0.0',
        'files': [
          {'projectID': 1, 'fileID': 2, 'required': true},
        ],
        'overrides': 'custom-overrides',
      }),
    );
    final archive = Archive()
      ..addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
      );
    await file.writeAsBytes(ZipEncoder().encode(archive)!);

    final package = await const ModpackInstaller().open(file);
    expect(package.format, ModpackFormat.curseForge);
    expect(package.curseForgeManifest?.name, 'CF Pack');
    expect(package.manifest.minecraftVersion, '1.21.1');
    expect(package.manifest.loader, 'neoforge');
    expect(package.manifest.loaderVersion, '21.1.248');
    expect(package.manifest.files, isEmpty);
    expect(package.manifest.overridesPrefixes, ['custom-overrides/']);

    await directory.delete(recursive: true);
  });
}
