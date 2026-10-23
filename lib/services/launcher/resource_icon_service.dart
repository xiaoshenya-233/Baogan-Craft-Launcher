import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:pool/pool.dart';

import '../../core/launcher_log.dart';
import '../../core/path_manager.dart';
import '../../core/path_utils.dart';
import '../network/curseforge_service.dart';
import '../network/models.dart';

/// Kind of on-disk resource whose thumbnail should be extracted.
enum ResourceType { mod, resourcePack, shaderPack, blueprint, saves, world }

/// Extracts `pack.png` / `logo.png` / `icon.png` from mods, resource packs,
/// shader packs and world folders.
///
/// Archive hits are copied to `BGCL/cache/resource_icons/<md5>.png` so the
/// archive is only decompressed once; world folders return their own
/// `icon.png` because it already is a plain file.
class ResourceIconService {
  const ResourceIconService._();

  /// Root and nested icon entries, in order of preference.
  static const List<String> iconNames = <String>[
    'pack.png',
    'logo.png',
    'icon.png',
    'assets/pack.png',
    'assets/logo.png',
    'assets/icon.png',
  ];

  static const String cacheFolderName = 'resource_icons';

  /// Bumped whenever the extraction rules change, so stale caches are ignored.
  static const String cacheVersion = 'v2';

  /// Icon lookups currently running, so one archive is never decoded twice.
  static final Map<String, Future<String?>> _inFlight =
      <String, Future<String?>>{};

  /// Archives that were already scanned without finding an icon.
  static final Set<String> _missing = <String>{};

  /// At most four archives are decompressed simultaneously; a 500-mod pack
  /// would otherwise spawn hundreds of isolates and saturate the CPU.
  static final Pool _extractPool = Pool(4);

  /// Returns an absolute PNG path, or `null` when the resource has no icon.
  static Future<String?> extractResourceIcon(
    String filePath,
    ResourceType type,
  ) {
    final key = '${type.name}|${filePath.trim().toLowerCase()}';
    if (key.isEmpty || _missing.contains(key)) {
      return Future<String?>.value();
    }
    final running = _inFlight[key];
    if (running != null) return running;
    final future = _resolve(filePath, type).then((value) {
      if (value == null) _missing.add(key);
      return value;
    });
    _inFlight[key] = future;
    // The callback must not return a value: returning `_inFlight[key]` here
    // would make `whenComplete` await this very future and never complete.
    future.whenComplete(() {
      _inFlight.remove(key);
    });
    return future;
  }

  /// `.disable` / `.disabled` copies are still valid archives; stripping the
  /// marker keeps one cache entry shared by both states.
  static String _cacheKeyPath(String path) {
    final lower = path.toLowerCase();
    for (final suffix in const <String>['.disabled', '.disable']) {
      if (lower.endsWith(suffix)) {
        return path.substring(0, path.length - suffix.length);
      }
    }
    return path;
  }

  static Future<String?> _resolve(String filePath, ResourceType type) async {
    final path = filePath.trim();
    if (path.isEmpty) return null;
    try {
      // Blueprints are NBT/schematic files without bundled artwork.
      if (type == ResourceType.blueprint) return null;
      // Worlds and saves store their thumbnail next to `level.dat`.
      if (type == ResourceType.world || type == ResourceType.saves) {
        final icon = File(joinPath(path, 'icon.png'));
        return await icon.exists() ? icon.path : null;
      }
      final archiveFile = File(path);
      if (!await archiveFile.exists()) {
        LauncherLog.warning('Resources', '资源文件不存在：$path');
        return null;
      }
      final cacheDirectory = PathManager.instance.cacheDir;
      if (cacheDirectory == null) return null;
      final stat = await archiveFile.stat();
      // A `.disable`/`.disabled` copy is a bit-identical archive, so the cache
      // key ignores the marker and both states share one cached PNG.
      final cacheKey =
          '$cacheVersion|${_cacheKeyPath(archiveFile.absolute.path)}|'
          '${stat.size}|${stat.modified.millisecondsSinceEpoch}';
      final target = File(
        joinPath(
          joinPath(cacheDirectory, cacheFolderName),
          '${md5.convert(utf8.encode(cacheKey))}.png',
        ),
      );
      if (await target.exists()) return target.path;
      LauncherLog.info('Resources', '开始解析资源图标：$path');
      // Large mod jars are decompressed off the UI isolate, at most four at a
      // time so a 500-mod pack cannot saturate the CPU.
      final icon = await _extractPool.withResource(
        () => Isolate.run(() => readArchiveIcon(path)),
      );
      if (icon == null) {
        // Shader archives usually ship no artwork inside the zip, so the
        // launcher falls back to the resource repository cover image.
        if (type == ResourceType.shaderPack) {
          final remote = await _downloadShaderIcon(path, target);
          if (remote != null) return remote;
        }
        LauncherLog.warning('Resources', '未找到图标：$path');
        return null;
      }
      LauncherLog.info(
        'Resources',
        '找到图标：${icon.name}（${icon.bytes.length} 字节，$path）',
      );
      await target.parent.create(recursive: true);
      await target.writeAsBytes(icon.bytes, flush: true);
      LauncherLog.info('Resources', '已缓存资源图标：${target.path}');
      return target.path;
    } on Object catch (error) {
      LauncherLog.warning('Resources', '读取资源图标失败：$path（$error）');
      return null;
    }
  }

  /// Searches the configured CurseForge endpoint for a shader archive and
  /// caches the first cover image it finds under the normal icon cache path.
  ///
  /// The endpoint honours the global resource channel, so turning on the MCIM
  /// mirror also routes this lookup through `mod.mcimirror.top`.
  static Future<String?> _downloadShaderIcon(
    String archivePath,
    File target,
  ) async {
    final query = _shaderSearchQuery(archivePath);
    if (query.isEmpty) return null;
    try {
      final page = await CurseForgeService.search(
        query: query,
        category: DownloadCategory.shaders,
        offset: 0,
        limit: 5,
      );
      String? iconUrl;
      for (final project in page.projects) {
        final url = project.iconUrl?.trim() ?? '';
        if (url.isNotEmpty) {
          iconUrl = url;
          break;
        }
      }
      if (iconUrl == null) return null;
      final bytes = await _downloadIconBytes(iconUrl);
      if (bytes == null || bytes.isEmpty) return null;
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes, flush: true);
      LauncherLog.info(
        'Resources',
        '已缓存光影包联网图标：$iconUrl（搜索词 $query）',
      );
      return target.path;
    } on Object catch (error) {
      LauncherLog.warning('Resources', '光影包联网图标获取失败：$query（$error）');
      return null;
    }
  }

  /// Archive name without `.zip` / `.disable(d)` markers, readable as a query.
  static String _shaderSearchQuery(String path) {
    var name = path.replaceAll(r'\', '/').split('/').last;
    var lower = name.toLowerCase();
    for (final suffix in const <String>['.disabled', '.disable', '.zip']) {
      if (lower.endsWith(suffix)) {
        name = name.substring(0, name.length - suffix.length);
        lower = name.toLowerCase();
      }
    }
    return name.replaceAll(RegExp(r'[_\-\.]+'), ' ').trim();
  }

  static Future<List<int>?> _downloadIconBytes(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'BlockLauncher/26.1alpha1.1 (shader icon)';
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// Icon entry plus its bytes, returned from the extraction isolate.
typedef ArchiveIcon = ({String name, Uint8List bytes});

/// Reads the first matching icon entry from a jar/zip.
///
/// Runs inside [Isolate.run], so it must not touch launcher state and uses
/// synchronous IO only. Matching is case-insensitive, so `pack.PNG` works.
ArchiveIcon? readArchiveIcon(String filePath) {
  try {
    final bytes = File(filePath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    final entries = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      entries[_normalizeEntry(file.name)] = file;
    }
    for (final name in _iconCandidates(entries)) {
      final content = entries[name]?.content;
      if (content is List<int> && content.isNotEmpty) {
        return (name: name, bytes: Uint8List.fromList(content));
      }
    }
  } on Object {
    // A corrupt or locked archive simply has no icon.
  }
  return null;
}

/// Candidate entries in preference order: fixed names, then the path declared
/// by `fabric.mod.json` / `META-INF/mods.toml`, then a shallow `/icon.png`.
Iterable<String> _iconCandidates(Map<String, ArchiveFile> entries) sync* {
  for (final name in ResourceIconService.iconNames) {
    if (entries.containsKey(name)) yield name;
  }
  final declared = _declaredLogoPath(entries);
  if (declared != null && entries.containsKey(declared)) yield declared;
  final nested =
      entries.keys
          .where(
            (name) =>
                name.endsWith('/icon.png') ||
                name.endsWith('/logo.png') ||
                name.endsWith('/pack.png'),
          )
          .toList()
        ..sort(
          (left, right) =>
              left.split('/').length.compareTo(right.split('/').length),
        );
  for (final name in nested.take(3)) {
    yield name;
  }
}

/// Reads `logo` / `logoFile` from the loader metadata files.
String? _declaredLogoPath(Map<String, ArchiveFile> entries) {
  final fabricJson = _entryText(entries['fabric.mod.json']);
  if (fabricJson != null) {
    try {
      final decoded = jsonDecode(fabricJson);
      if (decoded is Map) {
        final logo = decoded['logo'];
        if (logo is String && logo.trim().isNotEmpty) {
          return _normalizeEntry(logo.trim());
        }
        if (logo is Map && logo['logo'] is String) {
          return _normalizeEntry((logo['logo'] as String).trim());
        }
      }
    } on FormatException {
      // Malformed metadata: fall through to the other strategies.
    }
  }
  final toml =
      _entryText(entries['meta-inf/mods.toml']) ??
      _entryText(entries['meta-inf/neoforge.mods.toml']);
  if (toml != null) {
    final match = RegExp(
      r'logoFile\s*=\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(toml);
    final value = match?.group(1)?.trim();
    if (value != null && value.isNotEmpty) return _normalizeEntry(value);
  }
  return null;
}

String? _entryText(ArchiveFile? file) {
  if (file == null) return null;
  final content = file.content;
  if (content is! List<int>) return null;
  return utf8.decode(content, allowMalformed: true);
}

String _normalizeEntry(String name) {
  var value = name.replaceAll(r'\', '/').toLowerCase();
  while (value.startsWith('./')) {
    value = value.substring(2);
  }
  while (value.startsWith('/')) {
    value = value.substring(1);
  }
  return value;
}
