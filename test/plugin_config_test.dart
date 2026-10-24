import 'dart:convert';
import 'dart:io';

import 'package:baogan_craft_launcher/services/plugin/plugin_action_dispatcher.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manager.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manifest.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_startup_runner.dart';
import 'package:baogan_craft_launcher/widgets/plugin/plugin_ui_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('plugin config persistence', () {
    late Directory temp;
    late String dataDirectory;
    late String configPath;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('plugin_config_');
      PluginManager.instance.dataRootProvider = () => temp.path;
      dataDirectory = p.join(temp.path, 'plugins_data', 'config.demo');
      configPath = p.join(dataDirectory, 'config.json');
    });

    tearDown(() async {
      PluginManager.instance.dataRootProvider = null;
      try {
        if (await temp.exists()) await temp.delete(recursive: true);
      } on FileSystemException {
        // Windows may still hold a handle briefly.
      }
    });

    void writeConfig(Map<String, dynamic> value) {
      Directory(dataDirectory).createSync(recursive: true);
      File(configPath).writeAsStringSync(jsonEncode(value));
    }

    Future<Map<String, dynamic>> readConfig() async {
      final raw = await File(configPath).readAsString();
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    }

    PluginManifest manifest({
      List<Map<String, dynamic>> startupActions = const [],
    }) {
      return PluginManifest.fromJson(<String, dynamic>{
        'id': 'config.demo',
        'name': 'Config Demo',
        'version': '1.0.0',
        'entryUi': 'ui/main.json',
        'enableStartup': true,
        if (startupActions.isNotEmpty) 'startupActions': startupActions,
      }, directoryPath: p.join(temp.path, 'plugins', 'config.demo'));
    }

    test('config_update writes one key and preserves other keys', () async {
      writeConfig(<String, dynamic>{'volume': 0.5});
      final dispatcher = PluginActionDispatcher(
        onNavigate: (_) {},
        onLaunchGame: () async {},
      );

      final result = await dispatcher.dispatch(
        manifest(),
        'config_update',
        <String, dynamic>{'key': 'auto_play', 'value': false},
      );

      expect(result.isSuccess, isTrue);
      expect(result.message, 'config.json');
      final saved = await readConfig();
      expect(saved['auto_play'], isFalse);
      expect(saved['volume'], 0.5);
    });

    testWidgets('switch reads config and emits config_update on tap', (
      tester,
    ) async {
      writeConfig(<String, dynamic>{'auto_play': false});
      String? emittedAction;
      Map<String, dynamic>? emittedParams;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PluginUiRenderer(
              document: <String, dynamic>{
                'type': 'switch',
                'id': 'auto_play',
                'label': '启动时自动播放',
                'default': true,
              },
              dataDirectory: dataDirectory,
              onAction: (action, params) {
                emittedAction = action;
                emittedParams = params;
              },
            ),
          ),
        ),
      );

      await tester.pump();

      final tileFinder = find.byKey(
        const ValueKey<String>('plugin-switch:auto_play'),
      );
      expect(tileFinder, findsOneWidget);
      expect(tester.widget<SwitchListTile>(tileFinder).value, isFalse);
      expect(find.text('启动时自动播放'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(tester.widget<SwitchListTile>(tileFinder).value, isTrue);
      expect(emittedAction, 'config_update');
      expect(emittedParams?['key'], 'auto_play');
      expect(emittedParams?['value'], isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('switch falls back to default when config is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PluginUiRenderer(
              document: <String, dynamic>{
                'type': 'switch',
                'id': 'auto_play',
                'label': 'Auto play',
                'default': true,
              },
              dataDirectory: dataDirectory,
              onAction: (_, _) {},
            ),
          ),
        ),
      );

      await tester.pump();

      final tile = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey<String>('plugin-switch:auto_play')),
      );
      expect(tile.value, isTrue);
    });

    test(
      'startup runner skips play_music_folder when auto_play is false',
      () async {
        writeConfig(<String, dynamic>{'auto_play': false});
        final received = <String>[];
        final plugin = manifest(
          startupActions: <Map<String, dynamic>>[
            <String, dynamic>{
              'action': 'play_music_folder',
              'params': <String, dynamic>{'folder': 'Music'},
            },
            <String, dynamic>{
              'action': 'show_snackbar',
              'params': <String, dynamic>{'message': 'still runs'},
            },
          ],
        );

        await PluginStartupRunner.instance.run(
          <PluginManifest>[plugin],
          dispatch: (manifest, action, params) async {
            received.add(action);
            return const PluginActionResult(PluginActionStatus.success);
          },
        );

        expect(received, <String>['show_snackbar']);
      },
    );

    test('startup runner keeps playing when auto_play is true', () async {
      writeConfig(<String, dynamic>{'auto_play': true});
      final received = <String>[];
      final plugin = manifest(
        startupActions: <Map<String, dynamic>>[
          <String, dynamic>{
            'action': 'play_music_folder',
            'params': <String, dynamic>{'folder': 'Music'},
          },
        ],
      );

      await PluginStartupRunner.instance.run(
        <PluginManifest>[plugin],
        dispatch: (manifest, action, params) async {
          received.add(action);
          return const PluginActionResult(PluginActionStatus.success);
        },
      );

      expect(received, <String>['play_music_folder']);
    });
  });
}
