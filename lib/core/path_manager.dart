import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Owns the launcher root selected by the user and derives all managed paths.
///
/// The selected root is stored in `launcher_config.json` next to the
/// executable. Runtime data, configuration, caches and the Minecraft root live
/// below `<root>/Baogan Craft Launcher`.
class PathManager {
  PathManager._();

  static final PathManager instance = PathManager._();

  static const String launcherConfigFileName = 'launcher_config.json';
  static const String configFileName = 'launcher.json';
  static const String baseFolderName = 'Baogan Craft Launcher';
  static const String dataFolderName = 'BGCL';
  static const String gameFolderName = '.minecraft';
  static const String mcmodTitleDatabaseName = 'mcmod_titles.sqlite';
  static const String tagTranslationDatabaseName = 'tag_translations.sqlite';

  String? _selectedRoot;

  String? get selectedRoot => _selectedRoot;
  bool get isConfigured => _selectedRoot != null;

  /// `<root>/Baogan Craft Launcher`
  String? get basePath {
    final root = _selectedRoot;
    return root == null ? null : p.join(root, baseFolderName);
  }

  /// `<root>/Baogan Craft Launcher/BGCL`
  String? get dataRoot {
    final base = basePath;
    return base == null ? null : p.join(base, dataFolderName);
  }

  /// `<root>/Baogan Craft Launcher/.minecraft`
  String? get gameRoot {
    final base = basePath;
    return base == null ? null : p.join(base, gameFolderName);
  }

  String? get gameDir => gameRoot;
  String? get minecraftPath => gameRoot;

  /// `<root>/Baogan Craft Launcher/BGCL/config`
  String? get configDir => _childOfDataRoot('config');

  /// `<root>/Baogan Craft Launcher/BGCL/data`
  String? get dataDir => _childOfDataRoot('data');

  /// `<root>/Baogan Craft Launcher/BGCL/runtime`
  String? get runtimeDir => _childOfDataRoot('runtime');

  /// `<root>/Baogan Craft Launcher/BGCL/cache`
  String? get cacheDir => _childOfDataRoot('cache');

  /// `<root>/Baogan Craft Launcher/BGCL/cache/temp`
  String? get cacheTempDir {
    final cache = cacheDir;
    return cache == null ? null : p.join(cache, 'temp');
  }

  /// `<root>/Baogan Craft Launcher/BGCL/logs`
  String? get logsDir => _childOfDataRoot('logs');

  /// `<root>/Baogan Craft Launcher/BGCL/user_data`
  String? get userDataDir => _childOfDataRoot('user_data');

  /// `<root>/Baogan Craft Launcher/BGCL/user_data/wallpapers`
  String? get userWallpapersDir {
    final userData = userDataDir;
    return userData == null ? null : p.join(userData, 'wallpapers');
  }

  // Backwards-compatible aliases used by existing modules.
  String? get dataDirectory => dataDir;
  String? get cacheDirectory => cacheDir;
  String? get logsDirectory => logsDir;

  String? _childOfDataRoot(String child) {
    final data = dataRoot;
    return data == null ? null : p.join(data, child);
  }

  /// 指路牌固定放在启动器可执行文件同级目录，不写 AppData / Temp。
  File get rootConfigFile {
    final executable = File(Platform.resolvedExecutable);
    return File(p.join(executable.parent.path, launcherConfigFileName));
  }

  /// `<root>/Baogan Craft Launcher/BGCL/config/launcher.json`
  File? get preferencesFile {
    final config = configDir;
    return config == null ? null : File(p.join(config, configFileName));
  }

  /// Persistent Chinese mod-title database. Never place this in `cache`.
  File? get mcmodTitleDatabaseFile {
    final data = dataDir;
    return data == null ? null : File(p.join(data, mcmodTitleDatabaseName));
  }

  /// Persistent mod-tag translation database. Never place this in `cache`.
  File? get tagTranslationDatabaseFile {
    final data = dataDir;
    return data == null ? null : File(p.join(data, tagTranslationDatabaseName));
  }

  /// `<root>/Baogan Craft Launcher/BGCL/runtime/java_runtimes.json`
  File? get javaRuntimeCacheFile {
    final runtime = runtimeDir;
    return runtime == null ? null : File(p.join(runtime, 'java_runtimes.json'));
  }

  Future<void> load() async {
    final file = rootConfigFile;
    if (!await file.exists()) return;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return;

      final rootPath = decoded['rootPath'];
      if (rootPath is! String || rootPath.trim().isEmpty) return;

      _selectedRoot = p.normalize(p.absolute(rootPath.trim()));
      await ensureDirectories();
    } on Exception {
      _selectedRoot = null;
    }
  }

  /// Creates the launcher layout and returns the Minecraft game root.
  Future<String> configure(String rootPath) async {
    final value = rootPath.trim();
    if (value.isEmpty) {
      throw const FormatException('启动器根目录不能为空。');
    }

    final root = p.normalize(p.absolute(value));
    final configFile = rootConfigFile;

    _selectedRoot = root;
    try {
      await ensureDirectories();
      await configFile.parent.create(recursive: true);
      await configFile.writeAsString(
        jsonEncode({'rootPath': root}),
        flush: true,
      );
    } catch (_) {
      _selectedRoot = null;
      rethrow;
    }

    return gameRoot!;
  }

  /// Creates every managed directory. Safe to call repeatedly.
  Future<void> ensureDirectories() async {
    final base = basePath;
    final data = dataRoot;
    final game = gameRoot;

    if (base == null || data == null || game == null) {
      throw const FileSystemException('启动器路径尚未配置。');
    }

    final directories = <String>[
      base,
      data,
      game,
      configDir!,
      dataDir!,
      runtimeDir!,
      cacheDir!,
      cacheTempDir!,
      logsDir!,
      userDataDir!,
      userWallpapersDir!,
    ];

    for (final directory in directories) {
      await Directory(directory).create(recursive: true);
    }
  }

  /// Moves an old database that was incorrectly stored in `cache` to `data`.
  ///
  /// Existing data is never overwritten. If renaming across volumes fails, the
  /// file is copied and only then removed from the old cache location.
  Future<void> migrateLegacyCacheDatabase(String fileName) async {
    final data = dataDir;
    final cache = cacheDir;
    if (data == null || cache == null || fileName.trim().isEmpty) return;

    final sourcePath = p.join(cache, p.basename(fileName));
    final targetPath = p.join(data, p.basename(fileName));
    if (p.equals(sourcePath, targetPath)) return;

    final source = File(sourcePath);
    final target = File(targetPath);
    if (!await source.exists() || await target.exists()) return;

    await target.parent.create(recursive: true);
    try {
      await source.rename(targetPath);
    } on FileSystemException {
      await source.copy(targetPath);
      try {
        await source.delete();
      } on FileSystemException {
        // The important copy is safe; a later launch can retry cleanup.
      }
    }
  }

  /// Deletes only the contents of `cache/temp`.
  ///
  /// The guards below make it impossible for this method to descend into
  /// `data`, `user_data` or any other persistent directory.
  Future<void> clearCacheTemp() async {
    final temp = cacheTempDir;
    final cache = cacheDir;
    final data = dataDir;
    final userData = userDataDir;

    if (temp == null || cache == null) return;

    // cacheTempDir must stay strictly inside cache, never in persistent data.
    if (!p.isWithin(cache, temp)) return;
    if (data != null && _isSameOrInside(temp, data)) return;
    if (userData != null && _isSameOrInside(temp, userData)) return;

    final directory = Directory(temp);
    if (!await directory.exists()) return;

    await for (final entity in directory.list(followLinks: false)) {
      if (!p.isWithin(temp, entity.path)) continue;
      if (data != null && _isSameOrInside(entity.path, data)) continue;
      if (userData != null && _isSameOrInside(entity.path, userData)) continue;
      try {
        // Never follow a link out of cache/temp while deleting.
        if (entity is Link) {
          await entity.delete();
        } else {
          await entity.delete(recursive: true);
        }
      } on FileSystemException {
        // A preview or virus scanner may hold a file briefly. Keep the rest of
        // the cleanup running; the next startup can try this file again.
      }
    }
  }

  static bool _isSameOrInside(String child, String parent) {
    final normalizedChild = p.normalize(p.absolute(child));
    final normalizedParent = p.normalize(p.absolute(parent));
    return normalizedChild == normalizedParent ||
        p.isWithin(normalizedParent, normalizedChild);
  }
}
