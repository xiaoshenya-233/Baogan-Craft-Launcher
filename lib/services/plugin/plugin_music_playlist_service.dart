import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/launcher_log.dart';
import '../task/launcher_task.dart';
import 'plugin_audio_service.dart';
import 'plugin_audio_task_bridge.dart';
import 'plugin_manifest.dart';
import 'plugin_music_library.dart';

/// Sequential playlist playback for `play_music_folder`.
///
/// The service is UI-agnostic: it never invents capsule buttons. Only actions
/// parsed from the plugin's JSON `capsule_actions` are forwarded to the task
/// bridge, and natural track completion advances to the next song.
class PluginMusicPlaylistService {
  PluginMusicPlaylistService._();

  static final PluginMusicPlaylistService instance =
      PluginMusicPlaylistService._();

  List<PluginMusicTrack> _tracks = const <PluginMusicTrack>[];
  List<LauncherTaskAction> _actions = const <LauncherTaskAction>[];
  StreamSubscription<void>? _completionSub;
  int _index = 0;
  bool _active = false;

  List<PluginMusicTrack> get tracks =>
      List<PluginMusicTrack>.unmodifiable(_tracks);
  PluginMusicTrack? get current =>
      _tracks.isEmpty ? null : _tracks[_index % _tracks.length];
  bool get isActive => _active;

  Future<List<PluginMusicTrack>> start(
    PluginManifest manifest,
    String folder, {
    List<LauncherTaskAction> actions = const <LauncherTaskAction>[],
  }) async {
    final tracks = await PluginMusicLibrary.scanDirectory(
      manifest.directoryPath,
      folder,
    );
    _tracks = tracks;
    _actions = actions;
    _index = 0;
    _active = tracks.isNotEmpty;
    _ensureCompletionListener();
    if (tracks.isEmpty) return tracks;
    await _playCurrent();
    return tracks;
  }

  /// Stops auto-advance when another plugin starts a single audio source.
  void deactivate() {
    _active = false;
  }

  Future<bool> next() => _move(1);

  Future<bool> previous() => _move(-1);

  Future<bool> _move(int delta) async {
    if (_tracks.isEmpty) return false;
    _index = (_index + delta) % _tracks.length;
    await _playCurrent();
    return true;
  }

  void _ensureCompletionListener() {
    _completionSub ??= PluginAudioService.instance.completions.listen((_) {
      if (!_active ||
          _tracks.isEmpty ||
          !PluginAudioService.instance.hasSource) {
        return;
      }
      unawaited(() async {
        try {
          await next();
        } on Object catch (error) {
          LauncherLog.warning('Plugins', '播放列表自动下一首失败：$error');
        }
      }());
    });
  }

  Future<void> _playCurrent() async {
    final track = _tracks[_index];
    await PluginAudioService.instance.play(track.absolutePath);
    PluginAudioTaskBridge.instance.start(
      title: track.displayTitle,
      actions: _actions,
    );
  }

  Future<void> stop() async {
    _active = false;
    _tracks = const <PluginMusicTrack>[];
    _index = 0;
    await PluginAudioService.instance.stop();
  }

  @visibleForTesting
  void reset() {
    _active = false;
    _tracks = const <PluginMusicTrack>[];
    _index = 0;
    _actions = const <LauncherTaskAction>[];
    unawaited(_completionSub?.cancel());
    _completionSub = null;
  }
}
