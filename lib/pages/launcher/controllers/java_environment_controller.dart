import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/launcher_log.dart';
import '../../../core/preferences_store.dart';
import '../../../services/java/java_service.dart';

/// Owns Java runtime discovery, cache and the selected executable.
class JavaEnvironmentController extends ChangeNotifier {
  JavaEnvironmentController({
    required this.preferences,
    required this.minecraftPathProvider,
    required this.cacheFileProvider,
    this.onError,
  });

  final PreferencesStore preferences;
  final String Function() minecraftPathProvider;
  final File? Function() cacheFileProvider;
  final void Function(String message)? onError;

  List<JavaRuntime> _runtimes = [];
  String? _selectedExecutable;
  String _customJavaPath = '';
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _loadError;

  List<JavaRuntime> get runtimes => List.unmodifiable(_runtimes);
  String? get selectedExecutable => _selectedExecutable;

  /// Global default Java as a String: an executable path or `auto`.
  String get javaSelection {
    final selected = _selectedExecutable?.trim() ?? '';
    return selected.isEmpty ? PreferencesStore.autoJavaValue : selected;
  }

  String get customJavaPath => _customJavaPath;
  bool get isLoading => _isLoading;
  bool get hasSearched => _hasSearched;
  String? get loadError => _loadError;

  JavaRuntimeService get service => JavaRuntimeService(
    minecraftPath: minecraftPathProvider(),
    cacheFile: cacheFileProvider(),
  );

  void applyPreferences({String? customPath, String? selectedExecutable}) {
    _customJavaPath = customPath?.trim() ?? '';
    final selected = selectedExecutable?.trim() ?? '';
    _selectedExecutable =
        selected.isEmpty || selected == PreferencesStore.autoJavaValue
        ? null
        : selected;
    notifyListeners();
  }

  Future<void> loadCache() async {
    final loaded = await service.loadCache(known: _runtimes);
    if (loaded.isEmpty) return;
    _runtimes = loaded;
    _hasSearched = true;
    notifyListeners();
    LauncherLog.info('Java', '从缓存载入 ${_runtimes.length} 个 Java 运行时');
  }

  Future<void> discover() async {
    if (_isLoading) return;
    _isLoading = true;
    _hasSearched = true;
    _loadError = null;
    notifyListeners();
    try {
      final sorted = await service.discover(
        known: _runtimes,
        customPath: _customJavaPath,
        selectedExecutable: _selectedExecutable,
      );
      _runtimes = sorted;
      _isLoading = false;
      if (sorted.isEmpty) {
        _loadError = '未检测到可用 Java，请安装 Java、设置 JAVA_HOME，或手动选择 Java 位置。';
      }
      notifyListeners();
      await saveCache();
    } on Exception catch (error) {
      _isLoading = false;
      _loadError = 'Java 搜索失败：$error';
      notifyListeners();
    }
  }

  Future<JavaRuntime?> registerExecutable(String path) async {
    JavaRuntime? runtime;
    try {
      runtime = await service.probeExecutable(path, source: '手动选择');
    } on Exception catch (error) {
      onError?.call('Java 检测失败：$error');
      return null;
    }
    if (runtime == null) return null;

    final normalized = service.normalizePath(path);
    final next =
        _runtimes
            .where(
              (candidate) =>
                  service.normalizePath(candidate.executable) != normalized,
            )
            .toList()
          ..add(runtime);
    _runtimes = service.sort(next);
    _hasSearched = true;
    _customJavaPath = '';
    notifyListeners();
    try {
      // Adding a runtime never selects it: the default stays untouched.
      await preferences.write('customJavaPath', '');
      await saveCache();
    } on FormatException catch (error) {
      onError?.call('保存 Java 设置失败：${error.message}');
    } on FileSystemException catch (error) {
      onError?.call('保存 Java 设置失败：${error.message}');
    }
    return runtime;
  }

  /// Removes a runtime from the list and the cache; the file stays on disk.
  Future<void> removeRuntime(String executable) async {
    final service = this.service;
    final normalized = service.normalizePath(executable);
    _runtimes = _runtimes
        .where(
          (candidate) =>
              service.normalizePath(candidate.executable) != normalized,
        )
        .toList();
    final selected = _selectedExecutable;
    if (selected != null && service.normalizePath(selected) == normalized) {
      _selectedExecutable = null;
      await preferences.setJavaSelection(PreferencesStore.autoJavaValue);
    }
    notifyListeners();
    await saveCache();
    LauncherLog.info('Java', '从列表移除 Java：$executable');
  }

  Future<void> selectRuntime(String? executable) async {
    _customJavaPath = '';
    final value = executable?.trim() ?? '';
    _selectedExecutable =
        value.isEmpty || value == PreferencesStore.autoJavaValue ? null : value;
    notifyListeners();
    await _persistSelection();
  }

  Future<void> clearCustomPath() async {
    await selectRuntime(null);
  }

  Future<void> addProbedRuntime(JavaRuntime runtime) async {
    final normalized = service.normalizePath(runtime.executable);
    final next =
        _runtimes
            .where(
              (candidate) =>
                  service.normalizePath(candidate.executable) != normalized,
            )
            .toList()
          ..add(runtime);
    _runtimes = service.sort(next);
    _hasSearched = true;
    notifyListeners();
    await saveCache();
  }

  Future<void> saveCache() async {
    await service.saveCache(_runtimes);
  }

  Future<void> _persistSelection() async {
    try {
      await preferences.setJavaSelection(javaSelection);
      await preferences.write('customJavaPath', '');
    } on FormatException catch (error) {
      onError?.call('保存 Java 设置失败：${error.message}');
    } on FileSystemException catch (error) {
      onError?.call('保存 Java 设置失败：${error.message}');
    }
  }
}
