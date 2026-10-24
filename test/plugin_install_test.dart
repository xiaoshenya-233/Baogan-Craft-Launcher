import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('plugin install and cleanup', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('plugin_install_');
      PluginManager.instance.dataRootProvider = () => temp.path;
    });

    tearDown(() async {
      PluginManager.instance.dataRootProvider = null;
      await PluginManager.instance.reload();
      try {
        if (await temp.exists()) await temp.delete(recursive: true);
      } on FileSystemException {
        // Windows may still hold a file handle briefly.
      }
    });

    Map<String, dynamic> manifest(String id) => <String, dynamic>{
      'id': id,
      'name': 'Plugin $id',
      'version': '1.0.0',
      'entryUi': 'ui/main.json',
    };

    List<int> text(String value) => utf8.encode(value);

    Future<File> makeZip(
      String fileName,
      Map<String, List<int>> entries,
    ) async {
      final archive = Archive();
      for (final entry in entries.entries) {
        archive.addFile(
          ArchiveFile(entry.key, entry.value.length, entry.value),
        );
      }
      final encoded = ZipEncoder().encode(archive);
      if (encoded == null) throw StateError('ZIP encode failed.');
      final file = File(p.join(temp.path, fileName));
      await file.writeAsBytes(encoded, flush: true);
      return file;
    }

    test('installs a ZIP with plugin.json at its root', () async {
      final zip = await makeZip('root.zip', <String, List<int>>{
        'plugin.json': text(jsonEncode(manifest('root.plugin'))),
        'ui/main.json': text('{"type":"text","text":"hi"}'),
        'Music/a.txt': text('a'),
      });

      final installed = await PluginManager.instance.installFromZip(zip.path);

      expect(installed.id, 'root.plugin');
      final root = p.join(temp.path, 'plugins', 'root.plugin');
      expect(File(p.join(root, 'plugin.json')).existsSync(), isTrue);
      expect(File(p.join(root, 'ui', 'main.json')).existsSync(), isTrue);
      expect(File(p.join(root, 'Music', 'a.txt')).existsSync(), isTrue);
      expect(PluginManager.instance.byId('root.plugin'), isNotNull);
    });

    test('installs a ZIP wrapped in one first-level folder', () async {
      final zip = await makeZip('nested.zip', <String, List<int>>{
        'wrapped/plugin.json': text(jsonEncode(manifest('nested.plugin'))),
        'wrapped/ui/main.json': text('{"type":"text","text":"hi"}'),
      });

      final installed = await PluginManager.instance.installFromZip(zip.path);

      expect(installed.id, 'nested.plugin');
      final root = p.join(temp.path, 'plugins', 'nested.plugin');
      expect(File(p.join(root, 'plugin.json')).existsSync(), isTrue);
      expect(File(p.join(root, 'ui', 'main.json')).existsSync(), isTrue);
      expect(
        File(p.join(root, 'wrapped', 'plugin.json')).existsSync(),
        isFalse,
      );
    });

    test('rejects ZIP entries that contain ../ (Zip Slip)', () async {
      final zip = await makeZip('slip.zip', <String, List<int>>{
        'plugin.json': text(jsonEncode(manifest('slip.plugin'))),
        '../evil.txt': text('evil'),
      });

      await expectLater(
        PluginManager.instance.installFromZip(zip.path),
        throwsA(isA<PluginInstallException>()),
      );

      expect(File(p.join(temp.path, 'evil.txt')).existsSync(), isFalse);
      expect(
        Directory(p.join(temp.path, 'plugins', 'slip.plugin')).existsSync(),
        isFalse,
      );
    });

    test('scan deletes plugin data folders without a valid plugin', () async {
      final pluginDir = Directory(p.join(temp.path, 'plugins', 'keep'));
      await pluginDir.create(recursive: true);
      await File(p.join(pluginDir.path, 'plugin.json'))
          .writeAsString(jsonEncode(manifest('keep')));
      final keepData = Directory(p.join(temp.path, 'plugins_data', 'keep'));
      await keepData.create(recursive: true);
      final orphan = Directory(p.join(temp.path, 'plugins_data', 'orphan'));
      await orphan.create(recursive: true);
      await File(p.join(orphan.path, 'junk.txt')).writeAsString('x');

      await PluginManager.instance.reload();

      expect(keepData.existsSync(), isTrue);
      expect(orphan.existsSync(), isFalse);
      expect(PluginManager.instance.byId('keep'), isNotNull);
    });

    test('uninstall removes both plugin and data folders', () async {
      final pluginDir = Directory(p.join(temp.path, 'plugins', 'demo'));
      await pluginDir.create(recursive: true);
      await File(p.join(pluginDir.path, 'plugin.json'))
          .writeAsString(jsonEncode(manifest('demo')));
      final dataDir = Directory(p.join(temp.path, 'plugins_data', 'demo'));
      await dataDir.create(recursive: true);
      await File(p.join(dataDir.path, 'state.json')).writeAsString('{}');
      await PluginManager.instance.reload();
      expect(PluginManager.instance.byId('demo'), isNotNull);

      await PluginManager.instance.uninstallPlugin('demo');

      expect(pluginDir.existsSync(), isFalse);
      expect(dataDir.existsSync(), isFalse);
      expect(PluginManager.instance.byId('demo'), isNull);
    });
  });
}
