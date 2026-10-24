// Data models, enums and shared parsing helpers of the network layer.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/launcher_log.dart';

/// Cancellation signal shared by network downloads and the download queue.
class DownloadCancelledException implements Exception {
  const DownloadCancelledException();

  @override
  String toString() => '下载已取消';
}

class DownloadCancellationToken {
  bool _cancelled = false;
  final Set<void Function()> _listeners = {};

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      try {
        listener();
      } catch (_) {
        // Cancellation callbacks must never block the remaining cleanup.
      }
    }
  }

  void addListener(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void throwIfCancelled() {
    if (_cancelled) throw const DownloadCancelledException();
  }
}

T? firstOrNullOf<T>(Iterable<T> values) {
  return values.isEmpty ? null : values.first;
}

final RegExp _apiGameVersionBasePattern = RegExp(r'^(\d+\.\d+(?:\.\d+)?)');

bool apiIsSnapshotVersion(String value) {
  return RegExp(r'^\d{2}w\d{2}[a-z]$').hasMatch(value.trim().toLowerCase());
}

String? _apiBaseGameVersion(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || apiIsSnapshotVersion(normalized)) return null;
  return _apiGameVersionBasePattern.firstMatch(normalized)?.group(1);
}

List<String> apiNormalizeGameVersions(Iterable<String> values) {
  final versions = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final base = _apiBaseGameVersion(value);
    if (base != null && seen.add(base)) {
      versions.add(base);
    }
  }
  return versions;
}

List<String> apiInferMinecraftVersions(String text) {
  final versions = <String>[];
  final pattern = RegExp(r'(?:^|[^\d.])(\d{1,3}(?:\.\d+){1,2})(?!\d|\.\d)');
  for (final match in pattern.allMatches(text)) {
    final value = match.group(1);
    if (value == null) continue;
    final parts = value.split('.');
    if (parts.length < 2 || parts.length > 3) continue;
    final major = int.tryParse(parts[0]);
    final isMinecraft =
        major == 1 || (major != null && major >= 26 && major <= 30);
    if (!isMinecraft || versions.contains(value)) continue;
    versions.add(value);
  }
  return versions;
}

class MinecraftCatalogVersion {
  const MinecraftCatalogVersion({
    required this.id,
    required this.type,
    this.releaseTime,
  });

  final String id;
  final String type;
  final String? releaseTime;
}

enum DownloadCategory {
  mods('模组', 'mod', 'mods'),
  shaders('光影', 'shader', 'shaderpacks'),
  resourcePacks('材质包', 'resourcepack', 'resourcepacks'),
  dataPacks('数据包/地图', 'datapack', 'datapacks');

  const DownloadCategory(this.label, this.modrinthProjectType, this.folder);

  final String label;
  final String modrinthProjectType;
  final String folder;
}

enum ResourceSource {
  aggregate('聚合搜索'),
  modrinth('Modrinth'),
  curseForge('CurseForge');

  const ResourceSource(this.label);

  final String label;
}

enum AggregatePreference {
  balanced('全部显示'),
  modrinth('偏向 Modrinth'),
  curseForge('偏向 CurseForge');

  const AggregatePreference(this.label);

  final String label;
}

/// Normalizes a mod title so the same mod from two platforms compares equal.
String normalizeModTitle(String title) {
  return title.toLowerCase().replaceAll(
    RegExp(r'[\s\-_:：·.,，。()（）\[\]【】/\\]+'),
    '',
  );
}

/// Removes cross-platform duplicates from aggregated results.
///
/// A group is only collapsed when it contains results from more than one
/// source and the preferred source is present. Single-platform results and
/// groups without overlap are always kept.
List<T> dedupeAggregateResults<T>({
  required Iterable<T> items,
  required String Function(T) titleOf,
  required String Function(T) sourceOf,
  required String preferredSource,
}) {
  final list = items.toList();
  final grouped = <String, List<T>>{};
  for (final item in list) {
    final key = normalizeModTitle(titleOf(item));
    if (key.isEmpty) continue;
    grouped.putIfAbsent(key, () => []).add(item);
  }
  final emitted = <String>{};
  final output = <T>[];
  for (final item in list) {
    final key = normalizeModTitle(titleOf(item));
    if (key.isEmpty) {
      output.add(item);
      continue;
    }
    if (!emitted.add(key)) continue;
    final group = grouped[key]!;
    final sources = group.map(sourceOf).toSet();
    final preferred = firstOrNullOf(
      group.where((candidate) => sourceOf(candidate) == preferredSource),
    );
    if (group.length > 1 && sources.length > 1 && preferred != null) {
      output.add(preferred);
    } else {
      output.addAll(group);
    }
  }
  return output;
}

class ModrinthProject {
  const ModrinthProject({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.downloads,
    required this.followers,
    required this.versions,
    required this.tags,
    this.iconUrl,
    this.source = ResourceSource.modrinth,
    this.chineseTitle,
    this.supportedGameVersions = const <String>[],
    this.supportedLoaders = const <String>[],
  });

  final String id;
  final String title;
  final String? chineseTitle;
  final String description;
  final DownloadCategory category;
  final int downloads;
  final int followers;
  final String? iconUrl;
  final List<ModrinthVersion> versions;
  final List<String> tags;
  final ResourceSource source;

  /// Project-level metadata from search/detail responses. This lets the picker
  /// show every supported major version without downloading every file page.
  final List<String> supportedGameVersions;
  final List<String> supportedLoaders;

  ModrinthProject withVersions(List<ModrinthVersion> updatedVersions) {
    return ModrinthProject(
      id: id,
      title: title,
      description: description,
      category: category,
      downloads: downloads,
      followers: followers,
      versions: updatedVersions,
      tags: tags,
      iconUrl: iconUrl,
      source: source,
      chineseTitle: chineseTitle,
      supportedGameVersions: supportedGameVersions,
      supportedLoaders: supportedLoaders,
    );
  }

  ModrinthProject withChineseTitle(String? updatedTitle) {
    final normalized = updatedTitle?.trim();
    return ModrinthProject(
      id: id,
      title: title,
      description: description,
      category: category,
      downloads: downloads,
      followers: followers,
      versions: versions,
      tags: tags,
      iconUrl: iconUrl,
      source: source,
      chineseTitle: normalized == null || normalized.isEmpty
          ? chineseTitle
          : normalized,
      supportedGameVersions: supportedGameVersions,
      supportedLoaders: supportedLoaders,
    );
  }

  String get displayTitle {
    final localized = chineseTitle?.trim();
    return localized == null || localized.isEmpty ? title : localized;
  }
}

/// Result returned by the shared version/loader picker.
class ResourceVersionChoice {
  const ResourceVersionChoice({
    required this.project,
    this.version,
    this.loader,
    this.defer = false,
  });

  final ModrinthProject project;
  final ModrinthVersion? version;
  final String? loader;
  final bool defer;
}

/// One item in the download candidate list.
///
/// `versionId` and `loader` are nullable so a candidate can be added before
/// the user picks a concrete file. `englishName` is kept separately because
/// the UI may display a localized title.
class CandidateMod {
  const CandidateMod({
    required this.englishName,
    required this.projectId,
    required this.project,
    this.version,
    this.versionId,
    this.loader,
  });

  factory CandidateMod.deferred(ModrinthProject project) {
    return CandidateMod(
      englishName: project.title,
      projectId: project.id,
      project: project,
    );
  }

  factory CandidateMod.fromChoice(ResourceVersionChoice choice) {
    return CandidateMod(
      englishName: choice.project.title,
      projectId: choice.project.id,
      project: choice.project,
      version: choice.version,
      versionId: choice.version?.versionId,
      loader: choice.loader,
    );
  }

  final String englishName;
  final String projectId;
  final ModrinthProject project;
  final ModrinthVersion? version;
  final String? versionId;
  final String? loader;

  bool get needsVersion => versionId == null;
}

/// In-memory candidate list owned by the launcher page.
///
/// It intentionally has no persistence: candidates are cleared when the
/// launcher page is disposed.
class CandidateManager {
  final List<CandidateMod> _items = <CandidateMod>[];

  List<CandidateMod> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;

  bool contains(String projectId) {
    return _items.any((candidate) => candidate.projectId == projectId);
  }

  CandidateMod? find(String projectId) {
    for (final candidate in _items) {
      if (candidate.projectId == projectId) return candidate;
    }
    return null;
  }

  void add(CandidateMod candidate) {
    final index = _items.indexWhere(
      (item) => item.projectId == candidate.projectId,
    );
    if (index >= 0) {
      _items[index] = candidate;
    } else {
      _items.add(candidate);
    }
  }

  void remove(String projectId) {
    _items.removeWhere((candidate) => candidate.projectId == projectId);
  }

  void removeAll(Iterable<String> projectIds) {
    final ids = projectIds.toSet();
    _items.removeWhere((candidate) => ids.contains(candidate.projectId));
  }

  void clear() => _items.clear();
}

/// Displays a mod title immediately in English, then updates only this text
/// when the background mcmod query completes.

class ModrinthSearchPage {
  const ModrinthSearchPage({required this.projects, required this.totalHits});

  final List<ModrinthProject> projects;
  final int totalHits;
}

class ModrinthVersion {
  const ModrinthVersion({
    required this.name,
    required this.versionType,
    required this.downloads,
    required this.gameVersions,
    required this.loaders,
    required this.files,
    this.versionId,
  });

  final String name;
  final String versionType;
  final int downloads;
  final List<String> gameVersions;
  final List<String> loaders;
  final List<ModrinthFile> files;

  /// Modrinth version ID or CurseForge file ID.
  final String? versionId;
}

class ModrinthFile {
  const ModrinthFile({required this.filename, required this.url});

  final String filename;
  final String url;
}

/// Decodes Minecraft / NeoForge console output.
///
/// ModLauncher writes UTF-8 and masks the access token with eight snowflakes
/// (`❄❄❄❄❄❄❄❄`). Trying the Windows ANSI code page first would turn that mask
/// into mojibake and make it look like a corrupt launch argument, so game
/// output always uses a tolerant UTF-8 decoder.
String decodeMinecraftProcessOutput(List<int> bytes) {
  return utf8.decode(bytes, allowMalformed: true);
}

/// Decodes output from external Java / Windows tools.
///
/// Windows Chinese consoles emit GBK (the active ANSI code page), so
/// [systemEncoding] is attempted first. UTF-8 and a byte-preserving fallback
/// keep ASCII version fields parseable on other systems.
String _decodeJavaToolOutput(List<int> bytes) {
  try {
    return systemEncoding.decode(bytes);
  } on FormatException {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }
}

String decodeProcessOutput(Object? output) {
  if (output is List<int>) return _decodeJavaToolOutput(output);
  return output?.toString() ?? '';
}

/// Collects installer output as bytes and decodes them only after the stream
/// closes. Decoding each chunk separately can split a multi-byte character
/// (and Fabric/Forge installers can emit GBK or mixed console encodings).
Future<String> readProcessOutput(Stream<List<int>> stream) async {
  final bytes = await stream.fold<List<int>>(<int>[], (buffer, chunk) {
    buffer.addAll(chunk);
    return buffer;
  });
  return _decodeJavaToolOutput(bytes);
}

/// Terminates an installer and waits for its file handles to be released.
Future<void> terminateProcess(Process process) async {
  try {
    if (Platform.isWindows) {
      process.kill();
    } else {
      process.kill(ProcessSignal.sigkill);
    }
  } catch (_) {
    // The process may already have exited.
  }
  try {
    await process.exitCode.timeout(const Duration(seconds: 5));
  } catch (_) {
    // The OS will release the handles when the process eventually exits.
  }
}

/// Deletes a downloaded installer without masking the original install error
/// when Windows briefly keeps the JAR locked after the JVM exits.
Future<void> deleteInstallerFileWithRetry(File file) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    try {
      if (!await file.exists()) return;
      await file.delete();
      return;
    } on FileSystemException catch (error) {
      if (attempt == 19) {
        LauncherLog.warning(
          'Installer',
          '暂时无法删除安装器文件（将在下次启动时清理）：${error.message}',
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}

class ManagedMod {
  const ManagedMod({
    required this.file,
    required this.name,
    required this.enabled,
  });

  final File file;
  final String name;
  final bool enabled;
}

const String mcimApiHost = 'mod.mcimirror.top';
const String mcimCurseForgeBase = 'https://mod.mcimirror.top/curseforge';
const String mcimModrinthBase = 'https://mod.mcimirror.top/modrinth';
const int resourceVersionPageSize = 20;

/// Rewrites absolute CDN URLs returned by MCIM into the mirror host.
///
/// `mediafilez.forgecdn.net` is deliberately preserved: MCIM does not serve
/// that host, so replacing it would produce a broken download URL.
String mcimMirrorUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return url;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return url;
  final host = uri.host.toLowerCase();
  if (host != 'cdn.modrinth.com' && host != 'edge.forgecdn.net') {
    return url;
  }
  return uri.replace(scheme: 'https', host: mcimApiHost).toString();
}

bool isTrustedResourceHost(Uri uri) {
  final host = uri.host.toLowerCase();
  return host == mcimApiHost ||
      host == 'modrinth.com' ||
      host.endsWith('.modrinth.com') ||
      host == 'forgecdn.net' ||
      host.endsWith('.forgecdn.net') ||
      host == 'cursecdn.com' ||
      host.endsWith('.cursecdn.com') ||
      host == 'curseforge.com' ||
      host.endsWith('.curseforge.com');
}
