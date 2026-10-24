import 'package:baogan_craft_launcher/services/plugin/plugin_icon_mapper.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manifest.dart';
import 'package:baogan_craft_launcher/services/task/launcher_task.dart';
import 'package:baogan_craft_launcher/widgets/plugin/plugin_ui_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes a broad Material icon dictionary', () {
    expect(PluginIconMapper.iconCount, greaterThanOrEqualTo(300));
    expect(PluginIconMapper.iconCount, lessThanOrEqualTo(500));

    const required = <String>[
      'extension',
      'rocket_launch',
      'settings_suggest',
      'folder_open',
      'save',
      'edit',
      'delete',
      'search',
      'info',
      'warning',
      'home',
      'dashboard',
      'play_arrow',
      'pause',
      'stop',
      'skip_next',
      'skip_previous',
      'music_note',
      'photo_library',
      'videocam',
      'terminal',
      'wifi',
      'battery_full',
      'shopping_cart',
      'sports_esports',
    ];
    for (final name in required) {
      expect(
        PluginIconMapper.icons.containsKey(name),
        isTrue,
        reason: '缺少图标 $name',
      );
    }
  });

  test('normalizes snake_case, camelCase, Icons and material prefixes', () {
    expect(PluginIconMapper.normalize('rocketLaunch'), 'rocket_launch');
    expect(PluginIconMapper.normalize('Icons.rocketLaunch'), 'rocket_launch');
    expect(PluginIconMapper.normalize('rocket launch'), 'rocket_launch');
    expect(PluginIconMapper.normalize(' Rocket-Launch '), 'rocket_launch');
    expect(PluginIconMapper.normalize('material:home'), 'home');
    expect(
      PluginIconMapper.normalize('material:rocketLaunch'),
      'rocket_launch',
    );
    expect(PluginIconMapper.normalize('fontawesome:github'), isEmpty);

    expect(PluginIconMapper.getIcon('rocketLaunch'), Icons.rocket_launch);
    expect(PluginIconMapper.getIcon('rocket_launch'), Icons.rocket_launch);
    expect(PluginIconMapper.getIcon('Icons.folderOpen'), Icons.folder_open);
    expect(PluginIconMapper.getIcon('material:home'), Icons.home);
    expect(PluginIconMapper.getIcon('fontawesome:github'), Icons.extension);
  });

  test('unknown icons fall back to extension', () {
    expect(
      PluginIconMapper.getIcon('definitely_not_a_material_icon'),
      Icons.extension,
    );
  });

  test('invalid icon names emit the standard warning', () {
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = original);

    expect(PluginIconMapper.getIcon('fontawesome:github'), Icons.extension);
    expect(
      messages,
      contains(
        "[Plugins] 非法或不支持的图标名称：'fontawesome:github'，"
        "请使用全小写蛇形命名（如 'home', 'settings'）。",
      ),
    );
  });

  test('manifest icon is canonicalised and invalid names fall back', () {
    PluginManifest parse(Object? icon) =>
        PluginManifest.fromJson(<String, dynamic>{
          'id': 'demo',
          'name': 'Demo',
          'version': '1.0.0',
          'entryUi': 'ui/main.json',
          'icon': icon,
        }, directoryPath: 'plugins/demo');

    expect(parse('rocketLaunch').icon, 'rocket_launch');
    expect(parse('Icons.home').icon, 'home');
    expect(parse('material:folder_open').icon, 'folder_open');
    expect(parse('fontawesome:github').icon, isNull);
    expect(parse(null).icon, isNull);
  });

  test('launcher task aliases keep working through the mapper', () {
    expect(launcherTaskIcon('previous'), Icons.skip_previous_rounded);
    expect(launcherTaskIcon('next'), Icons.skip_next_rounded);
    expect(launcherTaskIcon('play'), Icons.play_arrow_rounded);
    expect(launcherTaskIcon('music'), Icons.music_note_rounded);
    expect(launcherTaskIcon('java'), Icons.coffee);
    expect(launcherTaskIcon(null), Icons.widgets_rounded);
    expect(launcherTaskIcon('  '), Icons.widgets_rounded);
    expect(launcherTaskIcon('unknown_task_icon'), Icons.extension);
  });

  testWidgets('renderer resolves camelCase plugin icons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PluginUiRenderer(
            document: <String, dynamic>{
              'type': 'filledButton',
              'label': 'Launch',
              'icon': 'rocketLaunch',
              'action': 'launch',
            },
            onAction: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.rocket_launch), findsOneWidget);
  });

  testWidgets('renderer falls back for an invalid plugin icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PluginUiRenderer(
            document: <String, dynamic>{
              'type': 'filledButton',
              'label': 'Broken',
              'icon': 'not_a_real_icon',
              'action': 'none',
            },
            onAction: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.extension), findsOneWidget);
  });
}
