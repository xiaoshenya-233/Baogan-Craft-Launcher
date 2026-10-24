import 'dart:io';

import 'package:baogan_craft_launcher/core/preferences_store.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_action_dispatcher.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manifest.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_permission_service.dart';
import 'package:baogan_craft_launcher/widgets/plugin/plugin_uac_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File preferencesFile;
  late PluginPermissionService permissions;
  late File hostFile;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('plugin-uac-');
    preferencesFile = File(
      '${directory.path}${Platform.pathSeparator}prefs.json',
    );
    final store = PreferencesStore(fileProvider: () => preferencesFile);
    permissions = PluginPermissionService(preferences: store);
    hostFile = File('${directory.path}${Platform.pathSeparator}secret.txt');
    await hostFile.writeAsString('host-secret');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  PluginManifest manifest(List<String> permissions) =>
      PluginManifest.fromJson(<String, dynamic>{
        'id': 'uac-demo',
        'name': 'UAC Demo',
        'version': '1.0.0',
        'entryUi': 'ui/main.json',
        'permissions': permissions,
      }, directoryPath: 'plugins/uac-demo');

  test('host reads without declaration are denied before prompting', () async {
    var prompts = 0;
    final dispatcher = PluginActionDispatcher(
      onNavigate: (_) {},
      onLaunchGame: () async {},
      permissionService: permissions,
      uacPrompt: (_, _, _) async {
        prompts++;
        return PluginPermissionDecision.once;
      },
    );

    final result = await dispatcher.dispatch(
      manifest(const <String>[]),
      'read_file',
      <String, dynamic>{'path': hostFile.path},
    );

    expect(result.status, PluginActionStatus.denied);
    expect(result.permission, PluginPermissions.hostFs);
    expect(prompts, 0);
  });

  test('absolute host read with minecraft_read asks for consent', () async {
    var prompts = 0;
    final dispatcher = PluginActionDispatcher(
      onNavigate: (_) {},
      onLaunchGame: () async {},
      permissionService: permissions,
      uacPrompt: (_, permission, path) async {
        prompts++;
        expect(permission, PluginPermissions.minecraftRead);
        expect(path, hostFile.path);
        return PluginPermissionDecision.once;
      },
    );

    final result = await dispatcher.dispatch(
      manifest(<String>[PluginPermissions.minecraftRead]),
      'read_file',
      <String, dynamic>{'path': hostFile.path},
    );

    expect(result.status, PluginActionStatus.success);
    expect(result.data, 'host-secret');
    expect(prompts, 1);
  });

  test('absolute host read with file_system asks for consent', () async {
    var prompts = 0;
    final dispatcher = PluginActionDispatcher(
      onNavigate: (_) {},
      onLaunchGame: () async {},
      permissionService: permissions,
      uacPrompt: (_, permission, path) async {
        prompts++;
        expect(permission, PluginPermissions.fileSystem);
        expect(path, hostFile.path);
        return PluginPermissionDecision.once;
      },
    );

    final result = await dispatcher.dispatch(
      manifest(<String>[PluginPermissions.fileSystem]),
      'read_file',
      <String, dynamic>{'path': hostFile.path},
    );

    expect(result.status, PluginActionStatus.success);
    expect(result.data, 'host-secret');
    expect(prompts, 1);
  });

  test(
    'resetForPlugin clears always decision so next read prompts again',
    () async {
      var prompts = 0;
      final plugin = manifest(<String>[PluginPermissions.minecraftRead]);
      await permissions.setState(
        plugin.id,
        PluginPermissions.minecraftRead,
        PluginPermissionState.always,
      );
      final dispatcher = PluginActionDispatcher(
        onNavigate: (_) {},
        onLaunchGame: () async {},
        permissionService: permissions,
        uacPrompt: (_, _, _) async {
          prompts++;
          return PluginPermissionDecision.once;
        },
      );

      final first = await dispatcher.dispatch(plugin, 'read_file', {
        'path': hostFile.path,
      });
      expect(first.status, PluginActionStatus.success);
      expect(prompts, 0);

      await permissions.resetForPlugin(plugin.id);
      expect(
        await permissions.stateFor(plugin.id, PluginPermissions.minecraftRead),
        PluginPermissionState.ask,
      );

      final second = await dispatcher.dispatch(plugin, 'read_file', {
        'path': hostFile.path,
      });
      expect(second.status, PluginActionStatus.success);
      expect(prompts, 1);
    },
  );

  test('always allow persists and skips the next prompt', () async {
    var prompts = 0;
    final dispatcher = PluginActionDispatcher(
      onNavigate: (_) {},
      onLaunchGame: () async {},
      permissionService: permissions,
      uacPrompt: (manifest, permission, path) async {
        prompts++;
        return PluginPermissionDecision.always;
      },
    );
    final plugin = manifest(<String>[PluginPermissions.hostFs]);

    final first = await dispatcher.dispatch(plugin, 'read_file', {
      'path': hostFile.path,
    });
    expect(first.status, PluginActionStatus.success);
    expect(first.data, 'host-secret');
    expect(prompts, 1);
    expect(
      await permissions.stateFor(plugin.id, PluginPermissions.hostFs),
      PluginPermissionState.always,
    );

    final second = await dispatcher.dispatch(plugin, 'read_file', {
      'path': hostFile.path,
    });
    expect(second.status, PluginActionStatus.success);
    expect(prompts, 1);
  });

  test('deny persists without reading the host file', () async {
    var prompts = 0;
    final dispatcher = PluginActionDispatcher(
      onNavigate: (_) {},
      onLaunchGame: () async {},
      permissionService: permissions,
      uacPrompt: (_, _, _) async {
        prompts++;
        return PluginPermissionDecision.deny;
      },
    );
    final plugin = manifest(<String>[PluginPermissions.hostFs]);

    final result = await dispatcher.dispatch(plugin, 'read_file', {
      'path': hostFile.path,
    });
    expect(result.status, PluginActionStatus.denied);
    expect(prompts, 1);
    expect(
      await permissions.stateFor(plugin.id, PluginPermissions.hostFs),
      PluginPermissionState.deny,
    );

    final again = await dispatcher.dispatch(plugin, 'read_file', {
      'path': hostFile.path,
    });
    expect(again.status, PluginActionStatus.denied);
    expect(prompts, 1);
  });

  test('traversal read with minecraft_read asks for consent', () async {
    var prompts = 0;
    final dispatcher = PluginActionDispatcher(
      onNavigate: (_) {},
      onLaunchGame: () async {},
      permissionService: permissions,
      uacPrompt: (_, permission, path) async {
        prompts++;
        expect(permission, PluginPermissions.minecraftRead);
        expect(path, contains('options.txt'));
        return PluginPermissionDecision.deny;
      },
    );

    final result = await dispatcher.dispatch(
      manifest(<String>[PluginPermissions.minecraftRead]),
      'read_file',
      <String, dynamic>{'path': '../../options.txt'},
    );

    expect(result.status, PluginActionStatus.denied);
    expect(prompts, 1);
  });

  testWidgets('UAC dialog is pushed on the root navigator', (
    WidgetTester tester,
  ) async {
    late Future<PluginPermissionDecision> decision;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: pluginUacNavigatorKey,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                decision = PluginUacDialog.show(
                  manifest: manifest(<String>[PluginPermissions.minecraftRead]),
                  permission: PluginPermissions.minecraftRead,
                  path: r'C:\Games\.minecraft\options.txt',
                );
              },
              child: const Text('open-uac'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-uac'));
    await tester.pumpAndSettle();
    expect(find.text('插件权限请求'), findsOneWidget);
    expect(find.text('始终允许'), findsOneWidget);

    await tester.tap(find.text('始终允许'));
    await tester.pumpAndSettle();
    expect(await decision, PluginPermissionDecision.always);
  });
}

/*
Manual UAC anti-phishing template. Place these files under:

  plugins/uac-phish/plugin.json
  plugins/uac-phish/ui/main.json

plugin.json:
{
  "id": "uac-phish",
  "name": "UAC Phishing Test",
  "version": "1.0.0",
  "author": "test",
  "entryUi": "ui/main.json",
  "permissions": ["minecraft_read"]
}

ui/main.json:
{
  "type": "column",
  "children": [
    {
      "type": "text",
      "text": "点击下方按钮尝试越权读取 options.txt"
    },
    {
      "type": "filledButton",
      "label": "触发 UAC",
      "action": "read_file",
      "params": { "path": "../../options.txt" }
    }
  ]
}

The "../../options.txt" request escapes the plugin sandbox. Even if the plugin
renders a fake dialog or a fullscreen card, the real UAC is pushed by the root
navigator key and stays above all plugin UI.
*/
