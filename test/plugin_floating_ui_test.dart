import 'dart:convert';
import 'dart:io';

import 'package:baogan_craft_launcher/l10n/app_localizations.dart';
import 'package:baogan_craft_launcher/pages/launcher/controllers/launcher_shell_controller.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manager.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manifest.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_overlay_manager.dart';
import 'package:baogan_craft_launcher/widgets/plugin/plugin_floating_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('parses floatingUi with position and whitelist visibility', () {
    final manifest = PluginManifest.fromJson(<String, dynamic>{
      'id': 'floating.demo',
      'name': 'Floating Demo',
      'version': '1.0.0',
      'entryUi': 'ui/main.json',
      'floatingUi': <String, dynamic>{
        'entry': 'floating.json',
        'position': 'bottomRight',
        'visibility': <String, dynamic>{
          'mode': 'whitelist',
          'pages': <String>['home', 'downloads'],
        },
      },
    }, directoryPath: 'x');

    final config = manifest.floatingUi!;
    expect(config.entry, 'floating.json');
    expect(config.position, PluginFloatingPosition.bottomRight);
    expect(config.mode, PluginFloatingVisibilityMode.whitelist);
    expect(config.isVisibleOn('home'), isTrue);
    expect(config.isVisibleOn('downloads'), isTrue);
    expect(config.isVisibleOn('settings'), isFalse);
  });

  test('defaults to bottomRight/all and rejects unsafe config', () {
    final manifest = PluginManifest.fromJson(<String, dynamic>{
      'id': 'floating.default',
      'name': 'Floating Default',
      'version': '1.0.0',
      'entryUi': 'ui/main.json',
      'floatingUi': <String, dynamic>{'entry': 'floating.json'},
    }, directoryPath: 'x');
    expect(manifest.floatingUi!.position, PluginFloatingPosition.bottomRight);
    expect(manifest.floatingUi!.mode, PluginFloatingVisibilityMode.all);
    expect(manifest.floatingUi!.isVisibleOn('settings'), isTrue);

    Map<String, dynamic> base() => <String, dynamic>{
      'id': 'floating.bad',
      'name': 'Bad',
      'version': '1.0.0',
      'entryUi': 'ui/main.json',
      'floatingUi': <String, dynamic>{
        'entry': '../floating.json',
        'position': 'middle',
        'visibility': <String, dynamic>{
          'mode': 'whitelist',
          'pages': <String>['home'],
        },
      },
    };
    expect(
      () => PluginManifest.fromJson(base(), directoryPath: 'x'),
      throwsA(isA<FormatException>()),
    );

    final badPage = base();
    (badPage['floatingUi'] as Map<String, dynamic>)['entry'] = 'floating.json';
    (badPage['floatingUi'] as Map<String, dynamic>)['position'] = 'bottomRight';
    (badPage['floatingUi']
        as Map<String, dynamic>)['visibility'] = <String, dynamic>{
      'mode': 'whitelist',
      'pages': <String>['unknown_page'],
    };
    expect(
      () => PluginManifest.fromJson(badPage, directoryPath: 'x'),
      throwsA(isA<FormatException>()),
    );
  });

  group('floating overlay', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('plugin_floating_');
      PluginManager.instance.dataRootProvider = () => temp.path;
      final root = Directory(p.join(temp.path, 'plugins', 'floating_demo'));
      await root.create(recursive: true);
      await File(p.join(root.path, 'plugin.json')).writeAsString(
        jsonEncode(<String, dynamic>{
          'id': 'floating_demo',
          'name': 'Floating Demo',
          'version': '1.0.0',
          'entryUi': 'ui/main.json',
          'floatingUi': <String, dynamic>{
            'entry': 'floating.json',
            'position': 'bottomRight',
            'visibility': <String, dynamic>{
              'mode': 'whitelist',
              'pages': <String>['home'],
            },
          },
        }),
      );
      await File(p.join(root.path, 'floating.json')).writeAsString(
        jsonEncode(<String, dynamic>{
          'type': 'column',
          'spacing': 8,
          'children': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'text',
              'text': '浮窗你好',
              'fontWeight': 'bold',
            },
            <String, dynamic>{
              'type': 'filledButton',
              'label': '打招呼',
              'action': 'show_snackbar',
              'params': <String, dynamic>{'message': '你好！'},
            },
          ],
        }),
      );
      await PluginManager.instance.reload();
      PluginOverlayManager.instance.updateTab(LauncherTab.home);
    });

    tearDown(() async {
      PluginOverlayManager.instance.updateTab(LauncherTab.home);
      PluginManager.instance.dataRootProvider = null;
      try {
        if (await temp.exists()) await temp.delete(recursive: true);
      } on FileSystemException {
        // Windows may still hold a handle.
      }
    });

    test('loads floating documents and filters by the active tab', () {
      expect(PluginManager.instance.floatingUis, hasLength(1));
      final ui = PluginManager.instance.floatingUis.single;
      expect(ui.manifest.id, 'floating_demo');
      expect(ui.config.position, PluginFloatingPosition.bottomRight);

      expect(PluginOverlayManager.instance.visible, hasLength(1));
      PluginOverlayManager.instance.updateTab(LauncherTab.downloads);
      expect(PluginOverlayManager.instance.visible, isEmpty);
      PluginOverlayManager.instance.updateTab(LauncherTab.versions);
      expect(PluginOverlayManager.instance.visible, isEmpty);
      PluginOverlayManager.instance.updateTab(LauncherTab.home);
      expect(PluginOverlayManager.instance.visible, hasLength(1));
    });

    testWidgets('renders on whitelisted pages and hides elsewhere', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AnimatedBuilder(
              animation: PluginOverlayManager.instance,
              builder: (context, _) => Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: PluginFloatingLayer(
                      items: PluginOverlayManager.instance.visible,
                      onNavigate: (_) {},
                      onLaunchGame: () async {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('浮窗你好'), findsOneWidget);

      await tester.tap(find.text('打招呼'));
      await tester.pump();
      expect(find.text('你好！'), findsOneWidget);

      PluginOverlayManager.instance.updateTab(LauncherTab.downloads);
      await tester.pumpAndSettle();
      expect(find.text('浮窗你好'), findsNothing);
    });
  });
}
