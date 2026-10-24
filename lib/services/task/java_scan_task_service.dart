import 'package:flutter/material.dart' show Icons;

import 'launcher_task.dart';
import 'task_activity_controller.dart';

/// Runs the first-launch Java discovery behind a global task capsule.
class JavaScanTaskService {
  const JavaScanTaskService._();

  static const String taskId = 'java-scan';

  /// Returns `true` when a scan was actually started.
  static Future<bool> runIfNeeded({
    required bool hasCachedRuntimes,
    required Future<void> Function() discover,
    bool skip = false,
  }) async {
    if (hasCachedRuntimes || skip) return false;
    final controller = TaskActivityController.instance;
    controller.addTask(
      const LauncherTask(
        id: taskId,
        title: '正在扫描本地 Java',
        icon: Icons.coffee,
        progress: null,
      ),
    );
    try {
      await discover();
      return true;
    } finally {
      controller.removeTask(taskId);
    }
  }
}
