// Modpack (.mrpack / CurseForge zip) parsing and installation.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show compute;

import '../../core/launcher_log.dart';
import '../../core/path_utils.dart';
import 'version_parser.dart';

/// Runs on a background isolate so hashing large downloads never blocks UI.
String _sha1HexDigest(List<int> bytes) => sha1.convert(bytes).toString();

class ModpackInstaller {
  const ModpackInstaller();

  /// Captures the direct child folder names under `.minecraft/versions`.
  ///
  /// This snapshot is the safety boundary for cleanup: folders that existed
  /// before the modpack installation must never be removed afterwards.
  static Future<Set<String>> snapshotVersions(String minecraftDirectory) async {
    final versionsDirectory = Directory(
      joinPath(minecraftDirectory, 'versions'),
    );
    if (!await versionsDirectory.exists()) return <String>{};
    final versions = <String>{};
    await for (final entity in versionsDirectory.list(followLinks: false)) {
      if (entity is Directory || entity is Link) {
        versions.add(installerLastPathSegment(entity.path));
      }
    }
    return versions;
  }

  Future<ModpackPackage> open(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('整合包文件不存在', file.path);
    }
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final index = _findArchiveFile(archive, 'modrinth.index.json');
    if (index != null) {
      final declared = jsonDecode(utf8.decode(index.content ?? <int>[]));
      if (declared is! Map<String, dynamic>) {
        throw const FormatException('modrinth.index.json 不是 JSON 对象。');
      }
      return ModpackPackage(
        manifest: _parseManifest(declared, file),
        archive: archive,
      );
    }

    final manifestFile = _findArchiveFile(archive, 'manifest.json');
    if (manifestFile != null) {
      final declared = jsonDecode(utf8.decode(manifestFile.content ?? <int>[]));
      if (declared is! Map<String, dynamic>) {
        throw const FormatException('manifest.json 不是 JSON 对象。');
      }
      final curseForge = parseCurseForgeManifestMap(declared);
      var overrides = curseForge.overridesDirectory
          .replaceAll('\\', '/')
          .trim();
      if (overrides.isEmpty) overrides = 'overrides';
      if (!overrides.endsWith('/')) overrides = '$overrides/';
      return ModpackPackage(
        format: ModpackFormat.curseForge,
        curseForgeManifest: curseForge,
        archive: archive,
        manifest: ModpackManifest(
          name: curseForge.name,
          versionId: curseForge.version,
          minecraftVersion: curseForge.minecraftVersion,
          loader: curseForge.loader,
          loaderVersion: curseForge.loaderVersion,
          files: const <ModpackFileEntry>[],
          overridesPrefixes: [overrides],
        ),
      );
    }

    throw const FormatException(
      '找不到 modrinth.index.json 或 manifest.json，无法识别整合包格式。',
    );
  }

  ArchiveFile? _findArchiveFile(Archive archive, String fileName) {
    for (final file in archive.files) {
      if (file.name == fileName || file.name.endsWith('/$fileName')) {
        return file;
      }
    }
    return null;
  }

  ModpackManifest _parseManifest(Map<String, dynamic> json, File archiveFile) {
    final rawDependencies = json['dependencies'];
    final dependencies = rawDependencies is Map
        ? Map<String, dynamic>.from(rawDependencies)
        : const <String, dynamic>{};
    final minecraftVersion = dependencies['minecraft'];
    if (minecraftVersion is! String || minecraftVersion.trim().isEmpty) {
      throw const FormatException('整合包没有声明 Minecraft 版本。');
    }

    String? loader;
    String? loaderVersion;
    for (final key in const [
      'neoforge',
      'forge',
      'fabric-loader',
      'quilt-loader',
    ]) {
      final value = dependencies[key];
      if (value is String && value.trim().isNotEmpty) {
        loader = switch (key) {
          'fabric-loader' => 'fabric',
          'quilt-loader' => 'quilt',
          _ => key,
        };
        loaderVersion = value.trim();
        break;
      }
    }

    final rawFiles = json['files'];
    final files = <ModpackFileEntry>[];
    if (rawFiles is List) {
      for (final entry in rawFiles.whereType<Map>()) {
        final path = entry['path'];
        final rawDownloads = entry['downloads'];
        if (path is! String || rawDownloads is! List) continue;
        final downloads = rawDownloads.whereType<String>().toList();
        if (downloads.isEmpty) continue;
        final env = entry['env'];
        var clientRequired = true;
        if (env is Map && env['client'] == 'unsupported') {
          clientRequired = false;
        }
        final hashes = entry['hashes'];
        final sha1 = hashes is Map ? hashes['sha1'] : null;
        final size = entry['fileSize'];
        files.add(
          ModpackFileEntry(
            path: path,
            downloads: downloads,
            sha1: sha1 is String && sha1.isNotEmpty ? sha1.toLowerCase() : null,
            fileSize: size is int ? size : null,
            clientRequired: clientRequired,
          ),
        );
      }
    }

    final name = json['name'];
    final versionId = json['versionId'];
    final fallbackName = _archiveBaseName(archiveFile.path);
    return ModpackManifest(
      name: name is String && name.trim().isNotEmpty
          ? name.trim()
          : fallbackName,
      versionId: versionId is String && versionId.trim().isNotEmpty
          ? versionId.trim()
          : '1.0.0',
      minecraftVersion: minecraftVersion.trim(),
      loader: loader,
      loaderVersion: loaderVersion,
      files: files,
      overridesPrefixes: const ['overrides/', 'client-overrides/'],
    );
  }

  Future<ModpackInstallSummary> install({
    required ModpackPackage package,
    required String clientDirectory,
    bool Function()? isCancelled,
    void Function(String status)? onProgress,
    ModpackFileDownloader? downloadFile,
    int maxConcurrentDownloads = 4,
    Set<String>? beforeInstall,
  }) async {
    final manifest = package.manifest;
    final client = Directory(clientDirectory);
    await client.create(recursive: true);
    final files = manifest.files
        .where((entry) => entry.clientRequired)
        .toList(growable: false);
    var completed = 0;
    var downloaded = 0;

    void checkCancelled() {
      if (isCancelled?.call() ?? false) {
        throw const ModpackCancelledException();
      }
    }

    onProgress?.call(
      '正在检查整合包文件：${manifest.name} · ${manifest.minecraftVersion}',
    );
    if (downloadFile != null) {
      await Future.wait(
        files.map((entry) async {
          checkCancelled();
          final destination = _safeJoin(client.path, entry.path);
          if (destination == null) {
            throw FormatException('整合包包含无效文件路径：${entry.path}');
          }
          await downloadFile(entry, destination);
          completed++;
          downloaded++;
          onProgress?.call(
            '正在下载整合包文件 $completed/${files.length}：${entry.path}',
          );
        }),
      );
    } else {
      for (
        var start = 0;
        start < files.length;
        start += maxConcurrentDownloads
      ) {
        checkCancelled();
        final end = (start + maxConcurrentDownloads).clamp(0, files.length);
        final chunk = files.sublist(start, end);
        await Future.wait(
          chunk.map((entry) async {
            final destination = _safeJoin(client.path, entry.path);
            if (destination == null) {
              throw FormatException('整合包包含无效文件路径：${entry.path}');
            }
            await _downloadEntry(
              entry: entry,
              destination: destination,
              isCancelled: isCancelled,
            );
            completed++;
            downloaded++;
            onProgress?.call(
              '正在下载整合包文件 $completed/${files.length}：${entry.path}',
            );
          }),
        );
      }
    }

    checkCancelled();
    onProgress?.call('正在写入整合包配置与覆盖文件…');
    final overridden = await _extractOverrides(
      archive: package.archive,
      destination: client,
      prefixes: manifest.overridesPrefixes,
      isCancelled: isCancelled,
    );
    checkCancelled();
    if (beforeInstall != null) {
      onProgress?.call('正在清理整合包临时版本…');
      await _cleanupTemporaryVersions(
        client: client,
        beforeInstall: beforeInstall,
        manifest: manifest,
      );
    }
    onProgress?.call('整合包安装完成：$downloaded 个文件，$overridden 个覆盖文件。');
    return ModpackInstallSummary(
      downloadedFiles: downloaded,
      overriddenFiles: overridden,
    );
  }

  Future<void> _cleanupTemporaryVersions({
    required Directory client,
    required Set<String> beforeInstall,
    required ModpackManifest manifest,
  }) async {
    try {
      final versionsDirectory = client.parent;
      final clientName = installerLastPathSegment(client.path);
      if (modpackVersionKey(installerLastPathSegment(versionsDirectory.path)) !=
          'versions') {
        LauncherLog.warning('Modpack', '跳过临时版本清理：客户端不在 versions 目录内。');
        return;
      }
      final clientConfig = File(joinPath(client.path, '$clientName.json'));
      if (!await clientConfig.exists()) {
        LauncherLog.warning('Modpack', '跳过临时版本清理：整合包版本 JSON 不存在。');
        return;
      }
      final dependencies = await _modpackClientDependencies(
        clientConfig,
        versionsDirectory,
      );
      if (dependencies == null) {
        LauncherLog.warning('Modpack', '跳过临时版本清理：无法解析整合包版本依赖。');
        return;
      }

      final beforeKeys = beforeInstall.map(modpackVersionKey).toSet();
      final candidates = <String, String>{};
      for (final id in dependencies) {
        if (!isSafeVersionFolderName(id)) continue;
        final key = modpackVersionKey(id);
        if (key == modpackVersionKey(clientName) || beforeKeys.contains(key)) {
          continue;
        }
        final path = joinPath(versionsDirectory.path, id);
        if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.directory) {
          continue;
        }
        candidates[key] = id;
      }

      // Also sweep brand-new folders that look like a plain vanilla or loader
      // version. The launcher blocks concurrent installs, so any such folder
      // created after [beforeInstall] was snapshotted can only be a build
      // intermediate of this modpack run. Folders the player already had are
      // protected by [beforeKeys]; anything still referenced by another client
      // is removed from the deletion set further below.
      final vanillaPattern = RegExp(r'^\d+\.\d+(?:\.\d+)?$');
      final loaderPattern = RegExp(
        r'^(?:fabric-loader|forge|neoforge|quilt-loader|liteloader)-',
        caseSensitive: false,
      );
      await for (final entity in versionsDirectory.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final id = installerLastPathSegment(entity.path);
        final key = modpackVersionKey(id);
        if (beforeKeys.contains(key) || key == modpackVersionKey(clientName)) {
          continue;
        }
        if (!isSafeVersionFolderName(id)) continue;
        if (!vanillaPattern.hasMatch(id) && !loaderPattern.hasMatch(id)) {
          continue;
        }
        if (!await File(joinPath(entity.path, '$id.json')).exists()) continue;
        candidates[key] = id;
      }
      if (candidates.isEmpty) return;

      final deletable = Map<String, String>.from(candidates);
      while (deletable.isNotEmpty) {
        final referenced = await _referencedCandidateKeys(
          versionsDirectory: versionsDirectory,
          clientKey: modpackVersionKey(clientName),
          deletableKeys: deletable.keys.toSet(),
        );
        if (referenced == null) {
          LauncherLog.warning('Modpack', '跳过临时版本清理：无法确认其他版本依赖。');
          return;
        }
        if (referenced.isEmpty) break;
        for (final key in referenced) {
          deletable.remove(key);
        }
      }
      if (deletable.isEmpty) return;

      final jarReady = await _ensureModpackClientJar(
        client: client,
        clientName: clientName,
        versionsDirectory: versionsDirectory,
        dependencyIds: dependencies,
      );
      if (!jarReady) {
        LauncherLog.warning('Modpack', '保留临时版本：无法为整合包准备本地客户端 JAR。');
        return;
      }
      final flattened = await flattenModpackClientConfig(
        clientConfig: clientConfig,
        versionsDirectory: versionsDirectory,
        clientName: clientName,
        minecraftVersion: manifest.minecraftVersion,
      );
      if (!flattened) {
        LauncherLog.warning('Modpack', '保留临时版本：整合包 JSON 扁平化失败。');
        return;
      }

      final removed = <String>[];
      for (final id in deletable.values) {
        if (!isSafeVersionFolderName(id)) continue;
        final key = modpackVersionKey(id);
        if (beforeKeys.contains(key) || key == modpackVersionKey(clientName)) {
          continue;
        }
        final path = joinPath(versionsDirectory.path, id);
        if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.directory) {
          continue;
        }
        if (modpackVersionKey(versionsDirectory.absolute.path) !=
            modpackVersionKey(Directory(path).parent.absolute.path)) {
          continue;
        }
        try {
          await Directory(path).delete(recursive: true);
          removed.add(id);
        } on FileSystemException catch (error) {
          LauncherLog.warning('Modpack', '清理临时版本失败：$id ($error)');
        }
      }
      if (removed.isNotEmpty) {
        LauncherLog.info('Modpack', '已清理整合包临时版本：${removed.join(', ')}');
      }
    } on Object catch (error) {
      LauncherLog.warning('Modpack', '清理临时版本失败，已保留原目录：$error');
    } finally {
      await _cleanupLoaderInstallerArtifacts(manifest);
    }
  }

  Future<List<String>?> _modpackClientDependencies(
    File clientConfig,
    Directory versionsDirectory,
  ) async {
    try {
      final decoded = jsonDecode(await clientConfig.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final dependencies = <String>[];
      final seen = <String>{};
      void add(String? value) {
        if (value == null) return;
        final id = value.trim();
        if (!isSafeVersionFolderName(id)) return;
        if (seen.add(modpackVersionKey(id))) dependencies.add(id);
      }

      final jar = decoded['jar'];
      if (jar is String) add(jar);
      var parent = decoded['inheritsFrom'];
      final visited = <String>{};
      while (parent is String && parent.trim().isNotEmpty) {
        final parentId = parent.trim();
        if (!isSafeVersionFolderName(parentId)) return null;
        final parentKey = modpackVersionKey(parentId);
        if (!visited.add(parentKey)) break;
        add(parentId);
        final parentConfig = File(
          joinPath(
            joinPath(versionsDirectory.path, parentId),
            '$parentId.json',
          ),
        );
        if (!await parentConfig.exists()) break;
        final parentDecoded = jsonDecode(await parentConfig.readAsString());
        if (parentDecoded is! Map<String, dynamic>) return null;
        final parentJar = parentDecoded['jar'];
        if (parentJar is String) add(parentJar);
        parent = parentDecoded['inheritsFrom'];
      }
      return dependencies;
    } on Object {
      return null;
    }
  }

  Future<Set<String>?> _referencedCandidateKeys({
    required Directory versionsDirectory,
    required String clientKey,
    required Set<String> deletableKeys,
  }) async {
    final referenced = <String>{};
    await for (final entity in versionsDirectory.list(followLinks: false)) {
      if (entity is! Directory && entity is! Link) continue;
      if (entity is Link) {
        final targetType = await FileSystemEntity.type(
          entity.path,
          followLinks: true,
        );
        if (targetType != FileSystemEntityType.directory) continue;
      }
      final id = installerLastPathSegment(entity.path);
      final key = modpackVersionKey(id);
      if (key == clientKey || deletableKeys.contains(key)) continue;
      final config = File(joinPath(entity.path, '$id.json'));
      if (!await config.exists()) continue;
      try {
        final decoded = jsonDecode(await config.readAsString());
        if (decoded is! Map<String, dynamic>) return null;
        final refs = <String>{};
        final jar = decoded['jar'];
        if (jar is String && jar.trim().isNotEmpty) {
          refs.add(modpackVersionKey(jar.trim()));
        }
        var parent = decoded['inheritsFrom'];
        final visited = <String>{};
        while (parent is String && parent.trim().isNotEmpty) {
          final parentId = parent.trim();
          if (!isSafeVersionFolderName(parentId)) return null;
          final parentKey = modpackVersionKey(parentId);
          if (!visited.add(parentKey)) break;
          refs.add(parentKey);
          final parentConfig = File(
            joinPath(
              joinPath(versionsDirectory.path, parentId),
              '$parentId.json',
            ),
          );
          if (!await parentConfig.exists()) break;
          final parentDecoded = jsonDecode(await parentConfig.readAsString());
          if (parentDecoded is! Map<String, dynamic>) return null;
          final parentJar = parentDecoded['jar'];
          if (parentJar is String && parentJar.trim().isNotEmpty) {
            refs.add(modpackVersionKey(parentJar.trim()));
          }
          parent = parentDecoded['inheritsFrom'];
        }
        referenced.addAll(refs.where(deletableKeys.contains));
      } on Object {
        return null;
      }
    }
    return referenced;
  }

  Future<bool> _ensureModpackClientJar({
    required Directory client,
    required String clientName,
    required Directory versionsDirectory,
    required List<String> dependencyIds,
  }) async {
    final target = File(joinPath(client.path, '$clientName.jar'));
    final existingLength = await target.exists() ? await target.length() : 0;
    if (existingLength > 0) return true;

    for (final id in dependencyIds) {
      if (!isSafeVersionFolderName(id) ||
          modpackVersionKey(id) == modpackVersionKey(clientName)) {
        continue;
      }
      final versionDirectory = Directory(joinPath(versionsDirectory.path, id));
      if (await FileSystemEntity.type(
            versionDirectory.path,
            followLinks: false,
          ) !=
          FileSystemEntityType.directory) {
        continue;
      }
      final candidates = <File>[
        File(joinPath(versionDirectory.path, '$id.jar')),
        File(joinPath(versionDirectory.path, 'client.jar')),
      ];
      final configFile = File(joinPath(versionDirectory.path, '$id.json'));
      if (await configFile.exists()) {
        try {
          final decoded = jsonDecode(await configFile.readAsString());
          if (decoded is Map<String, dynamic>) {
            candidates.addAll(
              installerClientJarCandidates(
                versionDirectory: versionDirectory.path,
                minecraftPath: versionsDirectory.parent.path,
                versionId: id,
                config: decoded,
              ).map(File.new),
            );
          }
        } on Object {
          // Fall back to the direct jar candidates above.
        }
      }
      for (final candidate in candidates) {
        if (sameModpackPath(candidate.path, target.path)) continue;
        if (!await candidate.exists()) continue;
        final sourceLength = await candidate.length();
        if (sourceLength == 0) continue;
        await target.parent.create(recursive: true);
        await candidate.copy(target.path);
        final copiedLength = await target.exists() ? await target.length() : 0;
        if (copiedLength > 0) return true;
      }
    }
    return false;
  }

  Future<void> _cleanupLoaderInstallerArtifacts(
    ModpackManifest manifest,
  ) async {
    final loader = manifest.loader;
    final loaderVersion = manifest.loaderVersion;
    if (loader == null || loaderVersion == null || loaderVersion.isEmpty) {
      return;
    }
    try {
      final installerName =
          '$loader-${manifest.minecraftVersion}-$loaderVersion-installer'
              .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final directory = Directory(
        joinPath(Directory.systemTemp.path, 'block-launcher-installers'),
      );
      if (!await directory.exists()) return;
      for (final suffix in ['$installerName.jar', '$installerName-cdn.jar']) {
        final file = File(joinPath(directory.path, suffix));
        if (!await file.exists()) continue;
        try {
          await file.delete();
        } on FileSystemException catch (error) {
          LauncherLog.warning('Modpack', '清理安装器失败：${file.path} ($error)');
        }
      }
    } on Object catch (error) {
      LauncherLog.warning('Modpack', '清理安装器缓存失败：$error');
    }
  }

  Future<void> _downloadEntry({
    required ModpackFileEntry entry,
    required String destination,
    required bool Function()? isCancelled,
  }) async {
    final target = File(destination);
    if (entry.sha1 != null && await target.exists()) {
      try {
        final existing = await target.readAsBytes();
        if (sha1.convert(existing).toString() == entry.sha1) return;
      } on FileSystemException {
        // Fall through and download a fresh copy.
      }
    }
    await target.parent.create(recursive: true);
    final temporary = File('$destination.part');
    Object? lastError;
    for (final download in entry.downloads) {
      if (isCancelled?.call() ?? false) {
        throw const ModpackCancelledException();
      }
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..userAgent = 'BlockLauncher/26.1alpha2.1 (modpack installer)';
      IOSink? sink;
      try {
        final uri = Uri.tryParse(download);
        if (uri == null || !uri.hasScheme) continue;
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 20));
        request.headers.set(HttpHeaders.acceptHeader, '*/*');
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = HttpException('HTTP ${response.statusCode}', uri: uri);
          await response.drain<void>();
          continue;
        }
        if (await temporary.exists()) await temporary.delete();
        sink = temporary.openWrite();
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.timeout(
          const Duration(seconds: 60),
        )) {
          if (isCancelled?.call() ?? false) {
            throw const ModpackCancelledException();
          }
          bytes.add(chunk);
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();
        sink = null;
        final digest = await compute(_sha1HexDigest, bytes.takeBytes());
        if (entry.sha1 != null && digest != entry.sha1) {
          throw FormatException(
            '文件校验失败：${entry.path}（期望 ${entry.sha1}，实际 $digest）',
          );
        }
        if (await target.exists()) await target.delete();
        await temporary.rename(target.path);
        lastError = null;
        return;
      } on ModpackCancelledException {
        rethrow;
      } on Object catch (error) {
        lastError = error;
      } finally {
        if (sink != null) {
          try {
            await sink.close();
          } on Object {
            // Ignore sink cleanup errors.
          }
        }
        client.close(force: true);
        if (await temporary.exists()) {
          try {
            await temporary.delete();
          } on FileSystemException {
            // The next attempt will overwrite it.
          }
        }
      }
    }
    if (lastError != null) throw lastError;
    throw FormatException('没有可下载地址：${entry.path}');
  }

  Future<int> _extractOverrides({
    required Archive archive,
    required Directory destination,
    required List<String> prefixes,
    required bool Function()? isCancelled,
  }) async {
    var written = 0;
    for (final prefix in prefixes) {
      for (final entry in archive.files) {
        if (isCancelled?.call() ?? false) {
          throw const ModpackCancelledException();
        }
        if (!entry.isFile || !entry.name.startsWith(prefix)) continue;
        final relative = entry.name.substring(prefix.length);
        if (relative.isEmpty) continue;
        final targetPath = _safeJoin(destination.path, relative);
        if (targetPath == null) {
          throw FormatException('整合包覆盖文件路径无效：${entry.name}');
        }
        final content = entry.content;
        if (content == null) continue;
        final target = File(targetPath);
        await target.parent.create(recursive: true);
        await target.writeAsBytes(
          content is Uint8List ? content : Uint8List.fromList(content),
          flush: true,
        );
        written++;
      }
    }
    return written;
  }

  String _archiveBaseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last;
    return name
        .replaceFirst(RegExp(r'\.(mrpack|zip)$', caseSensitive: false), '')
        .trim();
  }

  String? _safeJoin(String root, String relative) {
    final normalized = relative.replaceAll('\\', '/');
    if (normalized.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(normalized)) {
      return null;
    }
    final parts = normalized.split('/');
    if (parts.any((part) => part == '..')) return null;
    final cleanParts = parts
        .where((part) => part.isNotEmpty && part != '.')
        .toList();
    if (cleanParts.isEmpty) return null;
    return [root, ...cleanParts].join(Platform.pathSeparator);
  }
}
