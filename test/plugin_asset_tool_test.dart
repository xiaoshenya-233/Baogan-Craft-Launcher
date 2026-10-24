import 'dart:convert';
import 'dart:io';

import 'package:baogan_craft_launcher/services/plugin/plugin_action_dispatcher.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_file_sandbox.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manager.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manifest.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_tool_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late String pluginDirectory;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('plugin_assets_');
    PluginManager.instance.dataRootProvider = () => temp.path;
    pluginDirectory = p.join(temp.path, 'plugins', 'demo');
    final tool = File(p.join(pluginDirectory, 'bin', 'parser.exe'));
    await tool.parent.create(recursive: true);
    await tool.writeAsString('fake-exe');
    final audio = File(p.join(pluginDirectory, 'audio', 'bgm.mp3'));
    await audio.parent.create(recursive: true);
    await audio.writeAsString('mp3');
    final dataFile = File(
      p.join(temp.path, 'plugins_data', 'demo', 'cache', 'state.json'),
    );
    await dataFile.parent.create(recursive: true);
    await dataFile.writeAsString('{"ok":true}');
  });

  tearDown(() async {
    PluginManager.instance.dataRootProvider = null;
    try {
      if (await temp.exists()) await temp.delete(recursive: true);
    } on FileSystemException {
      // Windows may still hold a handle.
    }
  });

  PluginManifest manifest([List<String> permissions = const []]) =>
      PluginManifest.fromJson(<String, dynamic>{
        'id': 'demo',
        'name': 'Demo',
        'version': '1.0.0',
        'entryUi': 'ui/main.json',
        'permissions': permissions,
      }, directoryPath: pluginDirectory);

  test('resolves static assets and runtime data with traversal blocked', () {
    final plugin = manifest();

    final staticAudio = PluginFileSandbox.resolveReadable(
      plugin,
      'audio/bgm.mp3',
    );
    expect(staticAudio, isNotNull);
    expect(p.isWithin(pluginDirectory, staticAudio!), isTrue);

    final runtime = PluginFileSandbox.resolveReadable(
      plugin,
      'cache/state.json',
    );
    expect(runtime, isNotNull);
    expect(
      p.isWithin(p.join(temp.path, 'plugins_data', 'demo'), runtime!),
      isTrue,
    );

    expect(PluginFileSandbox.resolveReadable(plugin, '../outside.txt'), isNull);
    expect(
      PluginFileSandbox.resolveReadable(plugin, 'audio/../../escape.txt'),
      isNull,
    );
  });

  group('execute_tool', () {
    late List<({String exe, List<String> args, String cwd})> calls;

    PluginActionDispatcher runner() => PluginActionDispatcher(
      onNavigate: (_) {},
      onLaunchGame: () async {},
      runTool: (exe, args, cwd) async {
        calls.add((exe: exe, args: args, cwd: cwd));
        return const PluginToolResult(exitCode: 0, stdout: 'ok', stderr: '');
      },
    );

    setUp(() {
      calls = [];
    });

    test('denies execution without the execute permission', () async {
      final result = await runner().dispatch(
        manifest(),
        'execute_tool',
        <String, dynamic>{
          'path': 'bin/parser.exe',
          'args': <String>['--scan'],
        },
      );
      expect(result.status, PluginActionStatus.denied);
      expect(result.permission, PluginPermissions.execute);
      expect(calls, isEmpty);
    });

    test('runs the tool directly inside its own folder', () async {
      final result = await runner().dispatch(
        manifest(<String>[PluginPermissions.execute]),
        'execute_tool',
        <String, dynamic>{
          'path': 'bin/parser.exe',
          'args': <String>['--scan'],
        },
      );
      expect(result.isSuccess, isTrue);
      expect(calls, hasLength(1));
      expect(p.isWithin(pluginDirectory, calls.single.exe), isTrue);
      expect(calls.single.args, <String>['--scan']);
      expect(calls.single.cwd, p.dirname(calls.single.exe));

      final data = result.data! as Map<String, dynamic>;
      expect(data['exitCode'], 0);
      expect(data['stdout'], 'ok');
      expect(jsonEncode(data), contains('stderr'));
    });

    test('blocks traversal and missing binaries', () async {
      final plugin = manifest(<String>[PluginPermissions.execute]);
      final traversal = await runner().dispatch(
        plugin,
        'execute_tool',
        <String, dynamic>{'path': '../evil.exe'},
      );
      expect(traversal.isSuccess, isFalse);
      expect(traversal.message, contains('安全拦截'));
      expect(calls, isEmpty);

      final missing = await runner().dispatch(
        plugin,
        'execute_tool',
        <String, dynamic>{'path': 'bin/missing.exe'},
      );
      expect(missing.isSuccess, isFalse);
      expect(calls, isEmpty);

      final badArgs = await runner().dispatch(
        plugin,
        'execute_tool',
        <String, dynamic>{'path': 'bin/parser.exe', 'args': 'not-a-list'},
      );
      expect(badArgs.status, PluginActionStatus.invalid);
    });
  });
}
