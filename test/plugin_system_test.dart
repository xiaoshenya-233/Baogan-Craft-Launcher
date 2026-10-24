import 'dart:convert';
import 'dart:io';

import 'package:baogan_craft_launcher/services/plugin/plugin_action_dispatcher.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manifest.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_startup_runner.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manager.dart';
import 'package:baogan_craft_launcher/widgets/plugin/plugin_ui_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('PluginManifest', () {
    test('parses a valid manifest and deduplicates permissions', () {
      final manifest = PluginManifest.fromJsonString(
        jsonEncode(<String, dynamic>{
          'id': 'demo.plugin',
          'name': 'Demo Plugin',
          'version': '1.0.0',
          'author': 'Cline',
          'description': 'A demo',
          'entryUi': 'ui/main.json',
          'permissions': ['download', 'network', 'download'],
        }),
        directoryPath: p.join('C:', 'plugins', 'demo'),
      );

      expect(manifest.id, 'demo.plugin');
      expect(manifest.entryUi, 'ui/main.json');
      expect(manifest.permissions, ['download', 'network']);
      expect(manifest.hasPermission('network'), isTrue);
      expect(manifest.toJson()['name'], 'Demo Plugin');
    });

    test('parses startup actions with optional params', () {
      final manifest = PluginManifest.fromJson(<String, dynamic>{
        'id': 'demo',
        'name': 'Demo',
        'version': '1.0.0',
        'entryUi': 'ui/main.json',
        'startupActions': <Map<String, dynamic>>[
          <String, dynamic>{
            'action': 'play_music_folder',
            'params': <String, dynamic>{'folder': 'Music'},
          },
          <String, dynamic>{'action': 'show_snackbar'},
        ],
      }, directoryPath: 'x');
      expect(manifest.startupActions, hasLength(2));
      expect(manifest.startupActions.first.action, 'play_music_folder');
      expect(manifest.startupActions.first.params['folder'], 'Music');
      expect(manifest.startupActions.last.params, isEmpty);
      expect(manifest.enableStartup, isFalse);

      final enabled = PluginManifest.fromJson(<String, dynamic>{
        'id': 'enabled',
        'name': 'Enabled',
        'version': '1.0.0',
        'entryUi': 'ui/main.json',
        'enableStartup': true,
      }, directoryPath: 'x');
      expect(enabled.enableStartup, isTrue);
    });

    test('rejects unsafe ids, paths and unknown permissions', () {
      Map<String, dynamic> base() => <String, dynamic>{
        'id': 'demo',
        'name': 'Demo',
        'version': '1.0.0',
        'entryUi': 'ui/main.json',
      };

      expect(
        () => PluginManifest.fromJson(
          base()..['id'] = '../escape',
          directoryPath: 'x',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PluginManifest.fromJson(
          base()..['entryUi'] = '../outside.json',
          directoryPath: 'x',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PluginManifest.fromJson(
          base()..['entryUi'] = 'C:/abs/main.json',
          directoryPath: 'x',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PluginManifest.fromJson(
          base()..['permissions'] = ['root'],
          directoryPath: 'x',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PluginManager', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('plugin_system_');
      PluginManager.instance.dataRootProvider = () => temp.path;
    });

    tearDown(() async {
      PluginManager.instance.dataRootProvider = null;
      await PluginManager.instance.reload();
      try {
        if (await temp.exists()) await temp.delete(recursive: true);
      } on FileSystemException {
        // Another process may still hold a handle; the OS cleans it up.
      }
    });

    Future<void> writePlugin(
      String folder,
      Map<String, dynamic> manifest, {
      Map<String, dynamic>? ui,
    }) async {
      final root = Directory(p.join(temp.path, 'plugins', folder));
      await root.create(recursive: true);
      await File(p.join(root.path, 'plugin.json'))
          .writeAsString(jsonEncode(manifest));
      if (ui != null) {
        final uiFile = File(p.join(root.path, 'ui', 'main.json'));
        await uiFile.parent.create(recursive: true);
        await uiFile.writeAsString(jsonEncode(ui));
      }
    }

    test('scans plugins, creates data folders and loads UI', () async {
      await writePlugin(
        'demo',
        <String, dynamic>{
          'id': 'demo',
          'name': 'Demo',
          'version': '1.0.0',
          'author': 'Cline',
          'description': '',
          'entryUi': 'ui/main.json',
          'permissions': ['download'],
        },
        ui: <String, dynamic>{'type': 'text', 'text': 'Hello'},
      );

      final plugins = await PluginManager.instance.reload();
      expect(plugins.map((plugin) => plugin.id), ['demo']);
      expect(PluginManager.instance.pluginsDirectoryPath, isNotNull);
      expect(Directory(p.join(temp.path, 'plugins_data')).existsSync(), isTrue);
      expect(
        Directory(p.join(temp.path, 'plugins_data', 'demo')).existsSync(),
        isTrue,
      );

      final document = await PluginManager.instance.loadUiDocument(
        plugins.single,
      );
      expect(document?['text'], 'Hello');
      expect(PluginManager.instance.byId('demo'), isNotNull);
    });

    test('dispatches startup actions after scanning', () async {
      await writePlugin('startup', <String, dynamic>{
        'id': 'startup',
        'name': 'Startup',
        'version': '1.0.0',
        'entryUi': 'ui/main.json',
        'permissions': <String>['file_system'],
        'enableStartup': true,
        'startupActions': <Map<String, dynamic>>[
          <String, dynamic>{
            'action': 'play_music_folder',
            'params': <String, dynamic>{'folder': 'Music'},
          },
          <String, dynamic>{'action': 'launch_game'},
        ],
      });

      await writePlugin('manual', <String, dynamic>{
        'id': 'manual',
        'name': 'Manual',
        'version': '1.0.0',
        'entryUi': 'ui/main.json',
        'permissions': <String>['file_system'],
        'startupActions': <Map<String, dynamic>>[
          <String, dynamic>{
            'action': 'play_music_folder',
            'params': <String, dynamic>{'folder': 'Music'},
          },
        ],
      });

      final plugins = await PluginManager.instance.reload();
      final received = <String>[];
      await PluginStartupRunner.instance.run(
        plugins,
        dispatch: (manifest, action, params) async {
          received.add('${manifest.id}:$action:${params['folder'] ?? ''}');
          return const PluginActionResult(PluginActionStatus.success);
        },
      );

      expect(received, <String>['startup:play_music_folder:Music']);
    });

    test('skips invalid manifests without failing the scan', () async {
      await writePlugin('broken', <String, dynamic>{
        'id': 'Broken Id!',
        'name': 'Broken',
        'version': '1.0.0',
        'entryUi': 'ui/main.json',
      });
      await writePlugin('empty', <String, dynamic>{});

      final plugins = await PluginManager.instance.reload();
      expect(plugins, isEmpty);
      expect(PluginManager.instance.isLoaded, isTrue);
      expect(Directory(p.join(temp.path, 'plugins')).existsSync(), isTrue);
      expect(Directory(p.join(temp.path, 'plugins_data')).existsSync(), isTrue);
    });
  });

  testWidgets('renderer renders nodes and forwards actions with fields', (
    WidgetTester tester,
  ) async {
    String? action;
    Map<String, dynamic>? params;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PluginUiRenderer(
            document: <String, dynamic>{
              'type': 'column',
              'padding': 16,
              'spacing': 8,
              'children': [
                <String, dynamic>{'type': 'text', 'text': 'Hello plugin'},
                <String, dynamic>{
                  'type': 'textfield',
                  'id': 'name',
                  'label': 'Name',
                },
                <String, dynamic>{
                  'type': 'filledbutton',
                  'label': 'Send',
                  'action': 'submit',
                  'params': <String, dynamic>{'kind': 'demo'},
                },
                <String, dynamic>{
                  'type': 'listview',
                  'height': 100,
                  'children': [
                    <String, dynamic>{'type': 'text', 'text': 'row 0'},
                    <String, dynamic>{'type': 'text', 'text': 'row 1'},
                  ],
                },
              ],
            },
            onAction: (value, payload) {
              action = value;
              params = payload;
            },
          ),
        ),
      ),
    );

    expect(find.text('Hello plugin'), findsOneWidget);
    expect(find.text('row 0'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Cline');
    await tester.tap(find.text('Send'));
    await tester.pump();

    expect(action, 'submit');
    expect(params?['kind'], 'demo');
    expect((params?['fields'] as Map)['name'], 'Cline');
  });

  group('PluginActionDispatcher', () {
    PluginManifest manifest(List<String> permissions) =>
        PluginManifest.fromJson(<String, dynamic>{
          'id': 'demo',
          'name': 'Demo',
          'version': '1.0.0',
          'entryUi': 'ui/main.json',
          'permissions': permissions,
        }, directoryPath: p.join('C:', 'plugins', 'demo'));

    test('open_folder requires file_system permission', () async {
      var opened = false;
      final dispatcher = PluginActionDispatcher(
        onNavigate: (_) {},
        onLaunchGame: () async {},
        openFolder: (_, _) async {
          opened = true;
          return ProcessResult(0, 0, '', '');
        },
      );

      final result = await dispatcher.dispatch(
        manifest(const <String>[]),
        'open_folder',
        <String, dynamic>{'folder': ''},
      );

      expect(result.status, PluginActionStatus.denied);
      expect(result.permission, PluginPermissions.fileSystem);
      expect(opened, isFalse);
    });

    test(
      'open_folder creates and opens a folder inside plugins/<id>',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'plugin_open_folder_',
        );
        addTearDown(() async {
          try {
            if (await root.exists()) await root.delete(recursive: true);
          } on FileSystemException {
            // Windows may still hold a handle briefly.
          }
        });
        final pluginRoot = p.join(root.path, 'demo');
        final plugin = PluginManifest.fromJson(<String, dynamic>{
          'id': 'demo',
          'name': 'Demo',
          'version': '1.0.0',
          'entryUi': 'ui/main.json',
          'permissions': <String>['file_system'],
        }, directoryPath: pluginRoot);
        String? executable;
        List<String>? arguments;
        final dispatcher = PluginActionDispatcher(
          onNavigate: (_) {},
          onLaunchGame: () async {},
          openFolder: (value, args) async {
            executable = value;
            arguments = args;
            return ProcessResult(0, 0, '', '');
          },
        );

        final result = await dispatcher.dispatch(
          plugin,
          'open_folder',
          <String, dynamic>{'folder': 'Music'},
        );

        expect(result.isSuccess, isTrue);
        final target = p.normalize(p.absolute(p.join(pluginRoot, 'Music')));
        expect(Directory(target).existsSync(), isTrue);
        expect(arguments, <String>[target]);
        expect(executable, anyOf('explorer', 'open', 'xdg-open'));

        final escaped = await dispatcher.dispatch(
          plugin,
          'open_folder',
          <String, dynamic>{'folder': '../escape'},
        );
        expect(escaped.status, PluginActionStatus.invalid);
      },
    );

    test('denies actions without the required permission', () async {
      var navigated = false;
      var launched = false;
      final dispatcher = PluginActionDispatcher(
        onNavigate: (_) => navigated = true,
        onLaunchGame: () async => launched = true,
      );

      final result = await dispatcher.dispatch(
        manifest(const <String>[]),
        'launch_game',
        <String, dynamic>{},
      );

      expect(result.status, PluginActionStatus.denied);
      expect(result.permission, PluginPermissions.fileSystem);
      expect(launched, isFalse);

      final navigate = await dispatcher.dispatch(
        manifest(const <String>[]),
        'navigate_to',
        <String, dynamic>{'page': 'settings'},
      );
      expect(navigate.isSuccess, isTrue);
      expect(navigated, isTrue);
    });

    test('routes navigation, launch and snackbar actions', () async {
      String? navigated;
      var launched = false;
      String? message;
      final dispatcher = PluginActionDispatcher(
        onNavigate: (page) => navigated = page,
        onLaunchGame: () async => launched = true,
        onMessage: (value) => message = value,
      );

      final plugin = manifest(<String>[
        PluginPermissions.fileSystem,
        PluginPermissions.network,
      ]);
      expect(
        (await dispatcher.dispatch(plugin, 'navigate_to', <String, dynamic>{
          'page': 'download_tasks',
        })).isSuccess,
        isTrue,
      );
      expect(navigated, 'download_tasks');

      expect(
        (await dispatcher.dispatch(
          plugin,
          'launch_game',
          <String, dynamic>{},
        )).isSuccess,
        isTrue,
      );
      expect(launched, isTrue);

      expect(
        (await dispatcher.dispatch(plugin, 'show_snackbar', <String, dynamic>{
          'message': 'Hello from plugin',
        })).isSuccess,
        isTrue,
      );
      expect(message, 'Hello from plugin');
    });

    test('validates URLs and rejects unknown actions', () async {
      final opened = <String>[];
      final dispatcher = PluginActionDispatcher(
        onNavigate: (_) {},
        onLaunchGame: () async {},
        openUrl: (url) async => opened.add(url),
      );
      final plugin = manifest(<String>[PluginPermissions.network]);

      final success = await dispatcher.dispatch(
        plugin,
        'open_url',
        <String, dynamic>{'url': 'https://example.com/map'},
      );
      expect(success.isSuccess, isTrue);
      expect(opened, ['https://example.com/map']);

      final unsafe = await dispatcher.dispatch(
        plugin,
        'open_url',
        <String, dynamic>{'url': 'file:///C:/Windows/system32'},
      );
      expect(unsafe.status, PluginActionStatus.invalid);
      expect(opened, hasLength(1));

      final unknown = await dispatcher.dispatch(
        plugin,
        'delete_everything',
        <String, dynamic>{},
      );
      expect(unknown.status, PluginActionStatus.invalid);
    });
  });

  testWidgets('webview nodes require the webview permission', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PluginUiRenderer(
            document: <String, dynamic>{
              'type': 'webview',
              'url': 'https://example.com/map',
              'height': 120,
            },
            grantedPermissions: const <String>{},
            onAction: (_, _) {},
          ),
        ),
      ),
    );
    expect(find.textContaining('webview'), findsOneWidget);
    expect(find.textContaining('https://example.com/map'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PluginUiRenderer(
            document: <String, dynamic>{
              'type': 'webview',
              'url': 'https://example.com/map',
              'height': 120,
            },
            grantedPermissions: const <String>{'webview'},
            onAction: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('https://example.com/map'), findsOneWidget);
  });

  group('PluginActionDispatcher sandbox', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('plugin_sandbox_');
      PluginManager.instance.dataRootProvider = () => temp.path;
    });

    tearDown(() async {
      PluginManager.instance.dataRootProvider = null;
      try {
        if (await temp.exists()) await temp.delete(recursive: true);
      } on FileSystemException {
        // Windows may still hold a handle.
      }
    });

    PluginManifest sandboxManifest([List<String> permissions = const []]) =>
        PluginManifest.fromJson(<String, dynamic>{
          'id': 'demo',
          'name': 'Demo',
          'version': '1.0.0',
          'entryUi': 'ui/main.json',
          'permissions': permissions,
        }, directoryPath: p.join('C:', 'plugins', 'demo'));

    PluginActionDispatcher dispatcher({
      Future<int> Function(String url, String path)? downloadFile,
    }) => PluginActionDispatcher(
      onNavigate: (_) {},
      onLaunchGame: () async {},
      downloadFile: downloadFile,
    );

    test('writes and reads files inside the plugin sandbox', () async {
      final plugin = sandboxManifest(<String>[PluginPermissions.fileSystem]);
      final runner = dispatcher();

      final write = await runner.dispatch(plugin, 'write_file', {
        'path': 'config/settings.json',
        'content': '{"volume":1}',
      });
      expect(write.isSuccess, isTrue);
      expect(write.data, greaterThan(0));

      final file = File(
        p.join(temp.path, 'plugins_data', 'demo', 'config', 'settings.json'),
      );
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), '{"volume":1}');

      final read = await runner.dispatch(plugin, 'read_file', {
        'path': 'config/settings.json',
      });
      expect(read.isSuccess, isTrue);
      expect(read.data, '{"volume":1}');
    });

    test('denies writes without permission and blocks traversal', () async {
      final runner = dispatcher();
      final denied = await runner.dispatch(sandboxManifest(), 'write_file', {
        'path': 'a.txt',
        'content': 'x',
      });
      expect(denied.status, PluginActionStatus.denied);
      expect(denied.permission, PluginPermissions.fileSystem);

      final plugin = sandboxManifest(<String>[PluginPermissions.fileSystem]);
      final traversal = await runner.dispatch(plugin, 'write_file', {
        'path': '../escape.txt',
        'content': 'x',
      });
      expect(traversal.isSuccess, isFalse);
      expect(traversal.message, contains('不安全'));
      expect(
        File(p.join(temp.path, 'plugins_data', 'escape.txt')).existsSync(),
        isFalse,
      );

      final readTraversal = await runner.dispatch(plugin, 'read_file', {
        'path': 'config/../../escape.txt',
      });
      expect(readTraversal.isSuccess, isFalse);
    });

    test('downloads into the sandbox with the download permission', () async {
      Uri? requested;
      String? targetPath;
      final runner = dispatcher(
        downloadFile: (url, path) async {
          requested = Uri.parse(url);
          targetPath = path;
          await File(path).writeAsString('png');
          return 3;
        },
      );
      final plugin = sandboxManifest(<String>[PluginPermissions.download]);
      final result = await runner.dispatch(plugin, 'download_file', {
        'url': 'https://example.com/map.png',
        'savePath': 'images/map.png',
      });

      expect(result.isSuccess, isTrue);
      expect(requested.toString(), 'https://example.com/map.png');
      expect(result.data, 3);
      final root = p.join(temp.path, 'plugins_data', 'demo');
      expect(p.isWithin(root, targetPath!), isTrue);
      expect(File(targetPath!).existsSync(), isTrue);

      final denied = await runner.dispatch(
        sandboxManifest(),
        'download_file',
        <String, dynamic>{
          'url': 'https://example.com/map.png',
          'savePath': 'images/map.png',
        },
      );
      expect(denied.status, PluginActionStatus.denied);
    });
  });
}
