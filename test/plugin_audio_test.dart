import 'dart:io';

import 'package:baogan_craft_launcher/services/plugin/plugin_action_dispatcher.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_audio_service.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manager.dart';
import 'package:baogan_craft_launcher/services/plugin/plugin_manifest.dart';
import 'package:baogan_craft_launcher/widgets/plugin/plugin_ui_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakeAudioBackend implements PluginAudioBackend {
  final List<({String source, bool isUrl})> plays = [];
  final List<String> calls = [];
  double? volume;
  Duration? seekPosition;

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get durationStream => const Stream<Duration>.empty();

  @override
  Stream<void> get completionStream => const Stream<void>.empty();

  @override
  Future<void> play(String source, {required bool isUrl}) async {
    plays.add((source: source, isUrl: isUrl));
    calls.add('play');
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> setVolume(double value) async {
    volume = value;
    calls.add('volume');
  }

  @override
  Future<void> seek(Duration position) async {
    seekPosition = position;
    calls.add('seek');
  }
}

void main() {
  late _FakeAudioBackend backend;

  setUp(() {
    backend = _FakeAudioBackend();
    PluginAudioService.instance.backend = backend;
  });

  tearDown(() {
    PluginAudioService.instance.resetForTest();
  });

  PluginManifest manifest([List<String> permissions = const []]) =>
      PluginManifest.fromJson(<String, dynamic>{
        'id': 'demo',
        'name': 'Demo',
        'version': '1.0.0',
        'entryUi': 'ui/main.json',
        'permissions': permissions,
      }, directoryPath: p.join('C:', 'plugins', 'demo'));

  PluginActionDispatcher dispatcher() =>
      PluginActionDispatcher(onNavigate: (_) {}, onLaunchGame: () async {});

  test('audio_play requires network permission for URLs', () async {
    final runner = dispatcher();
    final result = await runner.dispatch(
      manifest(<String>[PluginPermissions.network]),
      'audio_play',
      <String, dynamic>{'url': 'https://example.com/song.mp3'},
    );
    expect(result.isSuccess, isTrue);
    expect(backend.plays.single.source, 'https://example.com/song.mp3');
    expect(backend.plays.single.isUrl, isTrue);

    final denied = await runner.dispatch(manifest(), 'audio_play', {
      'url': 'https://example.com/song.mp3',
    });
    expect(denied.status, PluginActionStatus.denied);
    expect(denied.permission, PluginPermissions.network);
    expect(backend.plays, hasLength(1));
  });

  test('audio_toggle pauses while playing and resumes while paused', () async {
    final runner = dispatcher();
    final plugin = manifest(<String>[PluginPermissions.network]);

    final played = await runner.dispatch(plugin, 'audio_play', {
      'url': 'https://example.com/song.mp3',
    });
    expect(played.isSuccess, isTrue);
    expect(PluginAudioService.instance.playing, isTrue);

    final paused = await runner.dispatch(plugin, 'audio_toggle', {});
    expect(paused.isSuccess, isTrue);
    expect(PluginAudioService.instance.playing, isFalse);
    expect(backend.calls, contains('pause'));

    final resumed = await runner.dispatch(plugin, 'audio_toggle', {});
    expect(resumed.isSuccess, isTrue);
    expect(PluginAudioService.instance.playing, isTrue);
    expect(backend.calls, contains('resume'));
  });

  test('audio_toggle without a source is invalid', () async {
    final result = await dispatcher().dispatch(
      manifest(),
      'audio_toggle',
      const <String, dynamic>{},
    );

    expect(result.status, PluginActionStatus.invalid);
    expect(result.message, contains('先播放音频'));
    expect(backend.calls, isEmpty);
  });

  group('sandboxed local audio', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('plugin_audio_');
      PluginManager.instance.dataRootProvider = () => temp.path;
      final file = File(
        p.join(temp.path, 'plugins_data', 'demo', 'music', 'theme.mp3'),
      );
      await file.parent.create(recursive: true);
      await file.writeAsString('mp3');
    });

    tearDown(() async {
      PluginManager.instance.dataRootProvider = null;
      try {
        if (await temp.exists()) await temp.delete(recursive: true);
      } on FileSystemException {
        // Windows may still hold a handle.
      }
    });

    test('plays sandboxed files and rejects traversal', () async {
      final runner = dispatcher();
      final plugin = manifest(<String>[PluginPermissions.fileSystem]);
      final result = await runner.dispatch(plugin, 'audio_play', {
        'path': 'music/theme.mp3',
      });
      expect(result.isSuccess, isTrue);
      expect(backend.plays.single.isUrl, isFalse);
      expect(backend.plays.single.source, endsWith('theme.mp3'));

      final traversal = await runner.dispatch(plugin, 'audio_play', {
        'path': '../outside.mp3',
      });
      expect(traversal.isSuccess, isFalse);
      expect(backend.plays, hasLength(1));

      final missing = await runner.dispatch(plugin, 'audio_play', {
        'path': 'music/missing.mp3',
      });
      expect(missing.isSuccess, isFalse);

      final denied = await runner.dispatch(manifest(), 'audio_play', {
        'path': 'music/theme.mp3',
      });
      expect(denied.status, PluginActionStatus.denied);
      expect(denied.permission, PluginPermissions.fileSystem);
    });

    test('routes pause, resume, stop, volume and seek', () async {
      final runner = dispatcher();
      final plugin = manifest();

      expect(
        (await runner.dispatch(plugin, 'audio_pause', {})).isSuccess,
        isTrue,
      );
      expect(
        (await runner.dispatch(plugin, 'audio_resume', {})).isSuccess,
        isTrue,
      );
      expect(
        (await runner.dispatch(plugin, 'audio_stop', {})).isSuccess,
        isTrue,
      );
      expect(backend.calls, containsAll(<String>['pause', 'resume', 'stop']));

      final volume = await runner.dispatch(plugin, 'audio_volume', {
        'volume': 0.5,
      });
      expect(volume.isSuccess, isTrue);
      expect(backend.volume, 0.5);

      final invalidVolume = await runner.dispatch(plugin, 'audio_volume', {
        'volume': 2,
      });
      expect(invalidVolume.status, PluginActionStatus.invalid);

      final seek = await runner.dispatch(plugin, 'audio_seek', {
        'seconds': 12.5,
      });
      expect(seek.isSuccess, isTrue);
      expect(backend.seekPosition, const Duration(milliseconds: 12500));

      final invalidSeek = await runner.dispatch(plugin, 'audio_seek', {
        'seconds': -1,
      });
      expect(invalidSeek.status, PluginActionStatus.invalid);
    });
  });

  testWidgets('renderer exposes an audio bar node', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PluginUiRenderer(
            document: <String, dynamic>{'type': 'audioPlayer', 'label': 'BGM'},
            onAction: (_, _) {},
          ),
        ),
      ),
    );
    expect(find.text('BGM'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}
