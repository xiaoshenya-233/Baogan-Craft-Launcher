// Minecraft version metadata parsing, artifact resolution and shared helpers.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../../core/launcher_log.dart';
import '../../core/path_utils.dart';
import '../network/api_service.dart';

const String bmclapiHost = 'bmclapi2.bangbang93.com';
const Duration minecraftRequestTimeout = Duration(seconds: 30);
/// Matches the SHA-1 hash of a Minecraft asset object.
///
/// Compiled once: the asset index of a modern client contains thousands of
/// entries and the pattern is checked for every one of them.
final RegExp sha1HexPattern = RegExp(r'^[a-fA-F0-9]{40}$');

enum MinecraftDownloadSource {
  mojang('Mojang 官方'),
  bmclapi('BMCLAPI 加速');

  const MinecraftDownloadSource(this.label);

  final String label;
}

Future<Map<String, dynamic>> installerLoadVersionConfig(
  File file,
  Directory versionsDirectory,
  Set<String> loading,
) async {
  final normalizedPath = file.absolute.path.toLowerCase();
  if (!loading.add(normalizedPath)) {
    throw FormatException('版本配置继承循环：${file.path}');
  }
  try {
    if (!await file.exists()) {
      throw FileSystemException('找不到版本配置文件。', file.path);
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('版本配置格式无效：${file.path}');
    }
    final merged = <String, dynamic>{};
    Map<String, dynamic>? parentConfig;
    final parentId = decoded['inheritsFrom'];
    if (parentId is String && parentId.isNotEmpty) {
      final parentFile = File(
        joinPath(
          joinPath(versionsDirectory.path, parentId),
          '$parentId.json',
        ),
      );
      parentConfig = await installerLoadVersionConfig(
        parentFile,
        versionsDirectory,
        loading,
      );
      merged.addAll(parentConfig);
    }
    merged.addAll(decoded);
    final parentLibraries = parentConfig?['libraries'];
    final childLibraries = decoded['libraries'];
    if (parentLibraries is List && childLibraries is List) {
      merged['libraries'] = [...parentLibraries, ...childLibraries];
    }
    final parentArguments = parentConfig?['arguments'];
    final childArguments = decoded['arguments'];
    if (parentArguments is Map<String, dynamic> &&
        childArguments is Map<String, dynamic>) {
      merged['arguments'] = {
        ...parentArguments,
        ...childArguments,
        for (final key in ['jvm', 'game'])
          if (parentArguments[key] is List && childArguments[key] is List)
            key: [
              ...(parentArguments[key] as List),
              ...(childArguments[key] as List),
            ],
      };
    }
    return merged;
  } finally {
    loading.remove(normalizedPath);
  }
}

String? installerNativeClassifier(Map<String, dynamic> library) {
  final natives = library['natives'];
  if (natives is! Map<String, dynamic>) return null;
  final nativePattern =
      natives[Platform.isWindows
          ? 'windows'
          : Platform.isMacOS
          ? 'osx'
          : 'linux'];
  if (nativePattern is! String) return null;
  final architecture =
      Platform.environment['PROCESSOR_ARCHITECTURE']?.toLowerCase() ?? '';
  return nativePattern.replaceAll(
    r'${arch}',
    architecture.contains('86') && !architecture.contains('64') ? '32' : '64',
  );
}

bool installerMatchesRules(dynamic rules) {
  if (rules is! List) return true;
  var allowed = false;
  final osName = Platform.isWindows
      ? 'windows'
      : Platform.isMacOS
      ? 'osx'
      : 'linux';
  for (final rawRule in rules) {
    if (rawRule is! Map<String, dynamic>) continue;
    final os = rawRule['os'];
    final ruleOs = os is Map<String, dynamic> ? os['name'] : null;
    if (ruleOs != null && ruleOs != osName) continue;
    final osArch = os is Map<String, dynamic> ? os['arch'] : null;
    final currentArch =
        Platform.environment['PROCESSOR_ARCHITECTURE']?.toLowerCase() ?? '';
    if (osArch is String && !currentArch.contains(osArch.toLowerCase())) {
      continue;
    }
    final osVersion = os is Map<String, dynamic> ? os['version'] : null;
    if (osVersion is String &&
        !RegExp(osVersion).hasMatch(Platform.operatingSystemVersion)) {
      continue;
    }
    final requiredFeatures = rawRule['features'];
    if (requiredFeatures is Map<String, dynamic> &&
        requiredFeatures.values.any((value) => value != false)) {
      continue;
    }
    final action = rawRule['action'];
    if (action == 'allow') allowed = true;
    if (action == 'disallow') allowed = false;
  }
  return allowed;
}

/// Returns the last non-empty segment of [path], tolerating both `/` and `\`.
String installerLastPathSegment(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.split('/').where((part) => part.isNotEmpty).last;
}

const Map<String, dynamic> defaultLauncherProfiles = <String, dynamic>{
  'profiles': <String, dynamic>{},
  'selectedProfile': '',
  'clientToken': '',
  'authenticationDatabase': <String, dynamic>{},
  'launcherVersion': <String, dynamic>{'name': '1.0', 'format': 21},
};

String encodeLauncherProfiles(Map<String, dynamic> profiles) =>
    '${JsonEncoder.withIndent('  ').convert(profiles)}\n';

/// Ensures Fabric's installer can find a valid launcher profile file.
///
/// Existing valid profiles and unknown fields are preserved. Only missing
/// fields are filled in, and only an unreadable/invalid file is rebuilt.
Future<void> ensureLauncherProfiles(String minecraftDirectory) async {
  final directory = Directory(minecraftDirectory);
  await directory.create(recursive: true);

  final file = File(joinPath(directory.path, 'launcher_profiles.json'));
  if (await file.exists()) {
    try {
      final contents = await file.readAsString();
      final decoded = jsonDecode(
        contents.startsWith('\uFEFF') ? contents.substring(1) : contents,
      );
      if (decoded is Map<String, dynamic>) {
        var changed = false;
        if (decoded['profiles'] is! Map) {
          decoded['profiles'] = <String, dynamic>{};
          changed = true;
        }
        for (final entry in defaultLauncherProfiles.entries) {
          if (!decoded.containsKey(entry.key)) {
            decoded[entry.key] = entry.value;
            changed = true;
          }
        }
        if (changed) {
          await file.writeAsString(
            encodeLauncherProfiles(decoded),
            flush: true,
          );
        }
        return;
      }
    } on FormatException {
      // Invalid JSON is rebuilt below with the minimal valid structure.
    }
    LauncherLog.warning(
      'Installer',
      'launcher_profiles.json 内容无效，正在重建：${file.path}',
    );
  }

  await file.writeAsString(
    encodeLauncherProfiles(
      Map<String, dynamic>.from(defaultLauncherProfiles),
    ),
    flush: true,
  );
}

String modpackVersionKey(String value) =>
    Platform.isWindows ? value.toLowerCase() : value;

bool isSafeVersionFolderName(String value) {
  final name = value.trim();
  return name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.contains('/') &&
      !name.contains('\\') &&
      !RegExp(r'^[A-Za-z]:').hasMatch(name);
}

bool sameModpackPath(String first, String second) =>
    modpackVersionKey(File(first).absolute.path) ==
    modpackVersionKey(File(second).absolute.path);

List<dynamic> dedupeModpackLibraries(List<dynamic> libraries) {
  final seen = <String>{};
  final result = <dynamic>[];
  for (final library in libraries) {
    if (seen.add(jsonEncode(library))) result.add(library);
  }
  return result;
}

Map<String, dynamic> dedupeModpackArguments(Map<String, dynamic> arguments) {
  final result = Map<String, dynamic>.from(arguments);
  for (final key in ['game', 'jvm']) {
    final values = arguments[key];
    if (values is! List) continue;
    final seen = <String>{};
    result[key] = [
      for (final value in values)
        if (seen.add(jsonEncode(value))) value,
    ];
  }
  return result;
}

/// Builds candidate client JAR paths for a version folder.
List<String> installerClientJarCandidates({
  required String versionDirectory,
  required String minecraftPath,
  required String versionId,
  required Map<String, dynamic> config,
}) {
  final folderName = installerLastPathSegment(versionDirectory);
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

/// Rewrites NeoForge's embedded Maven URLs to the official Forge CDN.
Future<File> installerApplyNeoForgeCdnMirror(File installer) async {
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
  final baseName = installerLastPathSegment(installer.path);
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

  Uri resolveDownloadUriFor(
    Uri original, {
    required MinecraftDownloadSource source,
    required String versionId,
    bool clientArtifact = false,
  }) {
    if (source == MinecraftDownloadSource.mojang) return original;
    if (clientArtifact) {
      return Uri.https(bmclapiHost, '/version/$versionId/client');
    }
    if (original.host == 'resources.download.minecraft.net') {
      return Uri.https(bmclapiHost, '/assets${original.path}');
    }
    if (original.host == 'libraries.minecraft.net' ||
        original.host.endsWith('.maven.apache.org') ||
        original.host == 'repo.maven.apache.org' ||
        original.host == 'repo1.maven.org') {
      return Uri.https(bmclapiHost, '/maven${original.path}');
    }
    return original;
  }

  String? safeJoin(String base, String relative) {
    final normalized = relative.replaceAll('\\', '/');
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized.split('/').any((part) => part == '..' || part.isEmpty)) {
      return null;
    }
    return joinPath(base, normalized);
  }

  Future<dynamic> getJson(
    Uri uri, {
    DownloadCancellationToken? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    if (uri.scheme != 'https') {
      throw FormatException('拒绝从非 HTTPS 地址获取 Minecraft 数据：$uri');
    }
    final client = HttpClient()
      ..connectionTimeout = minecraftRequestTimeout
      ..userAgent = 'BlockLauncher/26.1alpha1.1 (Minecraft installer)';
    void abort() => client.close(force: true);
    cancellation?.addListener(abort);
    try {
      final request = await client.getUrl(uri).timeout(minecraftRequestTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(minecraftRequestTimeout);
      cancellation?.throwIfCancelled();
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(minecraftRequestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}: $body', uri: uri);
      }
      return jsonDecode(body);
    } catch (_) {
      if (cancellation?.isCancelled ?? false) {
        throw const DownloadCancelledException();
      }
      rethrow;
    } finally {
      cancellation?.removeListener(abort);
      client.close(force: true);
    }
  }
class MinecraftDownloadArtifact {
  const MinecraftDownloadArtifact({
    required this.path,
    required this.uri,
    this.sha1,
    this.size,
  }) : sourcePath = null,
       bytes = null;

  const MinecraftDownloadArtifact.bytes({
    required this.path,
    required this.bytes,
  }) : uri = null,
       sha1 = null,
       size = null,
       sourcePath = null;

  const MinecraftDownloadArtifact.copy({
    required this.path,
    required this.sourcePath,
  }) : uri = null,
       sha1 = null,
       size = null,
       bytes = null;

  final String path;
  final Uri? uri;
  final String? sha1;
  final int? size;
  final String? sourcePath;
  final List<int>? bytes;
}

class CurseForgeManifestFile {
  const CurseForgeManifestFile({
    required this.projectId,
    required this.fileId,
    required this.required,
  });

  final int projectId;
  final int fileId;
  final bool required;
}

class CurseForgeManifest {
  const CurseForgeManifest({
    required this.name,
    required this.version,
    required this.author,
    required this.minecraftVersion,
    required this.manifestType,
    required this.manifestVersion,
    required this.loader,
    required this.loaderVersion,
    required this.primaryModLoaderId,
    required this.files,
    required this.overridesDirectory,
  });

  final String name;
  final String version;
  final String author;
  final String minecraftVersion;
  final String manifestType;
  final int manifestVersion;
  final String? loader;
  final String? loaderVersion;
  final String? primaryModLoaderId;
  final List<CurseForgeManifestFile> files;
  final String overridesDirectory;

  List<CurseForgeManifestFile> get requiredFiles =>
      files.where((file) => file.required).toList(growable: false);
}

/// Parses a CurseForge modpack `manifest.json`.
///
/// Example loader ids are `forge-47.2.0`, `neoforge-21.1.248`,
/// `fabric-0.15.11`, and `quilt-0.26.0`.
CurseForgeManifest parseCurseForgeManifest(String jsonContent) {
  dynamic decoded;
  try {
    decoded = jsonDecode(jsonContent);
  } on FormatException catch (error) {
    throw FormatException('manifest.json 不是有效 JSON：${error.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('manifest.json 顶层必须是 JSON 对象。');
  }
  return parseCurseForgeManifestMap(decoded);
}

CurseForgeManifest parseCurseForgeManifestMap(Map<String, dynamic> json) {
  final manifestType = json['manifestType'];
  if (manifestType is String &&
      manifestType.isNotEmpty &&
      manifestType != 'minecraftModpack') {
    throw FormatException('不支持的 manifestType：$manifestType');
  }

  final minecraft = json['minecraft'];
  if (minecraft is! Map) {
    throw const FormatException('manifest 缺少 minecraft 对象。');
  }
  final minecraftVersion = minecraft['version'];
  if (minecraftVersion is! String || minecraftVersion.trim().isEmpty) {
    throw const FormatException('manifest 缺少 minecraft.version。');
  }

  String? primaryModLoaderId;
  String? loader;
  String? loaderVersion;
  final modLoaders = minecraft['modLoaders'];
  if (modLoaders is List) {
    Map? selected;
    for (final entry in modLoaders.whereType<Map>()) {
      final id = entry['id'];
      if (id is! String || id.trim().isEmpty) continue;
      if (entry['primary'] == true) {
        selected = entry;
        break;
      }
      selected ??= entry;
    }
    if (selected != null) {
      primaryModLoaderId = (selected['id'] as String).trim();
      final parsed = _parseCurseForgeLoaderId(primaryModLoaderId);
      loader = parsed.loader;
      loaderVersion = parsed.version;
    }
  }

  final files = <CurseForgeManifestFile>[];
  final rawFiles = json['files'];
  if (rawFiles is List) {
    for (final entry in rawFiles.whereType<Map>()) {
      final projectId = _asPositiveInt(entry['projectID']);
      final fileId = _asPositiveInt(entry['fileID']);
      if (projectId == null || fileId == null) continue;
      files.add(
        CurseForgeManifestFile(
          projectId: projectId,
          fileId: fileId,
          required: entry['required'] is bool
              ? entry['required'] as bool
              : true,
        ),
      );
    }
  }

  final name = json['name'];
  final version = json['version'];
  final author = json['author'];
  final overrides = json['overrides'];
  final manifestVersion = json['manifestVersion'];
  return CurseForgeManifest(
    name: name is String && name.trim().isNotEmpty ? name.trim() : '未命名整合包',
    version: version is String && version.trim().isNotEmpty
        ? version.trim()
        : '1.0.0',
    author: author is String ? author.trim() : '',
    minecraftVersion: minecraftVersion.trim(),
    manifestType: manifestType is String ? manifestType : 'minecraftModpack',
    manifestVersion: manifestVersion is int ? manifestVersion : 1,
    loader: loader,
    loaderVersion: loaderVersion,
    primaryModLoaderId: primaryModLoaderId,
    files: List<CurseForgeManifestFile>.unmodifiable(files),
    overridesDirectory: overrides is String && overrides.trim().isNotEmpty
        ? overrides.trim()
        : 'overrides',
  );
}

int? _asPositiveInt(Object? value) {
  if (value is int) return value > 0 ? value : null;
  if (value is num) {
    final integer = value.toInt();
    return integer > 0 ? integer : null;
  }
  if (value is String) {
    final integer = int.tryParse(value);
    return integer != null && integer > 0 ? integer : null;
  }
  return null;
}

({String? loader, String? version}) _parseCurseForgeLoaderId(String id) {
  final normalized = id.trim();
  for (final prefix in const ['neoforge-', 'fabric-loader-', 'quilt-loader-']) {
    if (normalized.startsWith(prefix)) {
      final loader = switch (prefix) {
        'fabric-loader-' => 'fabric',
        'quilt-loader-' => 'quilt',
        _ => prefix.substring(0, prefix.length - 1),
      };
      return (loader: loader, version: normalized.substring(prefix.length));
    }
  }
  final separator = normalized.indexOf('-');
  if (separator <= 0 || separator == normalized.length - 1) {
    return (loader: normalized.isEmpty ? null : normalized, version: null);
  }
  return (
    loader: normalized.substring(0, separator),
    version: normalized.substring(separator + 1),
  );
}

/// One downloadable file from a Modrinth modpack index.
enum ModpackFormat { modrinth, curseForge }

class ModpackFileEntry {
  const ModpackFileEntry({
    required this.path,
    required this.downloads,
    required this.clientRequired,
    this.sha1,
    this.fileSize,
  });

  final String path;
  final List<String> downloads;
  final String? sha1;
  final int? fileSize;
  final bool clientRequired;
}

class ModpackManifest {
  const ModpackManifest({
    required this.name,
    required this.versionId,
    required this.minecraftVersion,
    required this.loader,
    required this.loaderVersion,
    required this.files,
    required this.overridesPrefixes,
  });

  final String name;
  final String versionId;
  final String minecraftVersion;
  final String? loader;
  final String? loaderVersion;
  final List<ModpackFileEntry> files;
  final List<String> overridesPrefixes;

  ModpackManifest copyWith({
    String? name,
    String? versionId,
    String? minecraftVersion,
    String? loader,
    String? loaderVersion,
    List<ModpackFileEntry>? files,
    List<String>? overridesPrefixes,
  }) {
    return ModpackManifest(
      name: name ?? this.name,
      versionId: versionId ?? this.versionId,
      minecraftVersion: minecraftVersion ?? this.minecraftVersion,
      loader: loader ?? this.loader,
      loaderVersion: loaderVersion ?? this.loaderVersion,
      files: files ?? this.files,
      overridesPrefixes: overridesPrefixes ?? this.overridesPrefixes,
    );
  }
}

class ModpackPackage {
  const ModpackPackage({
    required this.manifest,
    required this.archive,
    this.format = ModpackFormat.modrinth,
    this.curseForgeManifest,
  });

  final ModpackManifest manifest;
  final Archive archive;
  final ModpackFormat format;
  final CurseForgeManifest? curseForgeManifest;

  ModpackPackage withManifest(ModpackManifest updatedManifest) {
    return ModpackPackage(
      manifest: updatedManifest,
      archive: archive,
      format: format,
      curseForgeManifest: curseForgeManifest,
    );
  }
}

class ModpackCancelledException implements Exception {
  const ModpackCancelledException();

  @override
  String toString() => '整合包安装已取消。';
}

class ModpackInstallSummary {
  const ModpackInstallSummary({
    required this.downloadedFiles,
    required this.overriddenFiles,
  });

  final int downloadedFiles;
  final int overriddenFiles;
}

typedef ModpackFileDownloader = Future<void> Function(
  ModpackFileEntry entry,
  String destinationPath,
);

/// Flattens a modpack client config into a fully standalone version JSON.
///
/// The parent (vanilla or loader) config is merged in — libraries, arguments,
/// asset index, main class and downloads — and `inheritsFrom` is removed, so
/// the temporary parent folder can be deleted afterwards without breaking the
/// modpack client.
Future<bool> flattenModpackClientConfig({
  required File clientConfig,
  required Directory versionsDirectory,
  required String clientName,
  required String minecraftVersion,
}) async {
  final original = await clientConfig.readAsString();
  final merged = await installerLoadVersionConfig(
    clientConfig,
    versionsDirectory,
    <String>{},
  );
  final libraries = merged['libraries'];
  if (libraries is! List) return false;

  merged['libraries'] = dedupeModpackLibraries(libraries);
  final arguments = merged['arguments'];
  if (arguments is Map<String, dynamic>) {
    merged['arguments'] = dedupeModpackArguments(arguments);
  }
  merged['id'] = clientName;
  merged['minecraftVersion'] = minecraftVersion;
  merged['jar'] = clientName;
  merged.remove('inheritsFrom');
  try {
    await clientConfig.writeAsString(
      '${JsonEncoder.withIndent('  ').convert(merged)}\n',
      flush: true,
    );
    final decoded = jsonDecode(await clientConfig.readAsString());
    final valid =
        decoded is Map<String, dynamic> &&
        !decoded.containsKey('inheritsFrom') &&
        decoded['jar'] == clientName &&
        decoded['libraries'] is List &&
        decoded['mainClass'] is String;
    if (!valid) {
      await clientConfig.writeAsString(original, flush: true);
    }
    return valid;
  } on Object {
    try {
      await clientConfig.writeAsString(original, flush: true);
    } on Object {
      // Keep the original error.
    }
    rethrow;
  }
}
