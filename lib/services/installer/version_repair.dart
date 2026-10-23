// Repair pipeline: missing-artifact discovery, downloads and reinstall.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../../core/path_utils.dart';
import '../download/download_service.dart';
import '../network/api_service.dart';
import 'version_parser.dart';

/// Signature used by [VersionRepairer] to repair one installed version.
typedef VersionRepairExecutor = Future<void> Function(String versionId);

Future<void> collectAssetRepairArtifacts({
  required Map<String, MinecraftDownloadArtifact> artifacts,
  required Directory root,
  required Map<String, dynamic> assetIndexInfo,
  required MinecraftDownloadSource source,
  required String versionId,
  required DownloadCancellationToken? cancellation,
}) async {
  final indexId = assetIndexInfo['id'];
  if (indexId is! String || indexId.isEmpty) return;

  final indexPath = joinPath(root.path, 'assets/indexes/$indexId.json');
  final indexFile = File(indexPath);
  Map<String, dynamic>? indexData;
  if (await indexFile.exists()) {
    try {
      final decoded = jsonDecode(await indexFile.readAsString());
      if (decoded is Map<String, dynamic>) indexData = decoded;
    } on FormatException {
      indexData = null;
    }
  }

  if (indexData == null) {
    if (await indexFile.exists()) {
      await indexFile.delete();
    }
    final rawUrl = assetIndexInfo['url'];
    var indexUri = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    if (indexUri == null || indexUri.scheme != 'https') {
      indexUri = Uri.https(bmclapiHost, '/assets/indexes/$indexId.json');
    }
    final fetched = await getJson(indexUri, cancellation: cancellation);
    if (fetched is! Map<String, dynamic>) {
      throw const FormatException('资源索引格式无效。');
    }
    indexData = fetched;
    artifacts[indexPath] = MinecraftDownloadArtifact.bytes(
      path: indexPath,
      bytes: utf8.encode(jsonEncode(fetched)),
    );
  }

  final objects = indexData['objects'];
  if (objects is! Map<String, dynamic>) return;

  for (final value in objects.values) {
    cancellation?.throwIfCancelled();
    if (value is! Map<String, dynamic>) continue;
    final hash = value['hash'];
    if (hash is! String || !sha1HexPattern.hasMatch(hash)) {
      continue;
    }
    final prefix = hash.substring(0, 2);
    final objectPath = joinPath(
      root.path,
      'assets/objects/$prefix/$hash',
    );
    artifacts[objectPath] = MinecraftDownloadArtifact(
      path: objectPath,
      uri: resolveDownloadUriFor(
        Uri.https('resources.download.minecraft.net', '/$prefix/$hash'),
        source: source,
        versionId: versionId,
      ),
      sha1: hash.toLowerCase(),
      size: value['size'] is int ? value['size'] as int : null,
    );
  }
}

Future<Map<String, MinecraftDownloadArtifact>> collectRepairArtifacts({
  required Directory root,
  required Directory versionDirectory,
  required String versionId,
  required Map<String, dynamic> config,
  required MinecraftDownloadSource source,
  required DownloadCancellationToken? cancellation,
}) async {
  final artifacts = <String, MinecraftDownloadArtifact>{};
  final rawDownloads = config['downloads'];
  final rawClient = rawDownloads is Map<String, dynamic>
      ? rawDownloads['client']
      : null;
  final clientDownload = rawClient is Map<String, dynamic> ? rawClient : null;

  if (clientDownload != null) {
    final expectedSize = clientDownload['size'] is int
        ? clientDownload['size'] as int
        : null;
    var hasClientJar = false;
    for (final candidate in installerClientJarCandidates(
      versionDirectory: versionDirectory.path,
      minecraftPath: root.path,
      versionId: versionId,
      config: config,
    )) {
      if (await fileMatchesSize(candidate, expectedSize)) {
        hasClientJar = true;
        break;
      }
    }
    if (!hasClientJar) {
      addArtifact(
        artifacts,
        versionDirectory.path,
        clientDownload,
        source: source,
        versionId: versionId,
        clientArtifact: true,
      );
    }
  }

  final libraries = config['libraries'];
  if (libraries is List) {
    for (final library in libraries.whereType<Map<String, dynamic>>()) {
      cancellation?.throwIfCancelled();
      if (!installerMatchesRules(library['rules'])) {
        continue;
      }
      final downloads = library['downloads'];
      if (downloads is Map<String, dynamic>) {
        final artifact = downloads['artifact'];
        if (artifact is Map<String, dynamic>) {
          addArtifact(
            artifacts,
            joinPath(root.path, 'libraries'),
            artifact,
            source: source,
            versionId: versionId,
          );
        }
        final classifier = installerNativeClassifier(library);
        final classifiers = downloads['classifiers'];
        final nativeArtifact = classifier == null || classifiers is! Map
            ? null
            : classifiers[classifier];
        if (nativeArtifact is Map<String, dynamic>) {
          addArtifact(
            artifacts,
            joinPath(root.path, 'libraries'),
            nativeArtifact,
            source: source,
            versionId: versionId,
          );
        }
      } else {
        addLegacyLibrary(artifacts, root.path, library, source);
      }
    }
  }

  final assetIndexInfo = config['assetIndex'];
  if (assetIndexInfo is Map<String, dynamic>) {
    await collectAssetRepairArtifacts(
      artifacts: artifacts,
      root: root,
      assetIndexInfo: assetIndexInfo,
      source: source,
      versionId: versionId,
      cancellation: cancellation,
    );
  }
  return artifacts;
}

Future<List<MinecraftDownloadArtifact>> findMissingRepairArtifacts({
  required List<MinecraftDownloadArtifact> artifacts,
  required DownloadCancellationToken? cancellation,
  required void Function(String status)? onProgress,
}) async {
  final missing = <MinecraftDownloadArtifact>[];
  for (var index = 0; index < artifacts.length; index++) {
    cancellation?.throwIfCancelled();
    final artifact = artifacts[index];
    if (!await artifactMatches(artifact)) {
      missing.add(artifact);
    }
    final checked = index + 1;
    if (checked == artifacts.length ||
        checked % 50 == 0 ||
        missing.isNotEmpty) {
      onProgress?.call(
        '正在检查版本文件：$checked/${artifacts.length}，'
        '缺失 ${missing.length} 个',
      );
    }
  }
  return missing;
}

Future<bool> artifactMatches(
  MinecraftDownloadArtifact artifact,
) async {
  final file = File(artifact.path);
  if (!await file.exists()) return false;
  if (artifact.size == null) return true;
  try {
    return (await file.stat()).size == artifact.size;
  } on FileSystemException {
    return false;
  }
}

Future<bool> fileMatchesSize(String path, int? expectedSize) async {
  final file = File(path);
  if (!await file.exists()) return false;
  if (expectedSize == null) return true;
  try {
    return (await file.stat()).size == expectedSize;
  } on FileSystemException {
    return false;
  }
}

Future<void> downloadArtifactBatch({
  required List<MinecraftDownloadArtifact> artifacts,
  required DownloadManager? downloadManager,
  required String groupLabel,
  required DownloadCancellationToken? cancellation,
  required void Function(String status)? onProgress,
}) async {
  if (artifacts.isEmpty) return;

  var completed = 0;
  onProgress?.call('正在补全文件：0/${artifacts.length}');

  if (downloadManager != null) {
    final futures = artifacts.map((artifact) {
      final job = DownloadJob(
        id: downloadManager.createJobId('repair'),
        label: installerLastPathSegment(artifact.path),
        groupLabel: groupLabel,
        kind: '版本补全',
        path: artifact.path,
        totalBytes: artifact.size,
        cancellation: cancellation,
      );
      return downloadManager.enqueue(job, (job) async {
        await downloadArtifact(
          artifact,
          cancellation: cancellation,
          onProgress: (received, total) =>
              job.updateProgress(received, totalBytes: total),
        );
        completed++;
        onProgress?.call('正在补全文件：$completed/${artifacts.length}');
      });
    }).toList();

    Object? firstError;
    StackTrace? firstStack;
    await Future.wait(
      futures.map((future) async {
        try {
          await future;
        } catch (error, stackTrace) {
          firstError ??= error;
          firstStack ??= stackTrace;
        }
      }),
    );
    if (firstError != null) {
      Error.throwWithStackTrace(
        firstError!,
        firstStack ?? StackTrace.current,
      );
    }
    return;
  }

  var nextIndex = 0;
  Future<void> worker() async {
    while (true) {
      final index = nextIndex++;
      if (index >= artifacts.length) return;
      await downloadArtifact(artifacts[index], cancellation: cancellation);
      completed++;
      onProgress?.call('正在补全文件：$completed/${artifacts.length}');
    }
  }

  await Future.wait(
    List.generate(math.min(8, artifacts.length), (_) => worker()),
  );
}

void addArtifact(
  Map<String, MinecraftDownloadArtifact> artifacts,
  String basePath,
  Map<String, dynamic> info, {
  required MinecraftDownloadSource source,
  required String versionId,
  bool clientArtifact = false,
}) {
  final rawUrl = info['url'];
  final relativePath = info['path'];
  if (rawUrl is! String || rawUrl.isEmpty) return;
  final uri = Uri.tryParse(rawUrl);
  if (uri == null || uri.scheme != 'https') {
    throw FormatException('下载清单包含非 HTTPS 文件地址：$rawUrl');
  }
  final path = relativePath is String && relativePath.isNotEmpty
      ? safeJoin(basePath, relativePath)
      : safeJoin(basePath, clientArtifact ? '$versionId.jar' : '');
  if (path == null) {
    throw FormatException('下载清单包含无效文件路径：$relativePath');
  }
  artifacts[path] = MinecraftDownloadArtifact(
    path: path,
    uri: resolveDownloadUriFor(
      uri,
      source: source,
      versionId: versionId,
      clientArtifact: clientArtifact,
    ),
    sha1: info['sha1'] is String ? info['sha1'] as String : null,
    size: info['size'] is int ? info['size'] as int : null,
  );
}

void addLegacyLibrary(
  Map<String, MinecraftDownloadArtifact> artifacts,
  String rootPath,
  Map<String, dynamic> library,
  MinecraftDownloadSource source,
) {
  final coordinate = library['name'];
  if (coordinate is! String) return;
  final parts = coordinate.split(':');
  if (parts.length < 3) return;
  final artifactVersion = parts[2];
  final classifier = parts.length > 3 ? '-${parts[3]}' : '';
  final extension = parts.length > 4 ? parts[4] : 'jar';
  final groupPath = parts[0].replaceAll('.', '/');
  final relative =
      '$groupPath/${parts[1]}/$artifactVersion/'
      '${parts[1]}-$artifactVersion$classifier.$extension';
  final root = library['url'] is String
      ? Uri.tryParse(library['url'] as String)?.host
      : null;
  final uri = Uri.https(
    root == null || root.isEmpty ? 'libraries.minecraft.net' : root,
    '/$relative',
  );
  final path = safeJoin(joinPath(rootPath, 'libraries'), relative);
  if (path != null) {
    artifacts[path] = MinecraftDownloadArtifact(
      path: path,
      uri: resolveDownloadUriFor(uri, source: source, versionId: ''),
    );
  }
}

Future<void> downloadArtifact(
  MinecraftDownloadArtifact artifact, {
  DownloadCancellationToken? cancellation,
  void Function(int received, int total)? onProgress,
}) async {
  cancellation?.throwIfCancelled();
  if (artifact.bytes != null) {
    final destination = File(artifact.path);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(artifact.bytes!, flush: true);
    onProgress?.call(artifact.bytes!.length, artifact.bytes!.length);
    return;
  }
  if (artifact.sourcePath != null) {
    final sourceFile = File(artifact.sourcePath!);
    if (!await sourceFile.exists()) {
      throw FileSystemException('缺少待复制的 Minecraft 资源文件。', sourceFile.path);
    }
    final copiedBytes = await sourceFile.length();
    final destination = File(artifact.path);
    await destination.parent.create(recursive: true);
    if (await destination.exists()) await destination.delete();
    await sourceFile.copy(destination.path);
    onProgress?.call(copiedBytes, copiedBytes);
    return;
  }
  final destination = File(artifact.path);
  if (await destination.exists()) {
    final length = await destination.length();
    if ((artifact.size == null || length == artifact.size) &&
        (artifact.sha1 == null ||
            (await sha1.bind(destination.openRead()).first).toString() ==
                artifact.sha1!.toLowerCase())) {
      onProgress?.call(length, length);
      return;
    }
  }
  await destination.parent.create(recursive: true);
  final temporary = File(
    '${destination.path}.part-${DateTime.now().microsecondsSinceEpoch}',
  );
  final client = HttpClient()
    ..connectionTimeout = minecraftRequestTimeout
    ..userAgent = 'BlockLauncher/1.0.0 (Minecraft installer)';
  void abort() => client.close(force: true);
  cancellation?.addListener(abort);
  try {
    final request = await client
        .getUrl(artifact.uri!)
        .timeout(minecraftRequestTimeout);
    final response = await request.close().timeout(minecraftRequestTimeout);
    cancellation?.throwIfCancelled();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await utf8.decoder.bind(response).join();
      throw HttpException(
        'HTTP ${response.statusCode}: $body',
        uri: artifact.uri,
      );
    }
    final totalBytes =
        artifact.size ??
        (response.contentLength > 0 ? response.contentLength : 0);
    onProgress?.call(0, totalBytes);
    final sink = temporary.openWrite();
    var downloadedBytes = 0;
    try {
      await for (final chunk
          in response.timeout(minecraftRequestTimeout).cast<List<int>>()) {
        cancellation?.throwIfCancelled();
        sink.add(chunk);
        downloadedBytes += chunk.length;
        onProgress?.call(downloadedBytes, totalBytes);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    cancellation?.throwIfCancelled();
    if (artifact.size != null && downloadedBytes != artifact.size) {
      throw FileSystemException(
        '文件大小校验失败（预期 ${artifact.size} 字节，实际 $downloadedBytes 字节）。',
        artifact.uri.toString(),
      );
    }
    if (artifact.sha1 != null) {
      final digest = await sha1.bind(temporary.openRead()).first;
      if (digest.toString() != artifact.sha1!.toLowerCase()) {
        throw FileSystemException(
          'SHA-1 校验失败，已取消安装。',
          artifact.uri.toString(),
        );
      }
    }
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
    onProgress?.call(totalBytes, totalBytes);
  } catch (_) {
    if (cancellation?.isCancelled ?? false) {
      throw const DownloadCancelledException();
    }
    rethrow;
  } finally {
    cancellation?.removeListener(abort);
    client.close(force: true);
    if (await temporary.exists()) await temporary.delete();
  }
}

/// UI-facing entry point for repairing one version.
///
/// The actual verification and download implementation lives in
/// MinecraftDownloadService.repairVersion so it can reuse the launcher's
/// existing DownloadManager and BMCLAPI resolution.
class VersionRepairer {
  const VersionRepairer({required this.repairVersion});

  final VersionRepairExecutor repairVersion;

  Future<void> repair(String versionId) => repairVersion(versionId);
}

typedef VersionReinstallHandler = Future<void> Function(String versionName);

class VersionReinstallException implements Exception {
  const VersionReinstallException(this.message, [this.cause, this.stackTrace]);

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

class VersionReinstaller {
  VersionReinstaller({
    required this.minecraftDirectory,
    required this.versionName,
    required this.reinstallVersion,
    this.onProgress,
  });

  static const List<String> preservedEntries = <String>[
    'mods',
    'config',
    'saves',
    'resourcepacks',
    'shaderpacks',
    'options.txt',
    'servers.dat',
  ];

  final String minecraftDirectory;
  final String versionName;
  final VersionReinstallHandler reinstallVersion;
  final void Function(String message)? onProgress;

  Future<void> reinstall() async {
    _validateVersionName();

    final versionDirPath = _join(minecraftDirectory, 'versions', versionName);
    final versionDir = Directory(versionDirPath);
    if (!await versionDir.exists()) {
      throw VersionReinstallException('版本目录不存在：$versionDirPath');
    }

    final backupRootPath = _join(
      minecraftDirectory,
      'cache',
      'reinstall_backup',
      versionName,
    );

    Directory backupDir;
    try {
      await Directory(_join(minecraftDirectory, 'cache', 'reinstall_backup'))
          .create(recursive: true);

      backupDir = Directory(backupRootPath);
      if (await backupDir.exists()) {
        backupDir = Directory(
          _join(
            backupRootPath,
            DateTime.now().microsecondsSinceEpoch.toString(),
          ),
        );
      }
      await backupDir.create(recursive: true);
    } on Object catch (error, stackTrace) {
      throw VersionReinstallException('请关闭游戏后再试', error, stackTrace);
    }

    final backedUpEntries = <String>[];

    try {
      onProgress?.call('正在备份玩家数据...');
      for (final entryName in preservedEntries) {
        final moved = await _moveEntryToBackup(
          versionDirPath: versionDirPath,
          backupDirPath: backupDir.path,
          entryName: entryName,
        );
        if (moved) backedUpEntries.add(entryName);
      }
    } on Object catch (error, stackTrace) {
      try {
        await _restoreEntries(
          versionDirPath: versionDirPath,
          backupDirPath: backupDir.path,
          entryNames: backedUpEntries,
        );
      } on Object catch (rollbackError, rollbackStackTrace) {
        throw VersionReinstallException(
          '请关闭游戏后再试',
          rollbackError,
          rollbackStackTrace,
        );
      }

      await _deleteEntityIfExists(backupDir.path);
      throw VersionReinstallException('请关闭游戏后再试', error, stackTrace);
    }

    try {
      onProgress?.call('正在清理旧版本文件...');
      if (!isPathInside(versionDirPath, _join(minecraftDirectory, 'versions'))) {
        throw VersionReinstallException('版本目录不在 versions 文件夹内，已拒绝清理。');
      }
      if (await versionDir.exists()) {
        await versionDir.delete(recursive: true);
      }
      await versionDir.create(recursive: true);

      onProgress?.call('正在重新下载并安装版本文件...');
      await reinstallVersion(versionName);
    } on Object catch (error, stackTrace) {
      try {
        await _restoreEntries(
          versionDirPath: versionDirPath,
          backupDirPath: backupDir.path,
          entryNames: backedUpEntries,
        );
      } on Object catch (restoreError, restoreStackTrace) {
        throw VersionReinstallException(
          '请关闭游戏后再试',
          restoreError,
          restoreStackTrace,
        );
      }

      await _deleteEntityIfExists(backupDir.path);
      Error.throwWithStackTrace(error, stackTrace);
    }

    try {
      onProgress?.call('正在还原玩家数据...');
      await _restoreEntries(
        versionDirPath: versionDirPath,
        backupDirPath: backupDir.path,
        entryNames: backedUpEntries,
      );
    } on Object catch (error, stackTrace) {
      throw VersionReinstallException('请关闭游戏后再试', error, stackTrace);
    }

    onProgress?.call('正在清理临时文件...');
    await _deleteEntityIfExists(backupDir.path);
  }

  Future<bool> _moveEntryToBackup({
    required String versionDirPath,
    required String backupDirPath,
    required String entryName,
  }) async {
    final sourcePath = _join(versionDirPath, entryName);
    final sourceType = await FileSystemEntity.type(
      sourcePath,
      followLinks: false,
    );
    if (sourceType == FileSystemEntityType.notFound) return false;

    final backupPath = _join(backupDirPath, entryName);
    await _deleteEntityIfExists(backupPath);

    final source = _entityOfType(sourceType, sourcePath);
    await source.rename(backupPath);
    return true;
  }

  Future<void> _restoreEntries({
    required String versionDirPath,
    required String backupDirPath,
    required List<String> entryNames,
  }) async {
    await Directory(versionDirPath).create(recursive: true);

    for (final entryName in entryNames) {
      final backupPath = _join(backupDirPath, entryName);
      final backupType = await FileSystemEntity.type(
        backupPath,
        followLinks: false,
      );
      if (backupType == FileSystemEntityType.notFound) continue;

      final targetPath = _join(versionDirPath, entryName);
      await _deleteEntityIfExists(targetPath);

      final backupEntity = _entityOfType(backupType, backupPath);
      await backupEntity.rename(targetPath);
    }
  }

  Future<void> _deleteEntityIfExists(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;

    switch (type) {
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
      case FileSystemEntityType.link:
        await Link(path).delete();
      default:
        await File(path).delete();
    }
  }

  FileSystemEntity _entityOfType(FileSystemEntityType type, String path) {
    switch (type) {
      case FileSystemEntityType.directory:
        return Directory(path);
      case FileSystemEntityType.link:
        return Link(path);
      default:
        return File(path);
    }
  }

  void _validateVersionName() {
    if (versionName.trim().isEmpty ||
        versionName == '.' ||
        versionName == '..' ||
        versionName.contains('/') ||
        versionName.contains('\\')) {
      throw ArgumentError.value(versionName, 'versionName', '非法的版本名称');
    }
  }

  String _join(String base, [String? part2, String? part3, String? part4]) {
    var result = base;
    for (final part in <String?>[part2, part3, part4]) {
      if (part == null || part.isEmpty) continue;
      if (!result.endsWith(Platform.pathSeparator)) {
        result += Platform.pathSeparator;
      }
      result += part;
    }
    return result;
  }
}
