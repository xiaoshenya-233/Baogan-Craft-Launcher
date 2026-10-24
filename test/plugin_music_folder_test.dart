import 'dart:async';
import 'dart:io';

import 'package:baogan_craft_launcher/services/plugin/plugin_action_dispatcher.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_audio_service.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_audio_task_bridge.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manager.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manifest.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_music_library.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_music_playlist_service.dart';
import 'package:baogan_craft_launcher/services/task/task_activity_controller.dart';
import 'package:baogan_craft_launcher/widgets/plugin/plugin_ui_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakeAudioBackend implements PluginAudioBackend {
  final List<String> plays = [];
  final StreamController<void> completions = StreamController<void>.broadcast();

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get durationStream => const Stream<Duration>.empty();

  @override
  Stream<void> get completionStream => completions.stream;

  @override
  Future<void> play(String source, {required bool isUrl}) async {
    plays.add(source);
  }

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
}

void main() {
  late Directory temp;
  late String pluginDirectory;
  late _FakeAudioBackend backend;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('plugin_music_folder_');
    PluginManager.instance.dataRootProvider = () => temp.path;
    pluginDirectory = p.join(temp.path, 'plugins', 'demo');
    final music = Directory(p.join(pluginDirectory, 'Music'));
    await music.create(recursive: true);
    await File(p.join(music.path, '周杰伦 - 稻香.mp3')).writeAsString('a');
    await File(p.join(music.path, 'Artist – Song.flac')).writeAsString('b');
    await File(p.join(music.path, 'plain.wav')).writeAsString('c');
    await File(p.join(music.path, 'cover.txt')).writeAsString('d');
    await Directory(p.join(music.path, 'nested')).create();
    await File(p.join(music.path, 'nested', 'hidden.mp3')).writeAsString('e');
    TaskActivityController.instance.reset();
    backend = _FakeAudioBackend();
    PluginAudioService.instance.backend = backend;
  });

  tearDown(() async {
    PluginMusicPlaylistService.instance.reset();
    PluginAudioTaskBridge.instance.reset();
    PluginAudioService.instance.resetForTest();
    TaskActivityController.instance.reset();
    PluginManager.instance.dataRootProvider = null;
    await backend.completions.close();
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

  PluginActionDispatcher dispatcher() =>
      PluginActionDispatcher(onNavigate: (_) {}, onLaunchGame: () async {});

  test('parses artist - title and skips non-audio files', () async {
    final tracks = await PluginMusicLibrary.scanDirectory(
      pluginDirectory,
      'Music',
    );
    expect(tracks, hasLength(3));
    final daoXiang = tracks.firstWhere((track) => track.title == '稻香');
    expect(daoXiang.artist, '周杰伦');
    expect(daoXiang.relativePath, 'Music/周杰伦 - 稻香.mp3');
    final song = tracks.firstWhere((track) => track.fileName.contains('Song'));
    expect(song.artist, 'Artist');
    expect(song.title, 'Song');
    final plain = tracks.firstWhere((track) => track.fileName == 'plain.wav');
    expect(plain.title, 'plain');
    expect(plain.artist, isEmpty);
  });

  test('play_music_folder uses only plugin-provided capsule actions', () async {
    final result = await dispatcher().dispatch(
      manifest(<String>[PluginPermissions.fileSystem]),
      'play_music_folder',
      <String, dynamic>{
        'folder': 'Music',
        'capsule_actions': <Map<String, dynamic>>[
          <String, dynamic>{
            'icon': 'previous',
            'tooltip': '上一首',
            'action': 'audio_prev',
          },
          <String, dynamic>{
            'icon': 'next',
            'tooltip': '下一首',
            'action': 'audio_next',
          },
          <String, dynamic>{
            'icon': 'stop',
            'tooltip': '停止播放',
            'action': 'audio_stop',
          },
        ],
      },
    );
    expect(result.isSuccess, isTrue);
    expect(result.data, hasLength(3));
    expect(backend.plays, hasLength(1));

    final tracks = PluginMusicPlaylistService.instance.tracks;
    final task = TaskActivityController.instance.taskById(
      PluginAudioTaskBridge.taskId,
    );
    expect(task, isNotNull);
    expect(task!.title, tracks.first.displayTitle);
    expect(task.actions.map((action) => action.icon).toList(), <String>[
      'previous',
      'next',
      'stop',
    ]);

    task.actions.firstWhere((action) => action.icon == 'next').onPressed();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(backend.plays, hasLength(2));
    expect(backend.plays.last, endsWith(tracks[1].fileName));
    expect(
      TaskActivityController.instance
          .taskById(PluginAudioTaskBridge.taskId)!
          .title,
      tracks[1].displayTitle,
    );

    TaskActivityController.instance
        .taskById(PluginAudioTaskBridge.taskId)!
        .actions
        .firstWhere((action) => action.icon == 'previous')
        .onPressed();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(backend.plays.last, endsWith(tracks[0].fileName));

    TaskActivityController.instance
        .taskById(PluginAudioTaskBridge.taskId)!
        .actions
        .firstWhere((action) => action.icon == 'stop')
        .onPressed();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      TaskActivityController.instance.taskById(PluginAudioTaskBridge.taskId),
      isNull,
    );
  });

  test(
    'playlist without capsule_actions shows no buttons and stops cleanly',
    () async {
      final runner = dispatcher();
      final result = await runner.dispatch(
        manifest(<String>[PluginPermissions.fileSystem]),
        'play_music_folder',
        <String, dynamic>{'folder': 'Music'},
      );
      expect(result.isSuccess, isTrue);

      final task = TaskActivityController.instance.taskById(
        PluginAudioTaskBridge.taskId,
      );
      expect(task, isNotNull);
      expect(task!.actions, isEmpty);

      final stopped = await runner.dispatch(
        manifest(<String>[PluginPermissions.fileSystem]),
        'audio_stop',
        const <String, dynamic>{},
      );
      expect(stopped.isSuccess, isTrue);
      expect(
        TaskActivityController.instance.taskById(PluginAudioTaskBridge.taskId),
        isNull,
      );
      expect(PluginAudioService.instance.hasSource, isFalse);
    },
  );

  test('audio capsule never exposes injected download actions', () async {
    final result = await dispatcher().dispatch(
      manifest(<String>[PluginPermissions.fileSystem]),
      'play_music_folder',
      <String, dynamic>{
        'folder': 'Music',
        'capsule_actions': <Map<String, dynamic>>[
          <String, dynamic>{
            'icon': 'skip_previous',
            'tooltip': '上一首',
            'action': 'audio_prev',
          },
          <String, dynamic>{
            'icon': 'download_rounded',
            'tooltip': '伪装成下载',
            'action': 'audio_next',
          },
          <String, dynamic>{
            'icon': 'pause',
            'tooltip': '播放/暂停',
            'action': 'audio_toggle',
          },
          <String, dynamic>{
            'icon': 'skip_next',
            'tooltip': '下一首',
            'action': 'audio_next',
          },
          <String, dynamic>{
            'icon': 'stop',
            'tooltip': '停止',
            'action': 'audio_stop',
          },
          <String, dynamic>{
            'icon': 'download',
            'tooltip': '下载',
            'action': 'download_file',
          },
          <String, dynamic>{
            'icon': 'rocket_launch',
            'tooltip': '导航',
            'action': 'navigate_to',
          },
        ],
      },
    );
    expect(result.isSuccess, isTrue);

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
      task.actions.map((action) => action.icon),
      isNot(contains('download')),
    );
    expect(
      task.actions.any((action) => action.icon.contains('download')),
      isFalse,
    );
  });

  test('playlist advances automatically when a track completes', () async {
    final result = await dispatcher().dispatch(
      manifest(<String>[PluginPermissions.fileSystem]),
      'play_music_folder',
      <String, dynamic>{'folder': 'Music'},
    );
    expect(result.isSuccess, isTrue);
    final tracks = PluginMusicPlaylistService.instance.tracks;
    expect(backend.plays, hasLength(1));

    backend.completions.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(backend.plays, hasLength(2));
    expect(backend.plays.last, endsWith(tracks[1].fileName));
    expect(
      TaskActivityController.instance
          .taskById(PluginAudioTaskBridge.taskId)!
          .title,
      tracks[1].displayTitle,
    );
  });

  test('play_music_folder is sandboxed and permission gated', () async {
    final runner = dispatcher();
    final traversal = await runner.dispatch(
      manifest(<String>[PluginPermissions.fileSystem]),
      'play_music_folder',
      <String, dynamic>{'folder': '../Music'},
    );
    expect(traversal.isSuccess, isFalse);
    expect(backend.plays, isEmpty);

    final denied = await runner.dispatch(manifest(), 'play_music_folder', {
      'folder': 'Music',
    });
    expect(denied.status, PluginActionStatus.denied);

    final missing = await runner.dispatch(
      manifest(<String>[PluginPermissions.fileSystem]),
      'play_music_folder',
      <String, dynamic>{'folder': 'Missing'},
    );
    expect(missing.isSuccess, isTrue);
    expect(missing.data, isEmpty);
    expect(backend.plays, isEmpty);
  });

  testWidgets('musicPlaylist node renders songs and emits audio_play', (
    WidgetTester tester,
  ) async {
    String? action;
    Map<String, dynamic>? params;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PluginUiRenderer(
            document: <String, dynamic>{
              'type': 'musicPlaylist',
              'folder': 'Music',
              'capsule_actions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'icon': 'skip_previous',
                  'tooltip': '上一首',
                  'action': 'audio_prev',
                },
                <String, dynamic>{
                  'icon': 'pause',
                  'tooltip': '播放/暂停',
                  'action': 'audio_toggle',
                },
                <String, dynamic>{
                  'icon': 'skip_next',
                  'tooltip': '下一首',
                  'action': 'audio_next',
                },
                <String, dynamic>{
                  'icon': 'stop',
                  'tooltip': '停止',
                  'action': 'audio_stop',
                },
              ],
            },
            baseDirectory: pluginDirectory,
            grantedPermissions: const <String>{'file_system'},
            onAction: (value, payload) {
              action = value;
              params = payload;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    for (var attempt = 0; attempt < 10; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (find.text('稻香').evaluate().isNotEmpty) break;
    }

    expect(find.text('稻香'), findsOneWidget);
    expect(find.text('周杰伦'), findsOneWidget);
    expect(find.text('Song'), findsOneWidget);

    final tile = find.ancestor(
      of: find.text('稻香'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: tile, matching: find.byType(IconButton)),
    );
    expect(action, 'audio_play');
    expect(params?['title'], '稻香');
    expect(params?['artist'], '周杰伦');
    expect(params?['path'], 'Music/周杰伦 - 稻香.mp3');
    final forwarded = params?['capsule_actions'];
    expect(forwarded, isA<List<dynamic>>());
    expect(
      (forwarded! as List<dynamic>)
          .map((item) => (item as Map<String, dynamic>)['action'])
          .toList(),
      <String>['audio_prev', 'audio_toggle', 'audio_next', 'audio_stop'],
    );

    final played = await tester.runAsync(
      () => dispatcher().dispatch(
        manifest(<String>[PluginPermissions.fileSystem]),
        action!,
        params!,
      ),
    );
    expect(played, isNotNull);
    expect(played!.isSuccess, isTrue);
    final task = TaskActivityController.instance.taskById(
      PluginAudioTaskBridge.taskId,
    );
    expect(task, isNotNull);
    expect(task!.actions, hasLength(4));
  });
}
