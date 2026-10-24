import 'package:flutter/foundation.dart';

import 'launcher_task.dart';

/// Global registry of launcher tasks surfaced by the activity banner.
class TaskActivityController extends ChangeNotifier {
  TaskActivityController._();

  static final TaskActivityController instance = TaskActivityController._();

  final List<LauncherTask> _tasks = <LauncherTask>[];
  String? _activeTaskId;

  List<LauncherTask> get tasks => List<LauncherTask>.unmodifiable(_tasks);
  String? get activeTaskId => _activeTaskId;

  LauncherTask? get activeTask {
    final id = _activeTaskId;
    if (id == null) return null;
    return taskById(id);
  }

  LauncherTask? taskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// Adds (or replaces) a task and makes it active.
  void addTask(LauncherTask task) {
    _tasks.removeWhere((existing) => existing.id == task.id);
    _tasks.add(task);
    _activeTaskId = task.id;
    notifyListeners();
  }

  void updateTask(
    String id, {
    String? title,
    double? progress,
    bool indeterminate = false,
    LauncherTaskStatus? status,
    String? subText,
  }) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) return;
    final current = _tasks[index];
    _tasks[index] = LauncherTask(
      id: current.id,
      title: title ?? current.title,
      icon: current.icon,
      progress: indeterminate
          ? null
          : (progress ?? current.progress)?.clamp(0.0, 1.0).toDouble(),
      status: status ?? current.status,
      subText: subText ?? current.subText,
      onTap: current.onTap,
      actions: current.actions,
    );
    notifyListeners();
  }

  void removeTask(String id) {
    final removed = _tasks.length;
    _tasks.removeWhere((task) => task.id == id);
    if (_tasks.length == removed) return;
    if (_activeTaskId == id) {
      _activeTaskId = _tasks.isEmpty ? null : _tasks.first.id;
    }
    notifyListeners();
  }

  void setActive(String id) {
    if (_activeTaskId == id || taskById(id) == null) return;
    _activeTaskId = id;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _tasks.clear();
    _activeTaskId = null;
    notifyListeners();
  }
}
