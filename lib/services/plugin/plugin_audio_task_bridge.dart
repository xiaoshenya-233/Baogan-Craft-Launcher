import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show Icons;

import '../task/launcher_task.dart';
import '../task/task_activity_controller.dart';
import 'plugin_audio_service.dart';

/// Mirrors [PluginAudioService] playback into the global task capsule.
///
/// The bridge never parses file names: title/artist come from plugin JSON and
/// are passed through verbatim. Actions are rebuilt on every `audio_play`.
class PluginAudioTaskBridge {
  PluginAudioTaskBridge._();

  static final PluginAudioTaskBridge instance = PluginAudioTaskBridge._();

  static const String taskId = 'plugin-audio';

  bool _listening = false;

  /// Actions the audio capsule may render.
  ///
  /// This is a whitelist: navigation, download and other plugin actions are
  /// dropped so playback can never show a download button (or any other
  /// unrelated action injected through `capsule_actions`).
  static const Set<String> audioActions = <String>{
    'audio_prev',
    'audio_toggle',
    'audio_next',
    'audio_stop',
    'audio_play',
    'audio_pause',
    'audio_resume',
    'audio_volume',
    'audio_seek',
  };

  static bool _isDownloadRelated(LauncherTaskAction action) {
    final name = action.action.toLowerCase();
    final icon = action.icon.toLowerCase();
    return name.contains('download') || icon.contains('download');
  }

  /// Keeps only audio actions, drops download-related entries and removes
  /// duplicate action names (e.g. two "next" buttons from a plugin payload).
  List<LauncherTaskAction> _sanitizeActions(List<LauncherTaskAction> actions) {
    final seen = <String>{};
    final kept = <LauncherTaskAction>[];
    for (final action in actions) {
      final name = action.action.trim();
      if (!audioActions.contains(name)) continue;
      if (_isDownloadRelated(action)) continue;
      if (!seen.add(name)) continue;
      kept.add(action);
    }
    debugPrint(
      '[AudioTask] 原始 Actions: '
      '${actions.map((action) => '${action.action}/${action.icon}').toList()}',
    );
    debugPrint(
      '[AudioTask] 过滤后 Actions: '
      '${kept.map((action) => '${action.action}/${action.icon}').toList()}',
    );
    return List<LauncherTaskAction>.unmodifiable(kept);
  }

  /// Registers (or replaces) the audio task and starts syncing playback state.
  void start({
    required String title,
    required List<LauncherTaskAction> actions,
  }) {
    final playbackActions = _sanitizeActions(actions);
    TaskActivityController.instance.addTask(
      LauncherTask(
        id: taskId,
        title: title,
        icon: Icons.music_note_rounded,
        actions: playbackActions,
      ),
    );
    _listen();
    _sync();
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    PluginAudioService.instance.addListener(_sync);
  }

  void _detach() {
    if (!_listening) return;
    _listening = false;
    PluginAudioService.instance.removeListener(_sync);
  }

  void _sync() {
    final audio = PluginAudioService.instance;
    final controller = TaskActivityController.instance;
    if (controller.taskById(taskId) == null) {
      scheduleMicrotask(_detach);
      return;
    }
    if (!audio.hasSource) {
      controller.removeTask(taskId);
      scheduleMicrotask(_detach);
      return;
    }
    final duration = audio.duration.inMilliseconds;
    final progress = duration > 0
        ? (audio.position.inMilliseconds / duration).clamp(0.0, 1.0)
        : null;
    controller.updateTask(
      taskId,
      progress: progress,
      indeterminate: progress == null,
    );
  }

  /// Test hook: stop mirroring and drop the task.
  void reset() {
    _detach();
    TaskActivityController.instance.removeTask(taskId);
  }
}
