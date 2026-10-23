import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:baogan_craft_launcher/services/installer/game_installer.dart';

String _p(String base, String child) => '$base${Platform.pathSeparator}$child';

void main() {
  test(
    'reinstall backs up player data and restores it after core install',
    () async {
      final root = await Directory.systemTemp.createTemp('reinstaller_test_');
      final minecraft = _p(root.path, '.minecraft');
      final versionDir = _p(minecraft, 'versions${Platform.pathSeparator}Test');
      await Directory(_p(versionDir, 'mods')).create(recursive: true);
      await Directory(_p(versionDir, 'config')).create(recursive: true);
      await Directory(_p(versionDir, 'saves')).create(recursive: true);
      await Directory(_p(versionDir, 'resourcepacks')).create(recursive: true);
      await Directory(_p(versionDir, 'shaderpacks')).create(recursive: true);
      await File(_p(versionDir, 'options.txt')).writeAsString('options');
      await File(_p(versionDir, 'servers.dat')).writeAsString('servers');
      await File(_p(versionDir, 'Test.json')).writeAsString('{"id":"Test"}');
      await File(_p(versionDir, 'Test.jar')).writeAsString('core');
      await File(_p(_p(versionDir, 'mods'), 'example.jar'))
          .writeAsString('mod');
      await File(_p(_p(versionDir, 'config'), 'example.json'))
          .writeAsString('config');

      var callbackRan = false;
      final reinstaller = VersionReinstaller(
        minecraftDirectory: minecraft,
        versionName: 'Test',
        reinstallVersion: (name) async {
          callbackRan = true;
          expect(await Directory(_p(versionDir, 'mods')).exists(), isFalse);
          expect(await File(_p(versionDir, 'options.txt')).exists(), isFalse);
          expect(await File(_p(versionDir, 'Test.json')).exists(), isFalse);
          await File(_p(versionDir, 'Test.json')).writeAsString('{}');
          await File(_p(versionDir, 'Test.jar')).writeAsString('new-core');
        },
      );

      await reinstaller.reinstall();

      expect(callbackRan, isTrue);
      expect(
        await File(_p(_p(versionDir, 'mods'), 'example.jar')).readAsString(),
        'mod',
      );
      expect(
        await File(_p(_p(versionDir, 'config'), 'example.json')).readAsString(),
        'config',
      );
      expect(await Directory(_p(versionDir, 'saves')).exists(), isTrue);
      expect(
        await File(_p(versionDir, 'options.txt')).readAsString(),
        'options',
      );
      expect(
        await File(_p(versionDir, 'servers.dat')).readAsString(),
        'servers',
      );
      expect(await File(_p(versionDir, 'Test.jar')).readAsString(), 'new-core');
      expect(
        await Directory(
          _p(
            minecraft,
            'cache${Platform.pathSeparator}reinstall_backup'
            '${Platform.pathSeparator}Test',
          ),
        ).exists(),
        isFalse,
      );

      await root.delete(recursive: true);
    },
  );
}
