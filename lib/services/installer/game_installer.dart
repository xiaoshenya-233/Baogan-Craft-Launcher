// Vanilla client and loader installation.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../core/launcher_log.dart';
import '../../core/path_utils.dart';
import '../download/download_service.dart';
import '../network/api_service.dart';
import 'version_parser.dart';
import 'version_repair.dart';

export 'modpack_installer.dart';
export 'version_parser.dart';
export 'version_repair.dart';

class MinecraftDownloadService {
  const MinecraftDownloadService();

  /// Resolves an artifact URL for the selected download source.
  ///
  /// Kept as an instance member because callers use the service as their
  /// network entry point; the implementation lives in `version_parser.dart`.
  Uri resolveDownloadUri(
    Uri original, {
    required MinecraftDownloadSource source,
    required String versionId,
    bool clientArtifact = false,
  }) => resolveDownloadUriFor(
    original,
    source: source,
    versionId: versionId,
    clientArtifact: clientArtifact,
  );
Future<void> install({
  required String minecraftDirectory,
  required String versionId,
  required MinecraftDownloadSource source,
  DownloadManager? downloadManager,
  String? groupLabel,
  DownloadCancellationToken? cancellation,
  void Function(String status)? onProgress,
}) async {
  cancellation?.throwIfCancelled();
  if (versionId.isEmpty ||
      versionId == '.' ||
      versionId == '..' ||
      versionId.contains('/') ||
      versionId.contains(r'\')) {
    throw ArgumentError.value(versionId, 'versionId', '无效的版本 ID');
  }
  final versionUri = Uri.https(bmclapiHost, '/version/$versionId/json');
  final config = await getJson(versionUri, cancellation: cancellation);
  cancellation?.throwIfCancelled();
  if (config is! Map<String, dynamic> || config['id'] is! String) {
    throw const FormatException('Minecraft 版本配置无效。');
  }
  if (config['id'] != versionId) {
    throw FormatException('请求的版本为 $versionId，但下载清单返回了 ${config['id']}。');
  }

  final root = Directory(minecraftDirectory);
  final versionDirectory = Directory(
    joinPath(root.path, 'versions/$versionId'),
  );
  final artifactsByPath = <String, MinecraftDownloadArtifact>{};
  final virtualCopies = <MinecraftDownloadArtifact>[];
  final clientDownload =
      (config['downloads'] as Map<String, dynamic>?)?['client'];
  if (clientDownload is Map<String, dynamic>) {
    addArtifact(
      artifactsByPath,
      versionDirectory.path,
      clientDownload,
      source: source,
      versionId: versionId,
      clientArtifact: true,
    );
  } else if (config['minecraftArguments'] is! String) {
    throw const FormatException('Minecraft 版本配置没有客户端 JAR 下载信息。');
  }

  final libraries = config['libraries'];
  if (libraries is List) {
    for (final library in libraries.whereType<Map<String, dynamic>>()) {
      if (!installerMatchesRules(library['rules'])) {
        continue;
      }
      final downloads = library['downloads'];
      if (downloads is Map<String, dynamic>) {
        final artifact = downloads['artifact'];
        if (artifact is Map<String, dynamic>) {
          addArtifact(
            artifactsByPath,
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
            artifactsByPath,
            joinPath(root.path, 'libraries'),
            nativeArtifact,
            source: source,
            versionId: versionId,
          );
        }
      } else {
        addLegacyLibrary(artifactsByPath, root.path, library, source);
      }
    }
  }

  final assetIndexInfo = config['assetIndex'];
  Map<String, dynamic>? assetIndex;
  String? assetIndexId;
  if (assetIndexInfo is Map<String, dynamic>) {
    final indexUrl = assetIndexInfo['url'];
    assetIndexId = assetIndexInfo['id'] is String
        ? assetIndexInfo['id'] as String
        : null;
    if (indexUrl is String) {
      assetIndex = await getJson(
        Uri.parse(indexUrl),
        cancellation: cancellation,
      ) as Map<String, dynamic>;
    }
  }
  if (assetIndex != null && assetIndexId != null) {
    final indexPath = joinPath(
      root.path,
      'assets/indexes/$assetIndexId.json',
    );
    artifactsByPath[indexPath] = MinecraftDownloadArtifact.bytes(
      path: indexPath,
      bytes: utf8.encode(jsonEncode(assetIndex)),
    );
    final objects = assetIndex['objects'];
    if (objects is Map<String, dynamic>) {
      final virtualAssets = <String, String>{};
      for (final entry in objects.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;
        final hash = value['hash'];
        if (hash is! String || !sha1HexPattern.hasMatch(hash)) {
          continue;
        }
        final size = value['size'] is int ? value['size'] as int : null;
        final prefix = hash.substring(0, 2);
        final originalUri = Uri.https(
          'resources.download.minecraft.net',
          '/$prefix/$hash',
        );
        final uri = resolveDownloadUriFor(
          originalUri,
          source: source,
          versionId: versionId,
        );
        final objectPath = joinPath(
          root.path,
          'assets/objects/$prefix/$hash',
        );
        artifactsByPath[objectPath] = MinecraftDownloadArtifact(
          path: objectPath,
          uri: uri,
          sha1: hash.toLowerCase(),
          size: size,
        );
        if (assetIndex['virtual'] == true ||
            assetIndex['map_to_resources'] == true) {
          virtualAssets[entry.key] = objectPath;
        }
      }
      if (virtualAssets.isNotEmpty) {
        for (final entry in virtualAssets.entries) {
          final virtualPath = safeJoin(
            joinPath(root.path, 'assets/virtual/$assetIndexId'),
            entry.key,
          );
          if (virtualPath == null) {
            throw FormatException('资产索引包含无效资源路径：${entry.key}');
          }
          virtualCopies.add(
            MinecraftDownloadArtifact.copy(
              path: virtualPath,
              sourcePath: entry.value,
            ),
          );
        }
      }
      if (assetIndex['map_to_resources'] == true) {
        for (final entry in virtualAssets.entries) {
          final resourcePath = safeJoin(
            joinPath(root.path, 'resources'),
            entry.key,
          );
          if (resourcePath == null) {
            throw FormatException('资产索引包含无效资源路径：${entry.key}');
          }
          virtualCopies.add(
            MinecraftDownloadArtifact.copy(
              path: resourcePath,
              sourcePath: entry.value,
            ),
          );
        }
      }
    }
  }

  if (artifactsByPath.isEmpty) {
    throw const FormatException('版本清单中没有可下载的客户端文件。');
  }
  final artifacts = artifactsByPath.values.toList();
  var completed = 0;
  onProgress?.call('正在下载 Minecraft $versionId：0/${artifacts.length}');
  if (downloadManager != null) {
    final futures = artifacts.map((artifact) {
      final job = DownloadJob(
        id: downloadManager.createJobId('minecraft'),
        label: installerLastPathSegment(artifact.path),
        groupLabel: groupLabel ?? 'Minecraft $versionId',
        kind: '游戏版本',
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
        onProgress?.call(
          '正在下载 Minecraft $versionId：$completed/${artifacts.length}',
        );
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
  } else {
    var nextIndex = 0;
    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= artifacts.length) return;
        await downloadArtifact(artifacts[index], cancellation: cancellation);
        completed++;
        onProgress?.call(
          '正在下载 Minecraft $versionId：$completed/${artifacts.length}',
        );
      }
    }

    await Future.wait(
      List.generate(math.min(8, artifacts.length), (_) => worker()),
    );
  }
  for (final copy in virtualCopies) {
    await downloadArtifact(copy, cancellation: cancellation);
  }
  cancellation?.throwIfCancelled();
  await versionDirectory.create(recursive: true);
  final configFile = File(
    joinPath(versionDirectory.path, '$versionId.json'),
  );
  await configFile.writeAsString(jsonEncode(config));
  onProgress?.call('完成：Minecraft $versionId 已安装');
}

Future<void> repairVersion({
  required String minecraftDirectory,
  required String versionId,
  required MinecraftDownloadSource source,
  DownloadManager? downloadManager,
  String? groupLabel,
  DownloadCancellationToken? cancellation,
  void Function(String status)? onProgress,
}) async {
  cancellation?.throwIfCancelled();
  if (versionId.isEmpty ||
      versionId == '.' ||
      versionId == '..' ||
      versionId.contains('/') ||
      versionId.contains(r'\')) {
    throw ArgumentError.value(versionId, 'versionId', '无效的版本 ID');
  }

  final root = Directory(minecraftDirectory);
  final versionsDirectory = Directory(joinPath(root.path, 'versions'));
  final versionDirectory = Directory(
    joinPath(versionsDirectory.path, versionId),
  );
  final configFile = File(
    joinPath(versionDirectory.path, '$versionId.json'),
  );
  if (!await configFile.exists()) {
    throw FileSystemException('版本 JSON 不存在，无法补全文件。', configFile.path);
  }

  final config = await installerLoadVersionConfig(
    configFile,
    versionsDirectory,
    <String>{},
  );
  cancellation?.throwIfCancelled();

  final artifacts = await collectRepairArtifacts(
    root: root,
    versionDirectory: versionDirectory,
    versionId: versionId,
    config: config,
    source: source,
    cancellation: cancellation,
  );
  final missing = await findMissingRepairArtifacts(
    artifacts: artifacts.values.toList(growable: false),
    cancellation: cancellation,
    onProgress: onProgress,
  );

  if (missing.isEmpty) {
    onProgress?.call('版本文件完整，无需补全。');
    return;
  }

  onProgress?.call('正在补全 ${missing.length} 个文件...');
  await downloadArtifactBatch(
    artifacts: missing,
    downloadManager: downloadManager,
    groupLabel: groupLabel ?? '版本补全 · $versionId',
    cancellation: cancellation,
    onProgress: onProgress,
  );
  onProgress?.call('完成：版本「$versionId」文件补全结束');
}

Future<bool> installLoader({
  required String minecraftDirectory,
  required String minecraftVersion,
  required String loader,
  required String loaderVersion,
  required String javaExecutable,
  required MinecraftDownloadSource source,
  DownloadManager? downloadManager,
  String? groupLabel,
  DownloadCancellationToken? cancellation,
  void Function(String status)? onProgress,
}) async {
  cancellation?.throwIfCancelled();
  if (loaderVersion.isEmpty ||
      loaderVersion.contains('/') ||
      loaderVersion.contains(r'\') ||
      loaderVersion.contains('..')) {
    throw FormatException('无效的加载器版本：$loaderVersion');
  }
  final installerUris = await _loaderInstallerUris(
    minecraftVersion: minecraftVersion,
    loader: loader,
    loaderVersion: loaderVersion,
    source: source,
  );
  final installerDirectory = Directory(
    joinPath(Directory.systemTemp.path, 'block-launcher-installers'),
  );
  await installerDirectory.create(recursive: true);
  final installerName = '$loader-$minecraftVersion-$loaderVersion-installer'
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final installerFile = File(
    joinPath(installerDirectory.path, '$installerName.jar'),
  );
  Object? lastDownloadError;
  Process? activeInstallerProcess;
  File? cdnInstaller;
  void abortInstaller() {
    final process = activeInstallerProcess;
    if (process != null) unawaited(terminateProcess(process));
  }

  cancellation?.addListener(abortInstaller);
  Future<void> downloadInstaller(DownloadJob? job) async {
    for (final uri in installerUris) {
      try {
        await downloadArtifact(
          MinecraftDownloadArtifact(path: installerFile.path, uri: uri),
          cancellation: cancellation,
          onProgress: job == null
              ? null
              : (received, total) =>
                    job.updateProgress(received, totalBytes: total),
        );
        lastDownloadError = null;
        return;
      } on HttpException catch (error) {
        lastDownloadError = error;
      } on SocketException catch (error) {
        lastDownloadError = error;
      } on TimeoutException catch (error) {
        lastDownloadError = error;
      }
    }
    if (lastDownloadError != null) throw lastDownloadError!;
  }

  onProgress?.call('正在下载 $loader 安装器…');
  try {
    if (downloadManager != null) {
      final job = DownloadJob(
        id: downloadManager.createJobId('loader'),
        label: '$installerName.jar',
        groupLabel: groupLabel ?? '$loader $loaderVersion 安装器',
        kind: '模组加载器',
        path: installerFile.path,
        cancellation: cancellation,
      );
      await downloadManager.enqueue(job, (job) => downloadInstaller(job));
    } else {
      await downloadInstaller(null);
    }
    cancellation?.throwIfCancelled();

    onProgress?.call('正在安装 $loader $loaderVersion…');
    if (loader == 'optifine') {
      final process = await Process.start(javaExecutable, [
        '-Djava.net.useSystemProxies=true',
        '-jar',
        installerFile.path,
      ], runInShell: false);
      activeInstallerProcess = process;
      final stdout = readProcessOutput(process.stdout);
      final stderr = readProcessOutput(process.stderr);
      final exitCode = await process.exitCode.timeout(
        const Duration(minutes: 10),
        onTimeout: () async {
          await terminateProcess(process);
          throw TimeoutException('OptiFine 安装器等待超时。');
        },
      );
      activeInstallerProcess = null;
      cancellation?.throwIfCancelled();
      final output = '${await stdout}\n${await stderr}'.trim();
      if (exitCode != 0) {
        throw ProcessException(
          javaExecutable,
          ['-jar', installerFile.path],
          output.isEmpty ? 'OptiFine 安装器退出代码：$exitCode' : output,
          exitCode,
        );
      }
      onProgress?.call('OptiFine 安装器已关闭，请重新扫描版本列表确认安装结果。');
      return false;
    }
    if (loader == 'neoforge') {
      try {
        final mirrored = await installerApplyNeoForgeCdnMirror(
          installerFile,
        );
        if (mirrored.path != installerFile.path) {
          cdnInstaller = mirrored;
          onProgress?.call('已启用 NeoForge CDN 镜像加速。');
        }
      } on Object catch (error) {
        LauncherLog.warning(
          'Installer',
          'NeoForge 安装器 CDN 重写失败，继续使用原安装器：$error',
        );
      }
    }
    if (loader == 'fabric') {
      onProgress?.call('正在准备 Fabric 安装环境…');
      await ensureLauncherProfiles(minecraftDirectory);
    }
    final installerToRun = cdnInstaller ?? installerFile;
    final arguments = switch (loader) {
      'fabric' => [
        '-jar',
        installerToRun.path,
        'client',
        '-dir',
        minecraftDirectory,
        '-mcversion',
        minecraftVersion,
        '-loader',
        loaderVersion,
      ],
      'forge' => [
        '-jar',
        installerToRun.path,
        '--installClient',
        minecraftDirectory,
      ],
      'neoforge' => [
        '-jar',
        installerToRun.path,
        '--installClient',
        minecraftDirectory,
      ],
      _ => throw ArgumentError.value(loader, 'loader', '未知的模组加载器'),
    };
    final process = await Process.start(javaExecutable, [
      '-Djava.net.useSystemProxies=true',
      ...arguments,
    ], runInShell: false);
    activeInstallerProcess = process;
    final stdout = readProcessOutput(process.stdout);
    final stderr = readProcessOutput(process.stderr);
    final exitCode = await process.exitCode.timeout(
      const Duration(minutes: 15),
      onTimeout: () async {
        await terminateProcess(process);
        throw TimeoutException('$loader 安装器执行超时。');
      },
    );
    activeInstallerProcess = null;
    cancellation?.throwIfCancelled();
    final output = '${await stdout}\n${await stderr}'.trim();
    if (exitCode != 0) {
      throw ProcessException(
        javaExecutable,
        arguments,
        output.isEmpty ? '$loader 安装器退出代码：$exitCode' : output,
        exitCode,
      );
    }
    onProgress?.call('完成：$loader $loaderVersion 已安装');
    return true;
  } finally {
    cancellation?.removeListener(abortInstaller);
    activeInstallerProcess = null;
    await deleteInstallerFileWithRetry(installerFile);
    if (cdnInstaller != null) {
      await deleteInstallerFileWithRetry(cdnInstaller);
    }
  }
}

Future<List<Uri>> _loaderInstallerUris({
  required String minecraftVersion,
  required String loader,
  required String loaderVersion,
  required MinecraftDownloadSource source,
}) async {
  final encodedMinecraftVersion = Uri.encodeComponent(minecraftVersion);
  final encodedLoaderVersion = Uri.encodeComponent(loaderVersion);

  List<Uri> ordered(Uri bmclapiUri, Uri officialUri) {
    if (source == MinecraftDownloadSource.bmclapi) {
      return [bmclapiUri, officialUri];
    }
    return [officialUri, bmclapiUri];
  }

  switch (loader) {
    case 'forge':
      final bmclapiUri = Uri.https(bmclapiHost, '/forge/download', {
        'mcversion': minecraftVersion,
        'version': loaderVersion,
        'category': 'installer',
        'format': 'jar',
      });
      final officialUri = Uri.https(
        'maven.minecraftforge.net',
        '/net/minecraftforge/forge/$minecraftVersion-$loaderVersion/'
            'forge-$minecraftVersion-$loaderVersion-installer.jar',
      );
      return ordered(bmclapiUri, officialUri);
    case 'neoforge':
      final legacy =
          minecraftVersion == '1.20.1' || loaderVersion.startsWith('47.');
      final Uri bmclapiUri;
      final Uri officialUri;
      if (legacy) {
        bmclapiUri = Uri.https(
          bmclapiHost,
          '/maven/net/neoforged/forge/'
          '$minecraftVersion-$loaderVersion/'
          'forge-$minecraftVersion-$loaderVersion-installer.jar',
        );
        officialUri = Uri.https(
          'maven.neoforged.net',
          '/releases/net/neoforged/forge/'
              '$minecraftVersion-$loaderVersion/'
              'forge-$minecraftVersion-$loaderVersion-installer.jar',
        );
      } else {
        bmclapiUri = Uri.https(
          bmclapiHost,
          '/maven/net/neoforged/neoforge/'
          '$encodedLoaderVersion/'
          'neoforge-$encodedLoaderVersion-installer.jar',
        );
        officialUri = Uri.https(
          'maven.neoforged.net',
          '/releases/net/neoforged/neoforge/'
              '$encodedLoaderVersion/'
              'neoforge-$encodedLoaderVersion-installer.jar',
        );
      }
      return ordered(bmclapiUri, officialUri);
    case 'fabric':
      dynamic metadata;
      try {
        metadata = source == MinecraftDownloadSource.bmclapi
            ? await getJson(
                Uri.https(bmclapiHost, '/fabric-meta/v2/versions/installer'),
              )
            : await getJson(
                Uri.https('meta.fabricmc.net', '/v2/versions/installer'),
              );
      } on Exception {
        metadata = source == MinecraftDownloadSource.bmclapi
            ? await getJson(
                Uri.https('meta.fabricmc.net', '/v2/versions/installer'),
              )
            : await getJson(
                Uri.https(bmclapiHost, '/fabric-meta/v2/versions/installer'),
              );
      }
      String? installerVersion;
      if (metadata is List && metadata.isNotEmpty) {
        final row = metadata.first;
        if (row is Map && row['version'] is String) {
          installerVersion = row['version'] as String;
        }
      }
      installerVersion = installerVersion?.trim();
      if (installerVersion == null || installerVersion.isEmpty) {
        throw const FormatException('Fabric 安装器版本数据格式无效。');
      }
      final encodedInstaller = Uri.encodeComponent(installerVersion);
      final officialUri = Uri.https(
        'maven.fabricmc.net',
        '/net/fabricmc/fabric-installer/'
            '$encodedInstaller/'
            'fabric-installer-$encodedInstaller.jar',
      );
      return [officialUri];
    case 'optifine':
      final parts = loaderVersion.split('-');
      if (parts.length < 2) {
        throw FormatException('OptiFine 版本格式无效：$loaderVersion');
      }
      final mirrorUri = Uri.https(
        bmclapiHost,
        '/optifine/$encodedMinecraftVersion/'
        '${Uri.encodeComponent(parts.first)}/'
        '${Uri.encodeComponent(parts.skip(1).join('-'))}',
      );
      return [mirrorUri];
    default:
      throw ArgumentError.value(loader, 'loader', '未知的模组加载器');
  }
}

}