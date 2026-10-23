import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/launcher_log.dart';
import '../../../core/preferences_store.dart';
import '../../../services/installer/version_models.dart';
import '../../../services/launcher/game_launcher.dart';
import '../../launcher/controllers/launcher_environment_controller.dart';

/// Owns the scanned version catalog, selection and persisted client choice.
class VersionCatalogController extends ChangeNotifier {
  VersionCatalogController({
    required this.preferences,
    required this.sourcesProvider,
    required this.minecraftPathProvider,
    this.onError,
  });

  final PreferencesStore preferences;
  final List<String> Function() sourcesProvider;
  final String Function() minecraftPathProvider;
  final void Function(String message)? onError;

  List<LauncherVersion> _versions = [];
  List<MinecraftVersion> _localVersions = [];
  String? _selectedLaunchVersionId;
  String? _preferredDownloadVersionId;
  bool _isLoadingVersions = false;
  String? _versionLoadError;
  int _versionLoadRequestId = 0;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _notifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  List<LauncherVersion> get versions => List.unmodifiable(_versions);
  List<MinecraftVersion> get localVersions => List.unmodifiable(_localVersions);
  String? get selectedLaunchVersionId => _selectedLaunchVersionId;
  String? get preferredDownloadVersionId => _preferredDownloadVersionId;
  bool get isLoadingVersions => _isLoadingVersions;
  String? get versionLoadError => _versionLoadError;

  void applyPersistedSelection(String? preferredVersion) {
    _preferredDownloadVersionId = preferredVersion;
    _selectedLaunchVersionId = preferredVersion;
    _notifyListeners();
  }

  void clearVersions() {
    // Invalidate an in-flight scan so an old source cannot repopulate the list.
    _versionLoadRequestId++;
    _versions = [];
    _localVersions = [];
    _selectedLaunchVersionId = null;
    _isLoadingVersions = false;
    _versionLoadError = null;
    _notifyListeners();
  }

  String? resolveVersionPath(
    String? storedValue,
    List<MinecraftVersion> localVersions,
    List<LauncherVersion> versions,
  ) {
    if (storedValue == null || storedValue.trim().isEmpty) return null;
    final value = storedValue.trim();
    final byPath = localVersions
        .where(
          (version) => LauncherEnvironmentController.samePath(
            version.directoryPath,
            value,
          ),
        )
        .firstOrNull;
    if (byPath != null) return byPath.directoryPath;
    final byId = localVersions
        .where((version) => version.id == value)
        .firstOrNull;
    if (byId != null) return byId.directoryPath;
    final byName = versions
        .where((version) => version.name == value)
        .firstOrNull;
    return byName?.path;
  }

  Future<void> selectLaunchVersion(String versionId) async {
    if (_isDisposed) return;
    _selectedLaunchVersionId = versionId;
    _notifyListeners();
    try {
      await savePreferredDownloadVersion(versionId);
    } on FormatException catch (error) {
      onError?.call('保存客户端选择失败：${error.message}');
    } on FileSystemException catch (error) {
      onError?.call('保存客户端选择失败：${error.message}');
    }
  }

  Future<void> savePreferredDownloadVersion(String versionId) async {
    await preferences.write('preferredDownloadVersionId', versionId);
    _preferredDownloadVersionId = versionId;
    _selectedLaunchVersionId = versionId;
    _notifyListeners();
  }

  /// Removes a deleted client from both catalogs and clears matching choices.
  /// Returns true when the persisted preferred version was also cleared.
  bool removeVersionByPath(String path) {
    final removedPreferred =
        _preferredDownloadVersionId != null &&
        LauncherEnvironmentController.samePath(
          _preferredDownloadVersionId!,
          path,
        );
    _versions = _versions
        .where(
          (version) =>
              !LauncherEnvironmentController.samePath(version.path, path),
        )
        .toList();
    _localVersions = _localVersions
        .where(
          (version) => !LauncherEnvironmentController.samePath(
            version.directoryPath,
            path,
          ),
        )
        .toList();
    if (_selectedLaunchVersionId != null &&
        LauncherEnvironmentController.samePath(
          _selectedLaunchVersionId!,
          path,
        )) {
      _selectedLaunchVersionId = null;
    }
    if (removedPreferred) {
      _preferredDownloadVersionId = null;
    }
    _notifyListeners();
    return removedPreferred;
  }

  Future<void> loadVersions() async {
    if (_isDisposed) return;
    final requestId = ++_versionLoadRequestId;
    _isLoadingVersions = true;
    _versionLoadError = null;
    _notifyListeners();

    final sources = sourcesProvider();
    final minecraftPath = minecraftPathProvider();
    LauncherLog.info(
      'Versions',
      '开始扫描版本：当前来源 ${minecraftPath.isEmpty ? '未选择' : minecraftPath}，'
          '来源总数 ${sources.length}',
    );
    if (sources.isEmpty) {
      if (_isDisposed || requestId != _versionLoadRequestId) return;
      _versions = [];
      _localVersions = [];
      _selectedLaunchVersionId = null;
      _isLoadingVersions = false;
      _notifyListeners();
      return;
    }

    // 多个来源仅作为可切换的 .minecraft 目录保存，版本列表始终只扫描
    // 当前来源，避免切换后仍混入其他文件夹的客户端。
    final localVersions = <MinecraftVersion>[];
    String? firstError;
    try {
      localVersions.addAll(
        await loadActiveMinecraftVersions(
          minecraftPath: minecraftPath,
          sources: sources,
        ),
      );
    } on FileSystemException catch (error) {
      firstError = error.message;
    } on FormatException catch (error) {
      firstError = error.message;
    }
    localVersions.sort((left, right) {
      return left.id.toLowerCase().compareTo(right.id.toLowerCase());
    });

    final found = <LauncherVersion>[];
    for (final version in localVersions) {
      final name = lastPathSegment(version.directoryPath);
      final gameDirectory = version.directoryPath;
      var hasModsDirectory = false;
      try {
        hasModsDirectory = await Directory(
          minecraftVersionSubfolder(gameDirectory, 'mods'),
        ).exists();
      } on FileSystemException {
        hasModsDirectory = false;
      }
      final isModded =
          version.loaderType != null ||
          name.toLowerCase().contains('quilt') ||
          hasModsDirectory;
      found.add(
        LauncherVersion(
          name: name,
          path: version.directoryPath,
          gameDirectory: gameDirectory,
          kind: isModded ? VersionKind.modded : VersionKind.vanilla,
          minecraftPath: version.minecraftPath,
          minecraftVersion: version.minecraftVersion,
          versionType: version.type,
          loaderType: version.loaderType,
          loaderVersion: version.loaderVersion,
        ),
      );
    }
    found.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return byName;
      return a.minecraftPath.toLowerCase().compareTo(
        b.minecraftPath.toLowerCase(),
      );
    });

    if (_isDisposed || requestId != _versionLoadRequestId) return;
    _versions = found;
    _localVersions = localVersions;
    final storedSelection = resolveVersionPath(
      _selectedLaunchVersionId,
      localVersions,
      found,
    );
    final preferred = resolveVersionPath(
      _preferredDownloadVersionId,
      localVersions,
      found,
    );
    _selectedLaunchVersionId =
        storedSelection ??
        preferred ??
        localVersions.firstOrNull?.directoryPath;
    if (preferred != null) {
      _preferredDownloadVersionId = preferred;
    }
    _versionLoadError = localVersions.isEmpty ? firstError : null;
    _isLoadingVersions = false;
    _notifyListeners();
    LauncherLog.info(
      'Versions',
      '版本扫描完成：${found.length} 个客户端'
          '${firstError == null ? '' : '，错误：$firstError'}',
    );
  }
}
