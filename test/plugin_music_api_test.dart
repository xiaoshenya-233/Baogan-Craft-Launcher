import 'dart:async';
import 'dart:io';

import 'package:baogan_craft_launcher/services/plugin/plugin_action_dispatcher.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_audio_service.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_audio_task_bridge.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manager.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manifest.dart';
import 'package:baogan_craft_launcher/services/task/launcher_task.dart';
import 'package:baogan_craft_launcher/services/task/task_activity_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _StreamingAudioBackend implements PluginAudioBackend {
  final StreamController<Duration> position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> duration =
      StreamController<Duration>.broadcast();
  final StreamController<bool> playing = StreamController<bool>.broadcast();

  @override
  Stream<Duration> get positionStream => position.stream;

  @override
  Stream<Duration> get durationStream => duration.stream;

  @override
  Stream<bool> get playingStream => playing.stream;

  @override
  Stream<void> get completionStream => const Stream<void>.empty();

  @override
  Future<void> play(String source, {required bool isUrl}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> seek(Duration position) async {}

  Future<void> close() async {
    await position.close();
    await duration.close();
    await playing.close();
  }
}

void main() {
  late Directory temp;
  late _StreamingAudioBackend backend;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('plugin_music_');
    PluginManager.instance.dataRootProvider = () => temp.path;
    TaskActivityController.instance.reset();
    backend = _StreamingAudioBackend();
    PluginAudioService.instance.backend = backend;
  });

  tearDown(() async {
    PluginAudioTaskBridge.instance.reset();
    PluginAudioService.instance.resetForTest();
    TaskActivityController.instance.reset();
    PluginManager.instance.dataRootProvider = null;
    await backend.close();
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
      }, directoryPath: p.join(temp.path, 'plugins', 'demo'));

  PluginActionDispatcher dispatcher() =>
      PluginActionDispatcher(onNavigate: (_) {}, onLaunchGame: () async {});

  test('lists files inside the plugin folder only', () async {
    final root = Directory(p.join(temp.path, 'plugins', 'demo', 'Music'));
    await root.create(recursive: true);
    await File(p.join(root.path, 'a.mp3')).writeAsString('a');
    await File(p.join(root.path, 'b.flac')).writeAsString('b');
    await Directory(p.join(root.path, 'nested')).create();

    final result = await dispatcher().dispatch(
      manifest(<String>[PluginPermissions.fileSystem]),
      'list_plugin_files',
      <String, dynamic>{'folder': 'Music'},
    );
    expect(result.isSuccess, isTrue);
    expect(result.data, <String>['a.mp3', 'b.flac']);

    final missing = await dispatcher().dispatch(
      manifest(<String>[PluginPermissions.fileSystem]),
      'list_plugin_files',
      <String, dynamic>{'folder': 'Missing'},
    );
    expect(missing.isSuccess, isTrue);
    expect(missing.data, isEmpty);

    final traversal = await dispatcher().dispatch(
      manifest(<String>[PluginPermissions.fileSystem]),
      'list_plugin_files',
      <String, dynamic>{'folder': '../'},
    );
    expect(traversal.isSuccess, isFalse);

    final denied = await dispatcher().dispatch(
      manifest(),
      'list_plugin_files',
      <String, dynamic>{'folder': 'Music'},
    );
    expect(denied.status, PluginActionStatus.denied);
  });

  test('audio_play publishes title and capsule actions', () async {
    final result = await dispatcher().dispatch(
      manifest(<String>[PluginPermissions.network]),
      'audio_play',
      <String, dynamic>{
        'url': 'https://example.com/song.mp3',
        'title': 'Night Drive',
        'artist': 'Cline',
        'capsule_actions': <Map<String, dynamic>>[
          <String, dynamic>{
            'icon': 'stop',
            'tooltip': '停止播放',
            'action': 'audio_stop',
          },
        ],
      },
    );
    expect(result.isSuccess, isTrue);

    final task = TaskActivityController.instance.taskById(
      PluginAudioTaskBridge.taskId,
    );
    expect(task, isNotNull);
    expect(task!.title, '正在播放: Night Drive - Cline');
    expect(task.actions, hasLength(1));
    expect(task.actions.single.tooltip, '停止播放');

    backend.duration.add(const Duration(seconds: 100));
    await Future<void>.delayed(Duration.zero);
    backend.position.add(const Duration(seconds: 25));
    await Future<void>.delayed(Duration.zero);
    expect(
      TaskActivityController.instance
          .taskById(PluginAudioTaskBridge.taskId)!
          .progress,
      closeTo(0.25, 0.001),
    );

    task.actions.single.onPressed();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      TaskActivityController.instance.taskById(PluginAudioTaskBridge.taskId),
      isNull,
    );
  });

  test('audio capsule keeps only audio actions', () async {
    await PluginAudioService.instance.play('https://example.com/song.mp3');
    PluginAudioTaskBridge.instance.start(
      title: 'Song',
      actions: <LauncherTaskAction>[
        LauncherTaskAction(
          icon: 'skip_previous',
          tooltip: '上一首',
          action: 'audio_prev',
          onPressed: () {},
        ),
        LauncherTaskAction(
          icon: 'download_rounded',
          tooltip: '伪装下载',
          action: 'audio_next',
          onPressed: () {},
        ),
        LauncherTaskAction(
          icon: 'pause',
          tooltip: '播放/暂停',
          action: 'audio_toggle',
          onPressed: () {},
        ),
        LauncherTaskAction(
          icon: 'skip_next',
          tooltip: '下一首',
          action: 'audio_next',
          onPressed: () {},
        ),
        LauncherTaskAction(
          icon: 'stop',
          tooltip: '停止',
          action: 'audio_stop',
          onPressed: () {},
        ),
        LauncherTaskAction(
          icon: 'download',
          tooltip: '下载',
          action: 'download_file',
          onPressed: () {},
        ),
        LauncherTaskAction(
          icon: 'rocket_launch',
          tooltip: '导航',
          action: 'navigate_to',
          onPressed: () {},
        ),
      ],
    );

    final task = TaskActivityController.instance.taskById(
      PluginAudioTaskBridge.taskId,
    );
    expect(task, isNotNull);
    expect(task!.actions.map((action) => action.action).toList(), <String>[
      'audio_prev',
      'audio_toggle',
      'audio_next',
      'audio_stop',
    ]);
    expect(
      task.actions.any((action) => action.icon.contains('download')),
      isFalse,
    );
    expect(
      task.actions.any((action) => action.action.contains('download')),
      isFalse,
    );
  });
}
