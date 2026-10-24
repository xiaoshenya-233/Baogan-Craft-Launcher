import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/path_utils.dart';
import 'plugin_manager.dart';
import 'plugin_manifest.dart';

/// Raised when a plugin asks for a path outside its own data sandbox or when
/// reading/writing exceeds the configured limits.
class PluginSandboxException implements Exception {
  const PluginSandboxException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// File-system sandbox for plugins.
///
/// Every path is resolved against `BGCL/plugins_data/<plugin_id>/`; absolute
/// paths, `.`/`..` segments and any traversal are rejected before touching the
/// disk. Callers must also check the plugin's `file_system` permission.
class PluginFileSandbox {
  const PluginFileSandbox._();

  static const int maxReadBytes = 512 * 1024;
  static const int maxWriteBytes = 1024 * 1024;

  /// Fixed per-plugin settings file inside the data sandbox.
  static const String configFileName = 'config.json';

  /// Absolute path inside the plugin data sandbox, or `null` when unsafe.
  static String? resolve(String pluginId, String relativePath) {
    final root = PluginManager.instance.dataDirectoryFor(pluginId);
    if (root == null) return null;
    final normalized = _cleanRelative(relativePath);
    if (normalized == null) return null;
    final target = p.normalize(joinPath(root, normalized));
    return isPathInside(target, root) ? target : null;
  }

  /// Read-only lookup across the plugin folder and its data folder.
  ///
  /// Static resources bundled with the plugin (`plugins/<id>/audio/...`) win
  /// over runtime files in `plugins_data/<id>/`.
  static String? resolveReadable(
    PluginManifest manifest,
    String relativePath,
  ) => resolveInRoots(relativePath, <String?>[
    manifest.directoryPath,
    PluginManager.instance.dataDirectoryFor(manifest.id),
  ]);

  /// Resolves [relativePath] inside the first safe, existing root.
  static String? resolveInRoots(String relativePath, Iterable<String?> roots) {
    final normalized = _cleanRelative(relativePath);
    if (normalized == null) return null;
    String? fallback;
    for (final root in roots) {
      if (root == null || root.trim().isEmpty) continue;
      final target = p.normalize(joinPath(root, normalized));
      if (!isPathInside(target, root)) continue;
      if (File(target).existsSync()) return target;
      fallback ??= target;
    }
    return fallback;
  }

  /// Resolves a folder relative to [rootDirectory] (plugin folder).
  ///
  /// An empty [relativeFolder] addresses the root itself. Returns `null` for
  /// absolute paths and any traversal outside the root.
  static Directory? resolveDirectoryInRoot(
    String rootDirectory,
    String relativeFolder,
  ) {
    final root = p.normalize(p.absolute(rootDirectory));
    final cleaned = relativeFolder.trim().replaceAll('\\', '/');
    if (cleaned.isEmpty) return Directory(root);
    final normalized = _cleanRelative(cleaned);
    if (normalized == null) return null;
    final target = p.normalize(joinPath(root, normalized));
    if (!p.equals(target, root) && !isPathInside(target, root)) return null;
    return Directory(target);
  }

  /// Resolves a folder relative to the plugin root (`plugins/<id>/`).
  static Directory? resolvePluginDirectory(
    PluginManifest manifest,
    String relativeFolder,
  ) => resolveDirectoryInRoot(manifest.directoryPath, relativeFolder);

  /// File names directly inside a plugin folder; a missing folder returns `[]`.
  static Future<List<String>> listPluginFiles(
    PluginManifest manifest,
    String relativeFolder,
  ) async {
    final directory = resolvePluginDirectory(manifest, relativeFolder);
    if (directory == null) {
      throw PluginSandboxException('目录不在插件目录内或不安全：$relativeFolder');
    }
    if (!await directory.exists()) return const <String>[];
    final names = <String>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File) names.add(p.basename(entity.path));
    }
    names.sort();
    return names;
  }

  static String? _cleanRelative(String relativePath) {
    final normalized = relativePath.trim().replaceAll('\\', '/');
    if (normalized.isEmpty || normalized.startsWith('/')) return null;
    if (p.isAbsolute(normalized) || normalized.contains(':')) return null;
    for (final segment in normalized.split('/')) {
      if (segment.isEmpty || segment == '.' || segment == '..') return null;
    }
    return normalized;
  }

  /// Reads a UTF-8 text file from the sandbox.
  static Future<String> read(String pluginId, String relativePath) async {
    final target = require(pluginId, relativePath);
    final file = File(target);
    if (!await file.exists()) {
      throw PluginSandboxException('文件不存在：$relativePath');
    }
    final length = await file.length();
    if (length > maxReadBytes) {
      throw const PluginSandboxException('文件超过 512 KB 读取上限。');
    }
    return file.readAsString();
  }

  /// Writes UTF-8 [content], creating parent folders; returns written bytes.
  static Future<int> write(
    String pluginId,
    String relativePath,
    String content,
  ) async {
    final target = require(pluginId, relativePath);
    final bytes = utf8.encode(content);
    if (bytes.length > maxWriteBytes) {
      throw const PluginSandboxException('写入内容超过 1 MB 上限。');
    }
    final file = File(target);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
    return bytes.length;
  }

  /// Reads `config.json` for [pluginId]; a missing file is an empty config.
  static Future<Map<String, dynamic>> readConfig(String pluginId) async {
    final target = resolve(pluginId, configFileName);
    if (target == null) {
      throw const PluginSandboxException('无法定位插件配置目录。');
    }
    return _readConfigFile(File(target));
  }

  /// Reads `config.json` from an already resolved data directory.
  ///
  /// Used by the UI renderer, which only receives `plugins_data/<id>` and does
  /// not need to know the plugin id. A missing directory or file returns `{}`.
  static Future<Map<String, dynamic>> readConfigAt(
    String? dataDirectory,
  ) async {
    final root = dataDirectory?.trim();
    if (root == null || root.isEmpty) return <String, dynamic>{};
    return _readConfigFile(File(p.normalize(joinPath(root, configFileName))));
  }

  /// Synchronous directory variant used by [PluginUiRenderer] so a switch can
  /// show its persisted value on the first frame.
  static Map<String, dynamic> readConfigAtSync(String? dataDirectory) {
    final root = dataDirectory?.trim();
    if (root == null || root.isEmpty) return <String, dynamic>{};
    final file = File(p.normalize(joinPath(root, configFileName)));
    if (!file.existsSync()) return <String, dynamic>{};
    if (file.lengthSync() > maxReadBytes) {
      throw const PluginSandboxException('config.json 超过 512 KB 读取上限。');
    }
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        throw const PluginSandboxException('config.json 必须是 JSON 对象。');
      }
      return Map<String, dynamic>.from(decoded);
    } on FormatException catch (error) {
      throw PluginSandboxException('config.json 不是有效 JSON：${error.message}');
    }
  }

  /// Overwrites `config.json` for [pluginId]; returns the written byte count.
  static Future<int> writeConfig(
    String pluginId,
    Map<String, dynamic> config,
  ) => _writeConfigFile(File(require(pluginId, configFileName)), config);

  /// Writes `config.json` into a resolved data directory.
  static Future<int> writeConfigAt(
    String? dataDirectory,
    Map<String, dynamic> config,
  ) async {
    final root = dataDirectory?.trim();
    if (root == null || root.isEmpty) {
      throw const PluginSandboxException('插件数据目录未配置，无法保存 config.json。');
    }
    return _writeConfigFile(
      File(p.normalize(joinPath(root, configFileName))),
      config,
    );
  }

  /// One config value, or [fallback] when the key has not been persisted yet.
  static Future<Object?> readConfigValue(
    String pluginId,
    String key, {
    Object? fallback,
  }) async {
    final config = await readConfig(pluginId);
    return config.containsKey(key) ? config[key] : fallback;
  }

  /// Read-modify-write one key; other keys in the file are preserved.
  static Future<int> updateConfig(
    String pluginId,
    String key,
    Object? value,
  ) async {
    final config = await readConfig(pluginId);
    config[key] = value;
    return writeConfig(pluginId, config);
  }

  /// Directory variant of [updateConfig] used by the UI renderer.
  static Future<int> updateConfigAt(
    String? dataDirectory,
    String key,
    Object? value,
  ) async {
    final config = await readConfigAt(dataDirectory);
    config[key] = value;
    return writeConfigAt(dataDirectory, config);
  }

  static Future<Map<String, dynamic>> _readConfigFile(File file) async {
    if (!await file.exists()) return <String, dynamic>{};
    final length = await file.length();
    if (length > maxReadBytes) {
      throw const PluginSandboxException('config.json 超过 512 KB 读取上限。');
    }
    final text = await file.readAsString();
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const PluginSandboxException('config.json 必须是 JSON 对象。');
      }
      return Map<String, dynamic>.from(decoded);
    } on FormatException catch (error) {
      throw PluginSandboxException('config.json 不是有效 JSON：${error.message}');
    }
  }

  static Future<int> _writeConfigFile(
    File file,
    Map<String, dynamic> config,
  ) async {
    final content = const JsonEncoder.withIndent('  ').convert(config);
    final bytes = utf8.encode(content);
    if (bytes.length > maxWriteBytes) {
      throw const PluginSandboxException('config.json 超过 1 MB 写入上限。');
    }
    await file.parent.create(recursive: true);
    // Write to a sibling temp file first so a crash cannot leave half JSON.
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsString(content, flush: true);
      try {
        await temp.rename(file.path);
      } on FileSystemException {
        // Some Windows filesystems cannot replace an open target via rename.
        await file.writeAsString(content, flush: true);
      }
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } on FileSystemException {
          // Best-effort cleanup; the next write overwrites the temp file.
        }
      }
    }
    return bytes.length;
  }

  /// Sandbox path for a download, with its parent folders created.
  static Future<String> prepareDownload(
    String pluginId,
    String relativePath,
  ) async {
    final target = require(pluginId, relativePath);
    await File(target).parent.create(recursive: true);
    return target;
  }

  /// Like [resolve] but throws instead of returning `null`.
  static String require(String pluginId, String relativePath) {
    final target = resolve(pluginId, relativePath);
    if (target == null) {
      throw PluginSandboxException('路径不在插件数据目录内或不安全：$relativePath');
    }
    return target;
  }
}
