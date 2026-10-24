import 'package:baogan_craft_launcher/services/plugin/plugin_action_dispatcher.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manifest.dart';
import 'package:baogan_craft_launcher/services/task/launcher_task.dart';
import 'package:baogan_craft_launcher/services/task/task_activity_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => TaskActivityController.instance.reset());
  tearDown(() => TaskActivityController.instance.reset());

  PluginManifest manifest() => PluginManifest.fromJson(<String, dynamic>{
    'id': 'demo',
    'name': 'Demo',
    'version': '1.0.0',
    'entryUi': 'ui/main.json',
  }, directoryPath: 'x');

  PluginActionDispatcher dispatcher({void Function(String)? onMessage}) =>
      PluginActionDispatcher(
        onNavigate: (_) {},
        onLaunchGame: () async {},
        onMessage: onMessage,
      );

  test('registers namespaced plugin tasks with capsule actions', () async {
    String? message;
    final runner = dispatcher(onMessage: (value) => message = value);

    final registered = await runner.dispatch(manifest(), 'task_register', {
      'id': 'sync',
      'title': '正在同步',
      'icon': 'download',
      'progress': 0.25,
      'actions': <Map<String, dynamic>>[
        <String, dynamic>{
          'icon': 'stop',
          'tooltip': '停止同步',
          'action': 'show_snackbar',
          'params': <String, dynamic>{'message': '同步已停止'},
        },
      ],
    });
    expect(registered.isSuccess, isTrue);

    final task = TaskActivityController.instance.taskById('plugin_demo_sync');
    expect(task, isNotNull);
    expect(task!.title, '正在同步');
    expect(task.progress, 0.25);
    expect(task.actions, hasLength(1));
    expect(task.actions.single.tooltip, '停止同步');

    task.actions.single.onPressed();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(message, '同步已停止');

    final updated = await runner.dispatch(manifest(), 'task_update', {
      'id': 'sync',
      'progress': 0.75,
      'subText': '75%',
    });
    expect(updated.isSuccess, isTrue);
    final afterUpdate = TaskActivityController.instance.taskById(
      'plugin_demo_sync',
    );
    expect(afterUpdate!.progress, 0.75);
    expect(afterUpdate.subText, '75%');
    expect(afterUpdate.actions, hasLength(1));

    final removed = await runner.dispatch(manifest(), 'task_remove', {
      'id': 'sync',
    });
    expect(removed.isSuccess, isTrue);
    expect(
      TaskActivityController.instance.taskById('plugin_demo_sync'),
      isNull,
    );
  });

  test(
    'capsule action icons are canonicalised and invalid names fall back',
    () async {
      final runner = dispatcher();
      final registered = await runner.dispatch(manifest(), 'task_register', {
        'id': 'icons',
        'title': '图标测试',
        'actions': <Map<String, dynamic>>[
          <String, dynamic>{
            'icon': 'rocketLaunch',
            'tooltip': '有效图标',
            'action': 'show_snackbar',
          },
          <String, dynamic>{
            'icon': 'fontawesome:github',
            'tooltip': '无效图标',
            'action': 'show_snackbar',
          },
        ],
      });
      expect(registered.isSuccess, isTrue);

      final task = TaskActivityController.instance.taskById(
        'plugin_demo_icons',
      );
      expect(task, isNotNull);
      expect(task!.actions.map((action) => action.icon).toList(), <String>[
        'rocket_launch',
        'extension',
      ]);
    },
  );

  test('plugin ids never overwrite launcher tasks', () async {
    TaskActivityController.instance.addTask(
      const LauncherTask(
        id: 'downloads',
        title: '启动器下载',
        icon: Icons.download_rounded,
      ),
    );
    final runner = dispatcher();
    final result = await runner.dispatch(manifest(), 'task_register', {
      'id': 'downloads',
      'title': '插件下载',
    });
    expect(result.isSuccess, isTrue);
    expect(
      TaskActivityController.instance.taskById('downloads')!.title,
      '启动器下载',
    );
    expect(
      TaskActivityController.instance.taskById('plugin_demo_downloads'),
      isNotNull,
    );

    final invalid = await runner.dispatch(manifest(), 'task_register', {
      'id': '../escape',
      'title': '坏任务',
    });
    expect(invalid.status, PluginActionStatus.invalid);
  });
}
