import 'package:flutter/material.dart' show IconData, Icons, VoidCallback;

import '../plugin/plugin_icon_mapper.dart';

/// Lifecycle of one launcher task shown in the global activity banner.
enum LauncherTaskStatus { running, success, failed }

/// Resolves a short icon name used by plugin JSON to a Material icon.
///
/// Missing names keep the generic widget glyph for launcher tasks, while
/// unknown plugin names go through [PluginIconMapper] and fall back to
/// `Icons.extension` with a warning.
IconData launcherTaskIcon(String? name) {
  final value = name?.trim() ?? '';
  if (value.isEmpty) return Icons.widgets_rounded;
  return PluginIconMapper.getIcon(value);
}

/// A small button embedded inside the active task capsule.
class LauncherTaskAction {
  const LauncherTaskAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.action = '',
  });

  /// Short icon name understood by [launcherTaskIcon].
  final String icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Original plugin action name, e.g. `audio_toggle`.
  final String action;
}

/// A single task displayed by [ActivityBanner].
///
/// `progress == null` means the task is indeterminate (spinner).
class LauncherTask {
  const LauncherTask({
    required this.id,
    required this.title,
    required this.icon,
    this.progress,
    this.status = LauncherTaskStatus.running,
    this.subText,
    this.onTap,
    this.actions = const <LauncherTaskAction>[],
  });

  final String id;
  final String title;
  final IconData icon;

  /// 0.0–1.0, or `null` for an indeterminate task.
  final double? progress;
  final LauncherTaskStatus status;

  /// Short aggregate text (counts/status); never a download log.
  final String? subText;

  /// Optional tap handler, e.g. open the download manager.
  final VoidCallback? onTap;

  /// Buttons rendered inside the active capsule only.
  final List<LauncherTaskAction> actions;
}
