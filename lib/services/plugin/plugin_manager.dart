import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/launcher_log.dart';
import '../../core/path_manager.dart';
import '../../core/path_utils.dart';
import 'plugin_manifest.dart';

/// One loaded floating UI document, bound to the plugin that owns it.
class PluginFloatingUi {
  const PluginFloatingUi({required this.manifest, required this.document});

  final PluginManifest manifest;
  final Map<String, dynamic> document;

  PluginFloatingUiConfig get config => manifest.floatingUi!;
}

/// Raised when installing or uninstalling a plugin fails.
class PluginInstallException implements Exception {
  const PluginInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ZipFileData {
  const _ZipFileData(this.relativePath, this.bytes);

  final String relativePath;
  final List<int> bytes;
}

/// Discovers and loads plugins from `BGCL/plugins/`.
///
/// Every plugin folder must contain `plugin.json`; its `entryUi` points at the
/// JSON UI document rendered by the plugin UI renderer. Per-plugin writable
/// state lives in `BGCL/plugins_data/<plugin_id>/`, so plugins never share files.
class PluginManager extends ChangeNotifier {
  PluginManager._();

  static final PluginManager instance = PluginManager._();

  static const String manifestFileName = 'plugin.json';
  static const String pluginsFolderName = 'plugins';
  static const String pluginDataFolderName = 'plugins_data';
  static const int maxManifestBytes = 256 * 1024;
  static const int maxUiBytes = 1024 * 1024;
  static const int maxZipBytes = 64 * 1024 * 1024;
  static const int maxUncompressedBytes = 128 * 1024 * 1024;
  static const int maxPluginFileBytes = 32 * 1024 * 1024;
  static const int maxZipEntries = 4096;

  /// Overrides the `BGCL` data root; tests point this at a temporary folder.
  String? Function()? dataRootProvider;

  final List<PluginManifest> _plugins = <PluginManifest>[];
  final List<PluginFloatingUi> _floatingUis = <PluginFloatingUi>[];
  Future<List<PluginManifest>>? _scanFuture;
  bool _isLoaded = false;
  String? _lastError;

  List<PluginManifest> get plugins =>
      List<PluginManifest>.unmodifiable(_plugins);
  List<PluginFloatingUi> get floatingUis =>
      List<PluginFloatingUi>.unmodifiable(_floatingUis);
  bool get isLoaded => _isLoaded;
  String? get lastError => _lastError;

  String? get _dataRoot {
    final value = (dataRootProvider?.call() ?? PathManager.instance.dataRoot)
        ?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// `BGCL/plugins`; `null` until the launcher root is configured.
  String? get pluginsDirectory {
    final root = _dataRoot;
    return root == null ? null : joinPath(root, pluginsFolderName);
  }

  /// Absolute path of `BGCL/plugins`, or `null` before the setup completes.
  String? get pluginsDirectoryPath {
    final directory = pluginsDirectory;
    return directory == null ? null : p.normalize(p.absolute(directory));
  }

  /// `BGCL/plugins_data`; `null` until the launcher root is configured.
  String? get pluginDataDirectory {
    final root = _dataRoot;
    return root == null ? null : joinPath(root, pluginDataFolderName);
  }

  PluginManifest? byId(String id) {
    for (final plugin in _plugins) {
      if (plugin.id == id) return plugin;
    }
    return null;
  }

  /// Scans once; later calls share the same future until [reload].
  Future<List<PluginManifest>> scan() => _scanFuture ??= _scan();

  /// Forces a fresh scan (e.g. after the player drops in a new plugin).
  Future<List<PluginManifest>> reload() {
    _scanFuture = null;
    return scan();
  }

  /// Directory reserved for one plugin's writable data.
  String? dataDirectoryFor(String pluginId) {
    if (!PluginManifest.idPattern.hasMatch(pluginId)) return null;
    final root = _dataRoot;
    if (root == null) return null;
    return joinPath(joinPath(root, pluginDataFolderName), pluginId);
  }

  /// Removes the plugin folder and its writable data, then reloads the list.
  Future<void> uninstallPlugin(String id) async {
    if (!PluginManifest.idPattern.hasMatch(id)) {
      throw const PluginInstallException('插件 id 无效。');
    }
    final root = pluginsDirectory;
    if (root == null) {
      throw const PluginInstallException('启动器数据目录未配置，无法卸载插件。');
    }
    final pluginPath = byId(id)?.directoryPath ?? joinPath(root, id);
    final dataPath = dataDirectoryFor(id);
    try {
      final pluginDirectory = Directory(pluginPath);
      if (await pluginDirectory.exists()) {
        await pluginDirectory.delete(recursive: true);
      }
      if (dataPath != null) {
        final dataDirectory = Directory(dataPath);
        if (await dataDirectory.exists()) {
          await dataDirectory.delete(recursive: true);
        }
      }
      LauncherLog.info('Plugins', '已卸载插件并删除数据：$id');
    } on FileSystemException catch (error) {
      throw PluginInstallException('卸载插件失败：${error.message}');
    }
    await reload();
  }

  /// Installs a plugin ZIP into `plugins/<id>/` after validating every entry.
  Future<PluginManifest> installFromZip(String zipFilePath) async {
    final root = pluginsDirectory;
    if (root == null) {
      throw const PluginInstallException('启动器数据目录未配置，无法安装插件。');
    }
    final source = File(zipFilePath);
    if (!await source.exists()) {
      throw PluginInstallException('ZIP 文件不存在：$zipFilePath');
    }
    if (await source.length() > maxZipBytes) {
      throw const PluginInstallException('ZIP 文件超过 64 MB 上限。');
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await source.readAsBytes());
    } on Object catch (error) {
      throw PluginInstallException('ZIP 文件无效：$error');
    }
    if (archive.files.isEmpty) {
      throw const PluginInstallException('ZIP 文件为空。');
    }
    if (archive.files.length > maxZipEntries) {
      throw const PluginInstallException('ZIP 条目超过 4096 个上限。');
    }
    final manifestEntry = _findInstallManifest(archive);
    if (manifestEntry == null) {
      throw const PluginInstallException('ZIP 根目录或第一层子目录缺少 plugin.json。');
    }
    final manifestBytes = manifestEntry.content;
    if (manifestBytes is! List<int> ||
        manifestBytes.length > maxManifestBytes) {
      throw const PluginInstallException('plugin.json 内容无效或超过 256 KB。');
    }
    final Map<String, dynamic> raw;
    try {
      final decoded = jsonDecode(utf8.decode(manifestBytes));
      if (decoded is! Map) {
        throw const FormatException('根节点必须是对象。');
      }
      raw = Map<String, dynamic>.from(decoded);
    } on FormatException catch (error) {
      throw PluginInstallException('plugin.json 无效：${error.message}');
    }
    final PluginManifest preliminary;
    try {
      preliminary = PluginManifest.fromJson(raw, directoryPath: root);
    } on FormatException catch (error) {
      throw PluginInstallException('plugin.json 无效：${error.message}');
    }
    final targetRoot = joinPath(root, preliminary.id);
    final manifest = PluginManifest.fromJson(raw, directoryPath: targetRoot);
    final manifestPath = _normalizeZipEntry(manifestEntry.name);
    final prefix = manifestPath == manifestFileName
        ? null
        : p.posix.dirname(manifestPath);
    final staging = Directory(
      joinPath(
        root,
        '.install_${preliminary.id}_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await staging.create(recursive: true);
    try {
      final files = <_ZipFileData>[];
      var totalBytes = 0;
      for (final entry in archive.files) {
        final name = _normalizeZipEntry(entry.name);
        if (!entry.isFile) continue;
        if (name.startsWith('__MACOSX/')) continue;
        final relative = _relativeZipEntry(name, prefix);
        if (relative == null || relative.isEmpty) continue;
        if (relative == '.DS_Store' || relative.endsWith('/.DS_Store')) {
          continue;
        }
        final content = entry.content;
        if (content is! List<int>) {
          throw PluginInstallException('ZIP 条目内容无效：$name');
        }
        if (content.length > maxPluginFileBytes) {
          throw PluginInstallException('ZIP 内单个文件超过 32 MB：$name');
        }
        totalBytes += content.length;
        if (totalBytes > maxUncompressedBytes) {
          throw const PluginInstallException('ZIP 解压后超过 128 MB 上限。');
        }
        final target = p.normalize(joinPath(staging.path, relative));
        if (!isPathInside(target, staging.path)) {
          throw PluginInstallException('ZIP 路径越界：$name');
        }
        files.add(_ZipFileData(relative, content));
      }
      if (files.isEmpty) {
        throw const PluginInstallException('ZIP 中没有可安装的文件。');
      }
      for (final file in files) {
        final target = File(
          p.normalize(joinPath(staging.path, file.relativePath)),
        );
        await target.parent.create(recursive: true);
        await target.writeAsBytes(file.bytes, flush: true);
      }
      final target = Directory(targetRoot);
      if (await target.exists()) {
        await target.delete(recursive: true);
      }
      await staging.rename(targetRoot);
      await reload();
      return byId(preliminary.id) ?? manifest;
    } on FileSystemException catch (error) {
      throw PluginInstallException('解压插件失败：${error.message}');
    } finally {
      if (await staging.exists()) {
        try {
          await staging.delete(recursive: true);
        } on FileSystemException {
          // Best effort; the staging folder has no plugin.json and is ignored.
        }
      }
    }
  }

  /// Reads the plugin's JSON UI document, enforcing containment and size.
  Future<Map<String, dynamic>?> loadUiDocument(PluginManifest manifest) =>
      _loadDocument(manifest, manifest.entryUi, label: 'UI');

  Future<Map<String, dynamic>?> _loadDocument(
    PluginManifest manifest,
    String entry, {
    required String label,
  }) async {
    final target = joinPath(manifest.directoryPath, entry);
    if (!isPathInside(target, manifest.directoryPath)) {
      _lastError = '插件 ${manifest.id} 的 $label 路径越出了插件目录。';
      LauncherLog.warning('Plugins', _lastError!);
      return null;
    }
    try {
      final file = File(target);
      if (!await file.exists()) {
        _lastError = '插件 ${manifest.id} 缺少 $label 文件：$entry';
        LauncherLog.warning('Plugins', _lastError!);
        return null;
      }
      final length = await file.length();
      if (length > maxUiBytes) {
        _lastError = '插件 ${manifest.id} 的 $label 文件超过 1 MB。';
        LauncherLog.warning('Plugins', _lastError!);
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('$label 根节点必须是 JSON 对象。');
      }
      _lastError = null;
      return decoded;
    } on FormatException catch (error) {
      _lastError = '插件 ${manifest.id} 的 $label JSON 无效：${error.message}';
      LauncherLog.warning('Plugins', _lastError!);
      return null;
    } on FileSystemException catch (error) {
      _lastError = '读取插件 ${manifest.id} 的 $label 失败：${error.message}';
      LauncherLog.warning('Plugins', _lastError!);
      return null;
    }
  }

  Future<List<PluginManifest>> _scan() async {
    _plugins.clear();
    _floatingUis.clear();
    _lastError = null;
    final root = _dataRoot;
    final directory = pluginsDirectory;
    if (root == null || directory == null) {
      _isLoaded = true;
      LauncherLog.warning('Plugins', '启动器数据目录未配置，跳过插件扫描。');
      notifyListeners();
      return plugins;
    }

    try {
      final folder = Directory(directory);
      await folder.create(recursive: true);
      final dataDirectory = pluginDataDirectory;
      if (dataDirectory != null) {
        await Directory(dataDirectory).create(recursive: true);
      }
      final entries = await folder.list(followLinks: false).toList();
      entries.sort((a, b) => a.path.compareTo(b.path));
      final ids = <String>{};
      for (final entry in entries) {
        if (entry is! Directory) continue;
        try {
          final manifest = await _loadManifest(entry);
          if (manifest == null) continue;
          if (!ids.add(manifest.id)) {
            LauncherLog.warning(
              'Plugins',
              '插件 id 重复，已跳过：${manifest.id}（${entry.path}）',
            );
            continue;
          }
          await _ensureDataDirectory(manifest);
          final floatingConfig = manifest.floatingUi;
          if (floatingConfig != null) {
            final document = await _loadDocument(
              manifest,
              floatingConfig.entry,
              label: 'floating.json',
            );
            if (document != null) {
              _floatingUis.add(
                PluginFloatingUi(manifest: manifest, document: document),
              );
            }
          }
          _plugins.add(manifest);
          LauncherLog.info(
            'Plugins',
            '已加载插件 ${manifest.id} ${manifest.version}：${manifest.name}',
          );
        } on FormatException catch (error) {
          LauncherLog.warning(
            'Plugins',
            '插件 ${p.basename(entry.path)} 的 plugin.json 无效：${error.message}',
          );
        } on FileSystemException catch (error) {
          LauncherLog.warning(
            'Plugins',
            '读取插件 ${p.basename(entry.path)} 失败：${error.message}',
          );
        }
      }
      await _cleanupOrphanPluginData(ids);
      LauncherLog.info('Plugins', '插件扫描完成，共 ${_plugins.length} 个。');
    } on FileSystemException catch (error) {
      _lastError = '扫描插件目录失败：${error.message}';
      LauncherLog.warning('Plugins', _lastError!);
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
    return plugins;
  }

  ArchiveFile? _findInstallManifest(Archive archive) {
    ArchiveFile? nested;
    for (final entry in archive.files) {
      final name = _normalizeZipEntry(entry.name);
      if (!entry.isFile) continue;
      if (name == manifestFileName) return entry;
      final segments = name.split('/');
      if (segments.length == 2 && segments[1] == manifestFileName) {
        nested ??= entry;
      }
    }
    return nested;
  }

  /// Accepts only relative, forward-slash ZIP paths with no `..` segment.
  String _normalizeZipEntry(String raw) {
    final value = raw.trim().replaceAll('\\', '/');
    if (value.isEmpty ||
        value.contains('\u0000') ||
        value.contains(':') ||
        value.startsWith('/')) {
      throw PluginInstallException('ZIP 路径不安全：$raw');
    }
    if (value.split('/').any((segment) => segment == '..')) {
      throw PluginInstallException('ZIP 包含目录穿越路径：$raw');
    }
    final normalized = p.posix.normalize(value);
    if (normalized == '.' ||
        normalized == '..' ||
        normalized.startsWith('../') ||
        normalized.startsWith('/')) {
      throw PluginInstallException('ZIP 路径不安全：$raw');
    }
    if (normalized
        .split('/')
        .any((segment) => segment.isEmpty || segment == '..')) {
      throw PluginInstallException('ZIP 路径不安全：$raw');
    }
    return normalized;
  }

  String? _relativeZipEntry(String name, String? prefix) {
    if (prefix == null) return name;
    if (name == prefix) return null;
    return name.startsWith('$prefix/')
        ? name.substring(prefix.length + 1)
        : null;
  }

  Future<void> _cleanupOrphanPluginData(Set<String> validIds) async {
    final path = pluginDataDirectory;
    if (path == null) return;
    final directory = Directory(path);
    try {
      if (!await directory.exists()) return;
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is! Directory) continue;
        final name = p.basename(entry.path);
        if (validIds.contains(name)) continue;
        try {
          await entry.delete(recursive: true);
          LauncherLog.info('Plugins', '已清理孤儿插件数据：$name');
        } on FileSystemException catch (error) {
          LauncherLog.warning('Plugins', '清理孤儿插件数据 $name 失败：${error.message}');
        }
      }
    } on FileSystemException catch (error) {
      LauncherLog.warning('Plugins', '扫描孤儿插件数据失败：${error.message}');
    }
  }

  Future<PluginManifest?> _loadManifest(Directory directory) async {
    final file = File(joinPath(directory.path, manifestFileName));
    if (!await file.exists()) return null;
    final length = await file.length();
    if (length > maxManifestBytes) {
      throw FormatException('$manifestFileName 超过 256 KB。');
    }
    return PluginManifest.fromJsonString(
      await file.readAsString(),
      directoryPath: directory.path,
    );
  }

  Future<void> _ensureDataDirectory(PluginManifest manifest) async {
    final target = dataDirectoryFor(manifest.id);
    if (target == null) return;
    await Directory(target).create(recursive: true);
  }
}
