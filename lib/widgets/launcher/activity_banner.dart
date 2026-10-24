import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/plugin/plugin_audio_service.dart';
import '../../services/task/launcher_task.dart';
import '../../services/task/task_activity_controller.dart';

/// Global task capsule shown in the launcher top bar.
///
/// Shows the active task as a stadium capsule and the remaining tasks as
/// circular icon switches. Renders nothing when there are no tasks.
class ActivityBanner extends StatelessWidget {
  const ActivityBanner({super.key, this.onOpenDownloads});

  /// Fallback tap handler for the built-in download task.
  final VoidCallback? onOpenDownloads;

  static const String downloadTaskId = 'downloads';
  static const int _maxCircles = 4;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TaskActivityController.instance,
      builder: (context, _) {
        final controller = TaskActivityController.instance;
        final active = controller.activeTask;
        if (active == null) return const SizedBox.shrink();
        final others = controller.tasks
            .where((task) => task.id != active.id)
            .toList(growable: false);
        final visibleOthers = others.take(_maxCircles).toList(growable: false);
        return Padding(
          padding: EdgeInsets.only(right: Platform.isWindows ? 132 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _TaskCapsule(task: active, fallbackTap: _tapFor(active)),
              ),
              for (final task in visibleOthers) ...[
                const SizedBox(width: 7),
                _TaskCircle(
                  task: task,
                  onTap: () => controller.setActive(task.id),
                ),
              ],
              if (others.length > visibleOthers.length) ...[
                const SizedBox(width: 7),
                _TaskCircleCount(
                  count: others.length - visibleOthers.length,
                  onTap: () => controller.setActive(visibleOthers.last.id),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  VoidCallback? _tapFor(LauncherTask task) {
    if (task.onTap != null) return task.onTap;
    return task.id == downloadTaskId ? onOpenDownloads : null;
  }
}

class _TaskCapsule extends StatelessWidget {
  const _TaskCapsule({required this.task, required this.fallbackTap});

  final LauncherTask task;
  final VoidCallback? fallbackTap;

  /// Hard height limit: every task, including plugin tasks, uses this height.
  static const double capsuleHeight = 48;
  static const double maxWidth = 420;

  /// The plugin API caps task actions at six; slice defensively anyway so a
  /// hand-built task can never widen the capsule without bound.
  static const int _maxActions = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _taskColor(theme, task);
    final progress = task.progress;
    final percent = progress == null
        ? null
        : '${(progress * 100).toStringAsFixed(0)}%';
    debugPrint(
      '[Banner] 当前任务: ${task.id}, '
      '渲染的 Actions: ${task.actions.map((e) => e.action).toList()}',
    );
    debugPrint(
      '[Banner] 当前任务: ${task.id}, '
      'Action 图标: ${task.actions.map((e) => e.icon).toList()}',
    );
    final detail = task.subText?.trim();
    final displayTitle = detail == null || detail.isEmpty
        ? task.title
        : '${task.title} · $detail';
    final actions = task.actions.take(_maxActions).toList(growable: false);
    return SizedBox(
      key: ValueKey('task-capsule-${task.id}'),
      height: capsuleHeight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Material(
          color: scheme.surface.withValues(alpha: 0.94),
          shape: StadiumBorder(
            side: BorderSide(color: accent.withValues(alpha: 0.55)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: fallbackTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(task.icon, size: 20, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            if (percent != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                percent,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ] else if (task.status ==
                                LauncherTaskStatus.running) ...[
                              const SizedBox(width: 6),
                              Text(
                                '…',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (progress != null) ...[
                          const SizedBox(height: 2),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 3,
                              backgroundColor: scheme.outlineVariant.withValues(
                                alpha: 0.25,
                              ),
                              color: accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < actions.length; index++) ...[
                        if (index > 0) const SizedBox(width: 1),
                        _buildActionButton(
                          actions[index],
                          index,
                          accent,
                          scheme,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    LauncherTaskAction action,
    int index,
    Color accent,
    ColorScheme scheme,
  ) {
    return SizedBox(
      width: 26,
      height: 26,
      child: IconButton(
        key: ValueKey('task-action-${task.id}-$index-${action.action}'),
        tooltip: action.tooltip,
        onPressed: action.onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 26, height: 26),
        visualDensity: VisualDensity.compact,
        iconSize: 15,
        icon: action.action == 'audio_toggle'
            ? ListenableBuilder(
                listenable: PluginAudioService.instance,
                builder: (context, _) => Icon(
                  launcherTaskIcon(
                    PluginAudioService.instance.isPlaying
                        ? 'pause'
                        : 'play_arrow',
                  ),
                  size: 15,
                  color: accent,
                ),
              )
            : Icon(
                launcherTaskIcon(action.icon),
                size: 15,
                color: action.icon == 'stop' || action.icon == 'cancel'
                    ? scheme.error
                    : accent,
              ),
      ),
    );
  }
}

class _TaskCircle extends StatelessWidget {
  const _TaskCircle({required this.task, required this.onTap});

  final LauncherTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _taskColor(theme, task);
    return Tooltip(
      message: task.title,
      child: Material(
        color: scheme.surface.withValues(alpha: 0.94),
        shape: CircleBorder(
          side: BorderSide(color: accent.withValues(alpha: 0.55)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: _taskCircleSize,
            height: _taskCircleSize,
            child: Icon(task.icon, size: 18, color: accent),
          ),
        ),
      ),
    );
  }
}

class _TaskCircleCount extends StatelessWidget {
  const _TaskCircleCount({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.94),
      shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _taskCircleSize,
          height: _taskCircleSize,
          child: Center(
            child: Text(
              '+$count',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circle task switches stay within the capsule's 44–48 px band.
const double _taskCircleSize = 44;

Color _taskColor(ThemeData theme, LauncherTask task) => switch (task.status) {
  LauncherTaskStatus.running => theme.colorScheme.primary,
  LauncherTaskStatus.success => const Color(0xFF4CAF50),
  LauncherTaskStatus.failed => theme.colorScheme.error,
};
