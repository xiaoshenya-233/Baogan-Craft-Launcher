part of '../launcher_home_page.dart';

extension _MinecraftHelpers on _LauncherHomePageState {
  void _cancelActiveDownload() {
    if (!_downloads.cancel()) return;
    if (!mounted) return;
    _setPageState(() {
      if (_isInstallingMinecraft) {
        _minecraftInstallStatus = '正在取消下载…';
      }
      if (_isDownloadingResources) {
        _activeDownloadTask = '正在取消下载并清理临时文件…';
      }
    });
    _showVersionMessage('正在取消下载并清理临时文件…');
  }

  Future<Set<String>> _snapshotVersionDirectories(
    String minecraftDirectory,
  ) async {
    final result = <String>{};
    final root = Directory(
      '$minecraftDirectory${Platform.pathSeparator}versions',
    );
    if (!await root.exists()) return result;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory) result.add(_normalizedPathKey(entity.path));
    }
    return result;
  }

  Future<void> _deleteNewVersionDirectories(
    String minecraftDirectory,
    Set<String> existing,
  ) async {
    final root = Directory(
      '$minecraftDirectory${Platform.pathSeparator}versions',
    );
    if (!await root.exists()) return;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      if (existing.contains(_normalizedPathKey(entity.path))) continue;
      try {
        await entity.delete(recursive: true);
      } on FileSystemException {
        // 清理失败不应覆盖“下载已取消”的结果。
      }
    }
  }

  Future<void> _cleanupFailedVersionInstall(
    String minecraftDirectory,
    Set<String> existing,
  ) async {
    try {
      await _deleteNewVersionDirectories(minecraftDirectory, existing);
    } catch (_) {
      // The original installation error is more useful than cleanup details.
    }
  }

  String _normalizedPathKey(String path) {
    final normalized = path.replaceAll('/', Platform.pathSeparator);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relative = entity.path
          .substring(source.path.length)
          .replaceFirst(RegExp(r'^[\\/]+'), '');
      final destination = '${target.path}${Platform.pathSeparator}$relative';
      if (entity is Directory) {
        await Directory(destination).create(recursive: true);
      } else if (entity is File) {
        final file = File(destination);
        await file.parent.create(recursive: true);
        await entity.copy(file.path);
      }
    }
  }

  Future<String> _finalizeDownloadedClient({
    required String installedPath,
    required String baseVersionId,
    required String requestedName,
    bool keepSource = false,
  }) async {
    final name = requestedName.trim();
    if (name.isEmpty) return installedPath;
    final source = Directory(installedPath);
    final sourceName = lastPathSegment(installedPath);
    if (sourceName == name) return installedPath;
    final target = Directory(
      '${source.parent.path}${Platform.pathSeparator}$name',
    );
    if (!isPathInside(target.path, source.parent.path)) {
      _showVersionMessage('客户端名称「$name」无效：不能包含路径分隔符。');
      return installedPath;
    }
    if (await target.exists()) {
      _showVersionMessage('客户端名称「$name」已被占用，保留原版本目录名。');
      return installedPath;
    }
    final sourceConfig = File(
      '${source.path}${Platform.pathSeparator}$sourceName.json',
    );
    if (!await sourceConfig.exists()) {
      _showVersionMessage('无法重命名客户端：缺少 $sourceName.json。');
      return installedPath;
    }
    try {
      if (keepSource) {
        await _copyDirectory(source, target);
      } else {
        await source.rename(target.path);
      }
      final resultPath = target.path;
      final renamedConfig = File(
        '${target.path}${Platform.pathSeparator}$sourceName.json',
      );
      final targetConfig = File(
        '${target.path}${Platform.pathSeparator}$name.json',
      );
      await renamedConfig.rename(targetConfig.path);
      final decoded = jsonDecode(await targetConfig.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('版本配置不是 JSON 对象。');
      }
      decoded['id'] = name;
      decoded['minecraftVersion'] = baseVersionId;
      if (decoded['inheritsFrom'] == null && decoded['jar'] == null) {
        decoded['jar'] = baseVersionId;
      }
      await targetConfig.writeAsString(jsonEncode(decoded), flush: true);
      return resultPath;
    } on FileSystemException catch (error) {
      if (keepSource && await target.exists()) {
        try {
          await target.delete(recursive: true);
        } on FileSystemException {
          // 保留原始版本目录优先。
        }
      }
      _showVersionMessage('无法创建客户端副本：${error.message}');
    } on FormatException catch (error) {
      _showVersionMessage('客户端配置无效，无法重命名：${error.message}');
    }
    return target.existsSync() ? target.path : installedPath;
  }

  Future<bool> _installFabricApiForClient({
    required String clientDirectory,
    required String minecraftVersion,
    required DownloadCancellationToken cancellation,
  }) async {
    cancellation.throwIfCancelled();
    if (mounted) {
      _setPageState(() {
        _minecraftInstallStatus =
            '正在查找 Minecraft $minecraftVersion 的 Fabric API…';
        _activeDownloadTask = _minecraftInstallStatus;
      });
    }
    try {
      final file = await ModrinthService.fetchFabricApiFile(
        minecraftVersion,
        cancellation: cancellation,
      );
      cancellation.throwIfCancelled();
      final targetDirectory = Directory(
        minecraftVersionSubfolder(clientDirectory, 'mods'),
      );
      final targetFile = File(
        '${targetDirectory.path}${Platform.pathSeparator}${file.filename}',
      );
      if (await targetFile.exists()) {
        _showVersionMessage('Fabric API 已存在于客户端的 mods 文件夹。');
        return true;
      }
      if (mounted) {
        _setPageState(() {
          _minecraftInstallStatus = '正在下载 Fabric API：${file.filename}';
          _activeDownloadTask = _minecraftInstallStatus;
        });
      }
      final job = DownloadJob(
        id: _downloadManager.createJobId('fabric-api'),
        label: file.filename,
        groupLabel: 'Fabric API · Minecraft $minecraftVersion',
        kind: '模组',
        path: targetFile.path,
        cancellation: cancellation,
      );
      late String downloadedPath;
      await _downloadManager.enqueue(job, (job) async {
        downloadedPath = await ModrinthService.downloadFile(
          file,
          targetDirectory,
          cancellation: cancellation,
          onProgress: (received, total) =>
              job.updateProgress(received, totalBytes: total),
        );
      });
      _showVersionMessage('Fabric API 已放入客户端的 mods 文件夹：$downloadedPath');
      return true;
    } on DownloadCancelledException {
      rethrow;
    } on SocketException catch (error) {
      _showVersionMessage('Fabric API 下载连接失败：${error.message}');
    } on HttpException catch (error) {
      _showVersionMessage('Fabric API 下载失败：${error.message}');
    } on HandshakeException catch (error) {
      _showVersionMessage('Fabric API TLS 连接失败：${error.message}');
    } on TimeoutException {
      _showVersionMessage('Fabric API 下载超时，客户端已完成安装，可稍后在资源页重试。');
    } on FormatException catch (error) {
      _showVersionMessage('无法找到兼容的 Fabric API：${error.message}');
    } on FileSystemException catch (error) {
      _showVersionMessage('无法保存 Fabric API：${error.message}');
    }
    return false;
  }

  void _failMinecraftInstall(String error) {
    if (!mounted) return;
    _setPageState(() {
      _isInstallingMinecraft = false;
      _minecraftInstallError = error;
      _minecraftInstallStatus = null;
      _activeDownloadTask = null;
    });
    _showVersionMessage(error);
  }
}
