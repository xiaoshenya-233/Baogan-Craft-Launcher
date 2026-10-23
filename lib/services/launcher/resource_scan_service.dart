import 'dart:io';

import '../../core/launcher_log.dart';
import '../../core/path_utils.dart';
import 'resource_icon_service.dart';

/// One entry shown in the client "游戏资源大纲" list.
class GameResource {
  const GameResource({
    required this.name,
    required this.path,
    required this.category,
    required this.enabled,
    this.isDirectory = false,
  });

  /// Display name without the `.disabled` marker or the archive extension.
  final String name;

  /// Absolute path on disk (including `.disabled` when the entry is disabled).
  final String path;
  final ResourceType category;
  final bool enabled;
  final bool isDirectory;
}

/// Scans the per-client resource folders (`mods`, `resourcepacks`,
/// `shaderpacks`, schematics) into one flat list.
///
/// Disabled entries keep the `.disabled` suffix, exactly like Minecraft does,
/// so enabling/disabling is a pure rename.
class ResourceScanService {
  const ResourceScanService._();

  /// Disabling writes the PCL2-compatible `.disable` marker; reading accepts
  /// the older `.disabled` spelling produced by other launchers as well.
  static const String disableSuffix = '.disable';
  static const List<String> disableSuffixes = <String>['.disabled', '.disable'];

  static const List<ResourceType> categories = <ResourceType>[
    ResourceType.mod,
    ResourceType.resourcePack,
    ResourceType.shaderPack,
    ResourceType.saves,
  ];

  static const Set<String> modExtensions = <String>{'.jar'};
  static const Set<String> packExtensions = <String>{'.zip'};
  static const Set<String> blueprintExtensions = <String>{
    '.litematic',
    '.schem',
    '.schematic',
    '.nbt',
  };

  /// Scans every supported category of one client directory.
  static Future<List<GameResource>> scanAll(String clientDirectory) async {
    final resources = <GameResource>[];
    for (final category in categories) {
      resources.addAll(await scanCategory(clientDirectory, category));
    }
    return resources;
  }

  /// Scans a single category; a missing folder simply yields no entries.
  static Future<List<GameResource>> scanCategory(
    String clientDirectory,
    ResourceType category,
  ) async {
    final directory = clientDirectory.trim();
    if (directory.isEmpty) return const <GameResource>[];
    try {
      return switch (category) {
        ResourceType.mod => await scanFolder(
          joinPath(directory, 'mods'),
          category,
          extensions: modExtensions,
        ),
        ResourceType.resourcePack => await scanFolder(
          joinPath(directory, 'resourcepacks'),
          category,
          extensions: packExtensions,
          allowDirectories: true,
        ),
        ResourceType.shaderPack => await scanFolder(
          joinPath(directory, 'shaderpacks'),
          category,
          extensions: packExtensions,
          allowDirectories: true,
        ),
        ResourceType.blueprint => await scanBlueprints(directory),
        ResourceType.saves => await scanSaves(directory),
        ResourceType.world => const <GameResource>[],
      };
    } on FileSystemException catch (error) {
      LauncherLog.warning(
        'Resources',
        '扫描资源失败：$directory（${error.message}）',
      );
      return const <GameResource>[];
    }
  }

  /// Lists every world folder under `<client>/saves`.
  static Future<List<GameResource>> scanSaves(String clientDirectory) async {
    final directory = Directory(joinPath(clientDirectory, 'saves'));
    if (!await directory.exists()) return const <GameResource>[];
    final saves = <GameResource>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = _fileName(entity.path);
      if (name.isEmpty || name.startsWith('.')) continue;
      saves.add(
        GameResource(
          name: name,
          path: entity.path,
          category: ResourceType.saves,
          enabled: true,
          isDirectory: true,
        ),
      );
    }
    saves.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    return saves;
  }

  /// Lists one resource folder, honouring the `.disabled` suffix.
  static Future<List<GameResource>> scanFolder(
    String directoryPath,
    ResourceType category, {
    required Set<String> extensions,
    bool allowDirectories = false,
  }) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) return const <GameResource>[];
    final resources = <GameResource>[];
    await for (final entity in directory.list(followLinks: false)) {
      final fileName = _fileName(entity.path);
      if (fileName.isEmpty || fileName.startsWith('.')) continue;
      final isDirectory = entity is Directory;
      if (isDirectory && !allowDirectories) continue;
      final parsed = parseResourceFileName(fileName);
      final isEnabled = !parsed.disabled;
      final effectiveName = parsed.name;
      if (!isDirectory && !_matchesExtension(effectiveName, extensions)) {
        continue;
      }
      resources.add(
        GameResource(
          name: effectiveName,
          path: entity.path,
          category: category,
          enabled: isEnabled,
          isDirectory: isDirectory,
        ),
      );
    }
    resources.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    return resources;
  }

  /// Blueprints live in `schematics/` and `config/litematica/`; if neither
  /// exists (no schematic mod installed) the result is empty, never an error.
  static Future<List<GameResource>> scanBlueprints(
    String clientDirectory,
  ) async {
    final roots = <String>[
      joinPath(clientDirectory, 'schematics'),
      joinPath(joinPath(clientDirectory, 'config'), 'litematica'),
    ];
    final seen = <String>{};
    final resources = <GameResource>[];
    for (final root in roots) {
      final directory = Directory(root);
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final fileName = _fileName(entity.path);
        if (fileName.isEmpty || fileName.startsWith('.')) continue;
        final parsed = parseResourceFileName(fileName);
        final isEnabled = !parsed.disabled;
        final effectiveName = parsed.name;
        if (!_matchesExtension(effectiveName, blueprintExtensions)) continue;
        if (!seen.add(entity.path)) continue;
        resources.add(
          GameResource(
            name: effectiveName,
            path: entity.path,
            category: ResourceType.blueprint,
            enabled: isEnabled,
          ),
        );
      }
    }
    resources.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    if (resources.isNotEmpty) {
      LauncherLog.info('Resources', '扫描到 ${resources.length} 个投影蓝图');
    }
    return resources;
  }

  static bool _matchesExtension(String name, Set<String> extensions) {
    final lower = name.toLowerCase();
    for (final extension in extensions) {
      if (lower.endsWith(extension)) return true;
    }
    return false;
  }

  /// Splits `.jar` / `.jar.disable` / `.jar.disabled` into the real name
  /// (`Sodium.jar`) and the disabled flag. Matching is case-insensitive.
  static ({String name, bool disabled}) parseResourceFileName(
    String fileName,
  ) {
    final lower = fileName.toLowerCase();
    for (final suffix in disableSuffixes) {
      if (lower.endsWith(suffix)) {
        return (
          name: fileName.substring(0, fileName.length - suffix.length),
          disabled: true,
        );
      }
    }
    return (name: fileName, disabled: false);
  }

  /// Removes any disable marker from a full path.
  static String enabledPathOf(String path) {
    final lower = path.toLowerCase();
    for (final suffix in disableSuffixes) {
      if (lower.endsWith(suffix)) {
        return path.substring(0, path.length - suffix.length);
      }
    }
    return path;
  }

  /// Appends the `.disable` marker, normalising an existing `.disabled` path.
  static String disabledPathOf(String path) =>
      '${enabledPathOf(path)}$disableSuffix';

  /// Last path segment, tolerating both `/` and `\` separators.
  static String _fileName(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? normalized : parts.last;
  }
}
