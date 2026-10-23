// Filesystem scanning, version parsing and client maintenance helpers.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../../core/launcher_log.dart';
import '../../core/path_utils.dart';
import 'version_models.dart';

Future<({String? path, String content, bool truncated})> readMinecraftLatestLog(
  String gameDirectory, {
  int maxBytes = 240 * 1024,
}) async {
  final logsDirectory = Directory(
    '$gameDirectory${Platform.pathSeparator}logs',
  );
  File? logFile = File(
    '${logsDirectory.path}${Platform.pathSeparator}latest.log',
  );
  if (!await logFile.exists()) {
    logFile = null;
    if (await logsDirectory.exists()) {
      final candidates = <({File file, DateTime modified})>[];
      await for (final entity in logsDirectory.list(followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.log')) {
          candidates.add((file: entity, modified: await entity.lastModified()));
        }
      }
      if (candidates.isNotEmpty) {
        candidates.sort(
          (left, right) => right.modified.compareTo(left.modified),
        );
        logFile = candidates.first.file;
      }
    }
  }
  if (logFile == null || !await logFile.exists()) {
    return (path: null, content: '', truncated: false);
  }
  // Only the tail is read from disk, so a huge log cannot exhaust memory.
  final tail = await readLogTail(logFile.path, maxBytes: maxBytes);
  return (path: logFile.path, content: tail.content, truncated: tail.truncated);
}

List<String> _versionLibraryNames(Map<String, dynamic> config) {
  final rawLibraries = config['libraries'];
  if (rawLibraries is! List) return const <String>[];
  return rawLibraries
      .whereType<Map<String, dynamic>>()
      .map((library) => library['name'])
      .whereType<String>()
      .where((name) => name.isNotEmpty)
      .toList();
}

/// Flattens normal `arguments.game` / `arguments.jvm` entries and the legacy
/// `minecraftArguments` string, ignoring argument rules (they do not affect
/// metadata discovery).
List<String> _versionArgumentValues(Map<String, dynamic> config) {
  final values = <String>[];

  void add(dynamic raw) {
    if (raw is String) {
      values.add(raw);
    } else if (raw is List) {
      for (final item in raw) {
        add(item);
      }
    } else if (raw is Map) {
      add(raw['value']);
    }
  }

  final arguments = config['arguments'];
  if (arguments is Map) {
    add(arguments['game']);
    add(arguments['jvm']);
  }
  final legacy = config['minecraftArguments'];
  if (legacy is String && legacy.trim().isNotEmpty) {
    final pattern = RegExp(r'"([^"]*)"|(\S+)');
    for (final match in pattern.allMatches(legacy)) {
      values.add(match.group(1) ?? match.group(2)!);
    }
  }
  return values;
}

String? _argumentValue(List<String> arguments, String flag) {
  final normalizedFlag = flag.toLowerCase();
  for (var index = 0; index + 1 < arguments.length; index++) {
    if (arguments[index].toLowerCase() == normalizedFlag) {
      final value = arguments[index + 1].trim();
      if (value.isNotEmpty) return value;
    }
  }
  return null;
}

({String group, String artifact, String version})? _mavenCoordinates(
  String name,
) {
  final withoutExtension = name.split('@').first;
  final parts = withoutExtension.split(':');
  if (parts.length < 3) return null;
  return (
    group: parts[0].toLowerCase(),
    artifact: parts[1].toLowerCase(),
    version: parts[2],
  );
}

bool _looksLikeMinecraftVersion(String value) {
  final trimmed = value.trim();
  if (RegExp(
    r'^\d+\.\d+(?:\.\d+)?(?:-(?:pre|rc)\d+)?$',
    caseSensitive: false,
  ).hasMatch(trimmed)) {
    return true;
  }
  return RegExp(r'^\d{2}w\d{2}[a-z]$', caseSensitive: false).hasMatch(trimmed);
}

/// Extracts the Minecraft version from loader-specific profile IDs such as
/// `fabric-loader-0.16.9-1.21.1`, `quilt-loader-0.26.0-1.21.1` and
/// `1.20.1-forge-47.2.0`.
String? _minecraftVersionFromLoaderId(String value) {
  final trimmed = value.trim();
  final forge = RegExp(
    r'^(\d+\.\d+(?:\.\d+)?)-forge-(.+)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (forge != null && _looksLikeMinecraftVersion(forge.group(1)!)) {
    return forge.group(1);
  }
  final fabric = RegExp(
    r'^fabric-loader-[^-]+-(.+)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (fabric != null && _looksLikeMinecraftVersion(fabric.group(1)!)) {
    return fabric.group(1);
  }
  final quilt = RegExp(
    r'^quilt-loader-[^-]+-(.+)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (quilt != null && _looksLikeMinecraftVersion(quilt.group(1)!)) {
    return quilt.group(1);
  }
  final prefixedFabric = RegExp(
    r'^(\d+\.\d+(?:\.\d+)?)-fabric-loader-.+$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (prefixedFabric != null) return prefixedFabric.group(1);
  final prefixedQuilt = RegExp(
    r'^(\d+\.\d+(?:\.\d+)?)-quilt-loader-.+$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (prefixedQuilt != null) return prefixedQuilt.group(1);
  return null;
}

/// PCL2-style metadata discovery: inheritance chain, then merged libraries,
/// then launch arguments. This works even when the client directory was
/// renamed to something like `我的整合包` and its JSON id has no version text.
VersionIdentity inferVersionIdentity({
  required String folderName,
  required String configId,
  required Map<String, dynamic> config,
  required List<String> chainIds,
}) {
  final identifiers = <String>[
    folderName,
    configId,
    ...chainIds,
  ].where((value) => value.trim().isNotEmpty).toList();
  final libraryNames = _versionLibraryNames(config);
  final argumentValues = _versionArgumentValues(config);
  final mainClass = config['mainClass'] is String
      ? (config['mainClass'] as String).toLowerCase()
      : '';
  final idText = identifiers.join(' ').toLowerCase();
  final libraryText = libraryNames.join(' ').toLowerCase();

  final neoForgeArgument = _argumentValue(
    argumentValues,
    '--fml.neoForgeVersion',
  );
  final forgeArgument = _argumentValue(argumentValues, '--fml.forgeVersion');
  final minecraftArgument = _argumentValue(argumentValues, '--fml.mcVersion');

  bool hasLibrary(String group, Set<String> artifacts) {
    for (final name in libraryNames) {
      final coordinates = _mavenCoordinates(name);
      if (coordinates != null &&
          coordinates.group == group &&
          artifacts.contains(coordinates.artifact)) {
        return true;
      }
    }
    return false;
  }

  String? libraryVersion(String group, Set<String> artifacts) {
    String? result;
    for (final name in libraryNames) {
      final coordinates = _mavenCoordinates(name);
      if (coordinates != null &&
          coordinates.group == group &&
          artifacts.contains(coordinates.artifact)) {
        result = coordinates.version;
      }
    }
    return result;
  }

  final hasNeoForge =
      neoForgeArgument != null ||
      hasLibrary('net.neoforged', {'neoforge'}) ||
      libraryText.contains('net.neoforged') ||
      idText.contains('neoforge') ||
      mainClass.contains('neoforged');
  final hasForge =
      forgeArgument != null ||
      hasLibrary('net.minecraftforge', {
        'forge',
        'fmlloader',
        'fmlcore',
        'javafmllanguage',
        'lowcodelanguage',
        'mclanguage',
      }) ||
      libraryText.contains('net.minecraftforge') ||
      (idText.contains('forge') && !idText.contains('neoforge'));
  final hasFabric =
      hasLibrary('net.fabricmc', {'fabric-loader'}) ||
      libraryText.contains('fabric-loader') ||
      idText.contains('fabric-loader') ||
      mainClass.contains('net.fabricmc.loader');
  final hasQuilt =
      hasLibrary('org.quiltmc', {'quilt-loader'}) ||
      libraryText.contains('quilt-loader') ||
      idText.contains('quilt-loader');
  final hasLiteLoader =
      hasLibrary('com.mumfrey', {'liteloader'}) ||
      libraryText.contains('liteloader') ||
      idText.contains('liteloader');
  final hasOptiFine =
      libraryText.contains('optifine') || idText.contains('optifine');

  String? loaderType;
  String? loaderVersion;
  if (hasNeoForge) {
    loaderType = 'NeoForge';
    loaderVersion =
        libraryVersion('net.neoforged', {'neoforge'}) ??
        neoForgeArgument ??
        RegExp(
          r'neoforge[-_:]([0-9][\w.+-]*)',
          caseSensitive: false,
        ).firstMatch(idText)?.group(1);
  } else if (hasForge) {
    loaderType = 'Forge';
    final libraryLoaderVersion =
        libraryVersion('net.minecraftforge', {
          'forge',
          'fmlloader',
          'fmlcore',
          'javafmllanguage',
          'lowcodelanguage',
          'mclanguage',
        }) ??
        '';
    final forgeSuffix = libraryLoaderVersion.contains('-')
        ? libraryLoaderVersion.split('-').last
        : libraryLoaderVersion;
    loaderVersion =
        (forgeSuffix.isEmpty ? null : forgeSuffix) ??
        forgeArgument ??
        RegExp(
          r'forge[-_:]([0-9][\w.+-]*)',
          caseSensitive: false,
        ).firstMatch(idText)?.group(1);
  } else if (hasFabric) {
    loaderType = 'Fabric';
    loaderVersion =
        libraryVersion('net.fabricmc', {'fabric-loader'}) ??
        RegExp(
          r'fabric-loader-([0-9][0-9.]*)',
          caseSensitive: false,
        ).firstMatch(idText)?.group(1);
  } else if (hasQuilt) {
    loaderType = 'Quilt';
    loaderVersion =
        libraryVersion('org.quiltmc', {'quilt-loader'}) ??
        RegExp(
          r'quilt-loader-([0-9][0-9.]*)',
          caseSensitive: false,
        ).firstMatch(idText)?.group(1);
  } else if (hasLiteLoader) {
    loaderType = 'LiteLoader';
    loaderVersion =
        libraryVersion('com.mumfrey', {'liteloader'}) ??
        RegExp(
          r'liteloader[-_:]([0-9][\w.+-]*)',
          caseSensitive: false,
        ).firstMatch(idText)?.group(1);
  } else if (hasOptiFine) {
    loaderType = 'OptiFine';
    loaderVersion = RegExp(
      r'optifine[-_:]([a-z0-9_.+-]+)',
      caseSensitive: false,
    ).firstMatch(idText)?.group(1);
  }

  String? minecraftVersion;
  final explicitMinecraftVersion = config['minecraftVersion'];
  if (explicitMinecraftVersion is String &&
      _looksLikeMinecraftVersion(explicitMinecraftVersion)) {
    minecraftVersion = explicitMinecraftVersion.trim();
  }

  if (minecraftVersion == null) {
    // The deepest inherited profile is usually the vanilla version. Iterate
    // from the root towards the child so a loader profile cannot hide it.
    for (final identifier in chainIds.reversed) {
      final candidate =
          _minecraftVersionFromLoaderId(identifier) ??
          (_looksLikeMinecraftVersion(identifier) ? identifier.trim() : null);
      if (candidate != null) {
        minecraftVersion = candidate;
        break;
      }
    }
  }

  if (minecraftVersion == null) {
    for (final name in libraryNames) {
      final coordinates = _mavenCoordinates(name);
      if (coordinates == null) continue;
      if (coordinates.group == 'net.minecraftforge' &&
          coordinates.artifact == 'forge' &&
          coordinates.version.contains('-')) {
        final candidate = coordinates.version.split('-').first;
        if (_looksLikeMinecraftVersion(candidate)) {
          minecraftVersion = candidate;
          break;
        }
      }
    }
  }

  if (minecraftVersion == null &&
      minecraftArgument != null &&
      _looksLikeMinecraftVersion(minecraftArgument)) {
    minecraftVersion = minecraftArgument.trim();
  }

  if (minecraftVersion == null) {
    for (final identifier in identifiers) {
      final candidate =
          _minecraftVersionFromLoaderId(identifier) ??
          (_looksLikeMinecraftVersion(identifier) ? identifier.trim() : null);
      if (candidate != null) {
        minecraftVersion = candidate;
        break;
      }
    }
  }

  return VersionIdentity(
    minecraftVersion: minecraftVersion,
    loaderType: loaderType,
    loaderVersion: loaderVersion,
  );
}

/// Reads the child id followed by every `inheritsFrom` id. Parent IDs are
/// retained even when their JSON file is missing, because they can still
/// identify a loader or Minecraft version.
Future<List<String>> versionInheritanceIds(
  File jsonFile,
  Directory versionsDirectory,
) async {
  final ids = <String>[];
  final visited = <String>{};
  var file = jsonFile;
  while (true) {
    final key = file.absolute.path.toLowerCase();
    if (!visited.add(key) || !await file.exists()) break;
    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map<String, dynamic>) decoded = raw;
    } on FormatException {
      decoded = null;
    } on FileSystemException {
      decoded = null;
    }
    if (decoded == null) break;
    final id = decoded['id'];
    if (id is String && id.trim().isNotEmpty && !ids.contains(id.trim())) {
      ids.add(id.trim());
    }
    final parent = decoded['inheritsFrom'];
    if (parent is! String || parent.trim().isEmpty) break;
    final parentId = parent.trim();
    if (!ids.contains(parentId)) ids.add(parentId);
    file = File(
      '${versionsDirectory.path}${Platform.pathSeparator}$parentId'
      '${Platform.pathSeparator}$parentId.json',
    );
  }
  return ids;
}

String replaceIgnoreListClientJar({
  required String argument,
  required String versionName,
  required String clientJarName,
}) {
  if (!argument.startsWith('-DignoreList=')) return argument;
  return argument.replaceAll('$versionName.jar', clientJarName);
}

bool isPathInsideDirectory(String path, String directory) =>
    isPathInside(path, directory);

/// Deletes only one client folder below `<minecraftPath>/versions`.
Future<void> deleteMinecraftClientDirectory({
  required String minecraftPath,
  required String clientPath,
}) async {
  final versionsRoot = '$minecraftPath${Platform.pathSeparator}versions';
  if (!isPathInsideDirectory(clientPath, versionsRoot)) {
    throw ArgumentError.value(
      clientPath,
      'clientPath',
      '客户端目录必须位于 versions 文件夹内。',
    );
  }
  final directory = Directory(clientPath);
  if (!await directory.exists()) {
    throw FileSystemException('客户端目录不存在。', clientPath);
  }
  await directory.delete(recursive: true);
}

/// Rewrites NeoForge's embedded Maven URLs to the official Forge CDN.
///
/// NeoForge installer JARs are ZIP files containing root/nested JSON metadata.
/// The original installer is not modified; a sibling `<name>-cdn.jar` is
/// returned only when at least one URL was replaced.
Future<File> applyNeoForgeCdnMirror(File installer) async {
  const upstream = 'maven.neoforged.net';
  const cdn = 'neoforged.forgecdn.net';
  final sourceBytes = await installer.readAsBytes();
  final decoded = ZipDecoder().decodeBytes(sourceBytes);
  final rewritten = Archive();
  var replacedFiles = 0;

  for (final file in decoded) {
    if (file.isFile) {
      final content = file.content;
      if (content is List<int>) {
        String? text;
        try {
          text = utf8.decode(content);
        } on FormatException {
          text = null;
        }
        if (text != null && text.contains(upstream)) {
          final updatedText = text
              .replaceAll('https://$upstream', 'https://$cdn')
              .replaceAll('http://$upstream', 'https://$cdn');
          if (updatedText != text) {
            final updatedBytes = utf8.encode(updatedText);
            rewritten.addFile(
              ArchiveFile(file.name, updatedBytes.length, updatedBytes),
            );
            replacedFiles++;
            continue;
          }
        }
      }
    }
    rewritten.addFile(file);
  }

  if (replacedFiles == 0) return installer;
  final encoded = ZipEncoder().encode(rewritten);
  if (encoded == null) {
    throw const FormatException('无法重新打包 NeoForge 安装器。');
  }
  final baseName = lastPathSegment(installer.path);
  final stem = baseName.toLowerCase().endsWith('.jar')
      ? baseName.substring(0, baseName.length - 4)
      : baseName;
  final target = File(
    '${installer.parent.path}${Platform.pathSeparator}$stem-cdn.jar',
  );
  if (await target.exists()) await target.delete();
  await target.writeAsBytes(encoded, flush: true);
  LauncherLog.info(
    'Installer',
    '已将 NeoForge 安装器中的 $replacedFiles 个元数据文件的下载域名'
        '替换为 $cdn',
  );
  return target;
}

List<String> deduplicateClassPathEntries(Iterable<String> entries) {
  final seen = <String>{};
  final unique = <String>[];
  for (final entry in entries) {
    if (entry.trim().isEmpty) continue;
    final key = Platform.isWindows ? entry.toLowerCase() : entry;
    if (seen.add(key)) unique.add(entry);
  }
  return unique;
}

/// Builds the list of candidate client JAR paths for a version.
///
/// A version folder's name, its JSON `id`, the optional `jar` field and the
/// inherited vanilla version can all differ, so every common layout is tried.
List<String> minecraftClientJarCandidates({
  required String versionDirectory,
  required String minecraftPath,
  required String versionId,
  required Map<String, dynamic> config,
}) {
  final folderName = lastPathSegment(versionDirectory);
  final configId = config['id'] is String ? config['id'] as String : versionId;
  final jarName = config['jar'] is String ? config['jar'] as String : configId;
  final inherited = config['inheritsFrom'] is String
      ? config['inheritsFrom'] as String
      : null;
  final versionsRoot = joinPath(minecraftPath, 'versions');
  return <String>{
    joinPath(versionDirectory, '$folderName.jar'),
    joinPath(versionDirectory, '$versionId.jar'),
    joinPath(versionDirectory, '$configId.jar'),
    joinPath(versionDirectory, '$jarName.jar'),
    joinPath(versionDirectory, 'client.jar'),
    joinPath(joinPath(versionsRoot, jarName), '$jarName.jar'),
    if (inherited != null)
      joinPath(joinPath(versionsRoot, inherited), '$inherited.jar'),
  }.toList();
}

