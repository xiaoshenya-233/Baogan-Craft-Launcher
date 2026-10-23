import 'dart:io';

import 'package:flutter/foundation.dart';

/// Owns the selectable Minecraft client source directories.
class LauncherEnvironmentController extends ChangeNotifier {
  String _minecraftPath = '';
  List<String> _minecraftSources = [];

  String get minecraftPath => _minecraftPath;
  List<String> get minecraftSources => List.unmodifiable(_minecraftSources);

  /// Sources in display order with the current path always included once.
  List<String> get effectiveSources {
    final sources = <String>[];
    final seen = <String>{};
    void addSource(String rawPath) {
      final path = rawPath.trim();
      if (path.isEmpty) return;
      final key = _pathKey(path);
      if (seen.add(key)) sources.add(path);
    }

    for (final source in _minecraftSources) {
      addSource(source);
    }
    addSource(_minecraftPath);
    return sources;
  }

  void initialize({String? gameRoot}) {
    _minecraftPath = gameRoot ?? '';
    _minecraftSources = gameRoot == null ? [] : [gameRoot];
    notifyListeners();
  }

  void applyStoredPreferences({
    required List<String> sources,
    String? legacyPath,
    String? gameRoot,
  }) {
    final normalized = <String>[];
    for (final source in sources) {
      final path = source.trim();
      if (path.isNotEmpty && !normalized.any((item) => samePath(item, path))) {
        normalized.add(path);
      }
    }
    final legacy = legacyPath?.trim() ?? '';
    if (legacy.isNotEmpty &&
        !normalized.any((source) => samePath(source, legacy))) {
      normalized.add(legacy);
    }
    if (gameRoot != null &&
        !normalized.any((source) => samePath(source, gameRoot))) {
      normalized.add(gameRoot);
    }
    _minecraftSources = normalized;
    if (_minecraftPath.isEmpty) {
      _minecraftPath =
          gameRoot ??
          (legacy.isNotEmpty ? legacy : _minecraftSources.firstOrNull ?? '');
    }
    notifyListeners();
  }

  bool addSource(String source) {
    final path = source.trim();
    if (path.isEmpty) return false;
    if (_minecraftSources.any((item) => samePath(item, path))) {
      return false;
    }
    _minecraftSources = [..._minecraftSources, path];
    notifyListeners();
    return true;
  }

  bool selectSource(String source) {
    final path = source.trim();
    if (path.isEmpty) return false;
    final exists = _minecraftSources.any((item) => samePath(item, path));
    final changed = !exists || !samePath(_minecraftPath, path);
    if (!exists) {
      _minecraftSources = [..._minecraftSources, path];
    }
    _minecraftPath = path;
    if (changed) notifyListeners();
    return changed;
  }

  bool replaceSource(String oldSource, String newSource) {
    final oldPath = oldSource.trim();
    final newPath = newSource.trim();
    if (newPath.isEmpty) return false;
    final index = _minecraftSources.indexWhere(
      (candidate) => samePath(candidate, oldPath),
    );
    if (index >= 0) {
      _minecraftSources = [..._minecraftSources]..[index] = newPath;
    } else if (!_minecraftSources.any(
      (candidate) => samePath(candidate, newPath),
    )) {
      _minecraftSources = [..._minecraftSources, newPath];
    }
    final changed =
        !samePath(_minecraftPath, newPath) || oldPath != newPath || index < 0;
    _minecraftPath = newPath;
    if (changed) notifyListeners();
    return changed;
  }

  bool removeSource(String source) {
    if (_minecraftSources.length <= 1) return false;
    final path = source.trim();
    final index = _minecraftSources.indexWhere(
      (candidate) => samePath(candidate, path),
    );
    if (index < 0) return false;
    final next = [..._minecraftSources]..removeAt(index);
    _minecraftSources = next;
    if (samePath(_minecraftPath, path)) {
      _minecraftPath = next.first;
    }
    notifyListeners();
    return true;
  }

  static bool samePath(String left, String right) {
    final normalizedLeft = left.replaceAll('/', Platform.pathSeparator);
    final normalizedRight = right.replaceAll('/', Platform.pathSeparator);
    return Platform.isWindows
        ? normalizedLeft.toLowerCase() == normalizedRight.toLowerCase()
        : normalizedLeft == normalizedRight;
  }

  static String _pathKey(String path) {
    final normalized = path.replaceAll('/', Platform.pathSeparator);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }
}
