part of '../launcher_home_page.dart';

extension _ModpackActions on _LauncherHomePageState {
  Future<void> _importModpack() async {
    if (_isInstallingMinecraft || _isDownloadingResources) {
      _showVersionMessage('已有安装或下载任务正在进行，请等待完成后再导入整合包。');
      return;
    }
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: '选择要导入的整合包',
        type: FileType.custom,
        allowedExtensions: ['zip', 'mrpack'],
      );
      if (!mounted || result.isEmpty) return;
      final picked = result.single;
      final path = picked.path;
      if (path == null || path.trim().isEmpty) {
        _showVersionMessage('无法读取所选整合包文件路径，请重试。');
        return;
      }
      await _installModpackArchive(File(path));
    } on PlatformException catch (error) {
      _showVersionMessage('无法打开文件选择器：${error.message ?? error.code}');
    }
  }

  Future<void> _installModpackArchive(File archiveFile) async {
    late final String targetPath;
    try {
      targetPath = _minecraftPath.trim().isNotEmpty
          ? _minecraftPath.trim()
          : _defaultMinecraftDirectory();
    } on FileSystemException catch (error) {
      _showVersionMessage(error.message);
      return;
    }

    final cancellation = DownloadCancellationToken();
    String? clientPath;
    var completed = false;
    _environment.selectSource(targetPath);
    _setPageState(() {
      _isInstallingMinecraft = true;
      _minecraftInstallStatus =
          '正在读取整合包：${archiveFile.path.split(Platform.pathSeparator).last}';
      _minecraftInstallError = null;
      _activeDownloadToken = cancellation;
      _activeDownloadTask = _minecraftInstallStatus;
    });
    await _saveMinecraftSources();

    try {
      final beforeInstall = await ModpackInstaller.snapshotVersions(targetPath);
      var package = await const ModpackInstaller().open(archiveFile);
      var manifest = package.manifest;
      var curseForgeFailureCount = 0;
      if (package.format == ModpackFormat.curseForge) {
        final curseForgeManifest = package.curseForgeManifest;
        if (curseForgeManifest == null) {
          throw const FormatException('CurseForge manifest 解析结果为空。');
        }
        if (!mounted) return;
        _setPageState(() {
          _minecraftInstallStatus = '正在从 CurseForge 获取文件信息...';
          _activeDownloadTask = _minecraftInstallStatus;
        });
        final downloader = CurseForgeDownloader();
        try {
          final result = await downloader.fetchAll(
            curseForgeManifest.files,
            isCancelled: () => cancellation.isCancelled,
            onProgress: (completed, total) {
              if (!mounted) return;
              _setPageState(() {
                _minecraftInstallStatus =
                    '正在从 CurseForge 获取文件信息... $completed/$total';
                _activeDownloadTask = _minecraftInstallStatus;
              });
            },
          );
          curseForgeFailureCount = result.failures.length;
          for (final failure in result.failures) {
            LauncherLog.warning(
              'Modpack',
              'CurseForge 文件不可下载：${failure.projectId}/${failure.fileId} '
                  '${failure.reason}',
            );
          }
          final entries = result.tasks
              .map(
                (task) => ModpackFileEntry(
                  path: 'mods/${task.fileName}',
                  downloads: [task.url],
                  clientRequired: true,
                ),
              )
              .toList(growable: false);
          package = package.withManifest(
            package.manifest.copyWith(files: entries),
          );
          manifest = package.manifest;
        } finally {
          downloader.close();
        }
        cancellation.throwIfCancelled();
      }
      if (manifest.loader != null &&
          !const ['neoforge', 'forge', 'fabric'].contains(manifest.loader)) {
        throw FormatException('整合包使用了暂不支持的加载器：${manifest.loader}');
      }

      await _ensureModpackBase(
        targetPath: targetPath,
        manifest: manifest,
        cancellation: cancellation,
      );
      cancellation.throwIfCancelled();
      await _catalog.loadVersions();
      var profile = _findModpackProfile(targetPath, manifest);
      if (profile == null && manifest.loader != null) {
        profile = await _ensureModpackLoader(
          targetPath: targetPath,
          manifest: manifest,
          cancellation: cancellation,
        );
      }
      if (profile == null) {
        throw const FormatException('找不到匹配的 Minecraft/加载器版本。');
      }

      final clientName = _uniqueModpackClientName(manifest.name, targetPath);
      clientPath = await _createModpackClient(
        profile: profile,
        baseVersionId: manifest.minecraftVersion,
        clientName: clientName,
      );
      final clientDirectory = Directory(clientPath);
      await clientDirectory.create(recursive: true);
      await File('${clientDirectory.path}${Platform.pathSeparator}modpack.json')
          .writeAsString(
            jsonEncode({
              'name': manifest.name,
              'versionId': manifest.versionId,
              'minecraftVersion': manifest.minecraftVersion,
              'loader': manifest.loader,
              'loaderVersion': manifest.loaderVersion,
              'installedAt': DateTime.now().toIso8601String(),
            }),
            flush: true,
          );

      if (!mounted) return;
      _setPageState(() {
        _minecraftInstallStatus =
            '正在安装整合包：${manifest.name}（${manifest.minecraftVersion}）';
        _activeDownloadTask = _minecraftInstallStatus;
      });
      final summary = await const ModpackInstaller().install(
        package: package,
        clientDirectory: clientPath,
        isCancelled: () => cancellation.isCancelled,
        beforeInstall: beforeInstall,
        downloadFile: (entry, destination) => _downloadModpackFile(
          entry: entry,
          destination: destination,
          manifest: manifest,
          cancellation: cancellation,
        ),
        onProgress: (status) {
          if (!mounted) return;
          _setPageState(() {
            _minecraftInstallStatus = status;
            _activeDownloadTask = status;
          });
        },
      );
      cancellation.throwIfCancelled();
      await _catalog.loadVersions();
      await _catalog.selectLaunchVersion(clientPath);
      if (!mounted) return;
      completed = true;
      final warning = curseForgeFailureCount > 0
          ? ' 有 $curseForgeFailureCount 个模组无法自动下载，请手动前往网页下载。'
          : '';
      _setPageState(() {
        _isInstallingMinecraft = false;
        _minecraftInstallStatus =
            '整合包「${manifest.name}」安装完成：'
            '${summary.downloadedFiles} 个文件，${summary.overriddenFiles} 个覆盖文件。'
            '$warning';
        _minecraftInstallError = null;
        _activeDownloadTask = null;
      });
      _showVersionMessage(
        '整合包「${manifest.name}」已安装到 $clientPath，并已选中该客户端。'
        '$warning',
      );
    } on CurseForgeDownloadCancelledException {
      _showVersionMessage('整合包安装已取消。');
      if (mounted) {
        _setPageState(() {
          _isInstallingMinecraft = false;
          _minecraftInstallStatus = null;
          _activeDownloadTask = null;
        });
      }
    } on DownloadCancelledException {
      _showVersionMessage('整合包安装已取消，临时客户端和下载文件已清理。');
      if (mounted) {
        _setPageState(() {
          _isInstallingMinecraft = false;
          _minecraftInstallStatus = null;
          _activeDownloadTask = null;
        });
      }
    } on ModpackCancelledException {
      _showVersionMessage('整合包安装已取消，临时客户端和下载文件已清理。');
      if (mounted) {
        _setPageState(() {
          _isInstallingMinecraft = false;
          _minecraftInstallStatus = null;
          _activeDownloadTask = null;
        });
      }
    } on HttpException catch (error) {
      _failModpackInstall('整合包文件下载失败：${error.message}');
    } on SocketException catch (error) {
      _failModpackInstall('整合包文件下载连接失败：${error.message}');
    } on TimeoutException {
      _failModpackInstall('整合包安装超时，请检查网络后重试。');
    } on FormatException catch (error) {
      _failModpackInstall('整合包格式无效：${error.message}');
    } on FileSystemException catch (error) {
      _failModpackInstall('写入整合包文件失败：${error.message}');
    } on IOException catch (error) {
      _failModpackInstall('安装整合包失败：$error');
    } on PlatformException catch (error) {
      _failModpackInstall('无法打开整合包文件：${error.message ?? error.code}');
    } finally {
      if (!completed && clientPath != null) {
        try {
          if (!isPathInside(clientPath, joinPath(targetPath, 'versions'))) {
            LauncherLog.warning('Modpack', '拒绝清理 versions 之外的目录：$clientPath');
          } else {
            final directory = Directory(clientPath);
            if (await directory.exists()) {
              await directory.delete(recursive: true);
            }
          }
        } on FileSystemException {
          // 保留残留目录，避免清理失败掩盖原始错误。
        }
      }
      // Remove leftovers of this modpack run (partial downloads, installer
      // staging files) so repeated imports cannot accumulate cache junk.
      try {
        await PathManager.instance.clearCacheTemp();
      } on FileSystemException {
        // A locked temp file is retried by the next launch.
      }
      if (mounted && identical(_activeDownloadToken, cancellation)) {
        _setPageState(() => _activeDownloadToken = null);
      }
      if (mounted && _isInstallingMinecraft && !completed) {
        _setPageState(() => _isInstallingMinecraft = false);
      }
    }
  }

  void _failModpackInstall(String message) {
    if (!mounted) return;
    _setPageState(() {
      _isInstallingMinecraft = false;
      _minecraftInstallError = message;
      _minecraftInstallStatus = null;
      _activeDownloadTask = null;
    });
    _showVersionMessage(message);
  }

  Future<void> _ensureModpackBase({
    required String targetPath,
    required ModpackManifest manifest,
    required DownloadCancellationToken cancellation,
  }) async {
    final baseDirectory = Directory(
      '$targetPath${Platform.pathSeparator}versions'
      '${Platform.pathSeparator}${manifest.minecraftVersion}',
    );
    final baseConfig = File(
      '${baseDirectory.path}${Platform.pathSeparator}'
      '${manifest.minecraftVersion}.json',
    );
    final baseJar = File(
      '${baseDirectory.path}${Platform.pathSeparator}'
      '${manifest.minecraftVersion}.jar',
    );
    if (await baseConfig.exists() && await baseJar.exists()) {
      cancellation.throwIfCancelled();
      return;
    }
    _setPageState(() {
      _minecraftInstallStatus =
          '正在安装基础 Minecraft ${manifest.minecraftVersion}…';
      _activeDownloadTask = _minecraftInstallStatus;
    });
    await _downloadService.install(
      minecraftDirectory: targetPath,
      versionId: manifest.minecraftVersion,
      source: _minecraftDownloadSource,
      downloadManager: _downloadManager,
      groupLabel: '整合包基础 · Minecraft ${manifest.minecraftVersion}',
      cancellation: cancellation,
      onProgress: (status) {
        if (!mounted) return;
        _setPageState(() {
          _minecraftInstallStatus = status;
          _activeDownloadTask = status;
        });
      },
    );
    cancellation.throwIfCancelled();
  }

  MinecraftVersion? _findModpackProfile(
    String targetPath,
    ModpackManifest manifest,
  ) {
    final candidates = _localVersions.where((candidate) {
      final sameRoot = _samePath(candidate.minecraftPath, targetPath);
      final sameMinecraft =
          candidate.minecraftVersion == manifest.minecraftVersion ||
          candidate.id == manifest.minecraftVersion;
      final sameLoader = manifest.loader == null
          ? candidate.loaderType == null
          : candidate.loaderType?.toLowerCase() == manifest.loader;
      return sameRoot && sameMinecraft && sameLoader;
    }).toList();
    if (candidates.isEmpty) return null;
    if (manifest.loaderVersion != null) {
      final exact = candidates
          .where(
            (candidate) => candidate.loaderVersion == manifest.loaderVersion,
          )
          .firstOrNull;
      if (exact != null) return exact;
    }
    return candidates.last;
  }

  Future<MinecraftVersion?> _ensureModpackLoader({
    required String targetPath,
    required ModpackManifest manifest,
    required DownloadCancellationToken cancellation,
  }) async {
    final loader = manifest.loader;
    final loaderVersion = manifest.loaderVersion;
    if (loader == null) return null;
    if (loaderVersion == null || loaderVersion.isEmpty) {
      throw const FormatException('整合包没有声明加载器版本。');
    }
    final loaderType = MinecraftLoader.values
        .where((candidate) => candidate.apiName == loader)
        .firstOrNull;
    if (loaderType == null) {
      throw FormatException('暂不支持加载器：$loader');
    }
    _setPageState(() {
      _minecraftInstallStatus = '正在安装 ${loaderType.label} $loaderVersion…';
      _activeDownloadTask = _minecraftInstallStatus;
    });
    final javaExecutable = await _resolveInstallerJava(
      minecraftDirectory: targetPath,
      versionId: manifest.minecraftVersion,
    );
    cancellation.throwIfCancelled();
    await _downloadService.installLoader(
      minecraftDirectory: targetPath,
      minecraftVersion: manifest.minecraftVersion,
      loader: loaderType.apiName,
      loaderVersion: loaderVersion,
      javaExecutable: javaExecutable,
      source: _minecraftDownloadSource,
      downloadManager: _downloadManager,
      groupLabel: '整合包加载器 · ${loaderType.label} $loaderVersion',
      cancellation: cancellation,
      onProgress: (status) {
        if (!mounted) return;
        _setPageState(() {
          _minecraftInstallStatus = status;
          _activeDownloadTask = status;
        });
      },
    );
    cancellation.throwIfCancelled();
    await _catalog.loadVersions();
    return _findModpackProfile(targetPath, manifest);
  }

  Future<void> _downloadModpackFile({
    required ModpackFileEntry entry,
    required String destination,
    required ModpackManifest manifest,
    required DownloadCancellationToken cancellation,
  }) async {
    final target = File(destination);
    if (entry.sha1 != null && await target.exists()) {
      try {
        final digest = sha1.convert(await target.readAsBytes()).toString();
        if (digest == entry.sha1) return;
      } on FileSystemException {
        // Redownload the damaged file.
      }
    }
    await target.parent.create(recursive: true);
    final job = DownloadJob(
      id: _downloadManager.createJobId('modpack'),
      label: entry.path.split('/').last,
      groupLabel: '整合包 · ${manifest.name}',
      kind: '整合包文件',
      path: destination,
      totalBytes: entry.fileSize,
      cancellation: cancellation,
    );
    await _downloadManager.enqueue(
      job,
      (job) => _downloadModpackArtifact(
        entry: entry,
        destination: destination,
        cancellation: cancellation,
        onProgress: (received, total) =>
            job.updateProgress(received, totalBytes: total),
      ),
    );
  }

  Future<void> _downloadModpackArtifact({
    required ModpackFileEntry entry,
    required String destination,
    required DownloadCancellationToken cancellation,
    required void Function(int received, int total) onProgress,
  }) async {
    Object? lastError;
    for (final downloadUrl in entry.downloads) {
      cancellation.throwIfCancelled();
      final uri = Uri.tryParse(downloadUrl);
      if (uri == null || uri.scheme != 'https') continue;
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20)
        ..userAgent = 'BlockLauncher/1.0.0 (modpack installer)';
      void abort() => client.close(force: true);
      cancellation.addListener(abort);
      final temporary = File(
        '$destination.part-${DateTime.now().microsecondsSinceEpoch}',
      );
      IOSink? sink;
      try {
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 30));
        request.headers.set(HttpHeaders.acceptHeader, '*/*');
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        cancellation.throwIfCancelled();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = HttpException('HTTP ${response.statusCode}', uri: uri);
          await response.drain<void>();
          continue;
        }
        final totalBytes = response.contentLength > 0
            ? response.contentLength
            : entry.fileSize ?? 0;
        onProgress(0, totalBytes);
        sink = temporary.openWrite();
        final digestSink = DigestSink();
        final digestConverter = sha1.startChunkedConversion(digestSink);
        var receivedBytes = 0;
        await for (final chunk in response.timeout(
          const Duration(seconds: 60),
        )) {
          cancellation.throwIfCancelled();
          sink.add(chunk);
          digestConverter.add(chunk);
          receivedBytes += chunk.length;
          onProgress(receivedBytes, totalBytes);
        }
        digestConverter.close();
        await sink.flush();
        await sink.close();
        sink = null;
        final digest = digestSink.value.toString();
        if (entry.sha1 != null && digest != entry.sha1) {
          throw FormatException(
            '文件校验失败：${entry.path}（期望 ${entry.sha1}，实际 $digest）',
          );
        }
        final target = File(destination);
        if (await target.exists()) await target.delete();
        await temporary.rename(target.path);
        onProgress(totalBytes, totalBytes);
        return;
      } on DownloadCancelledException {
        rethrow;
      } on Object catch (error) {
        lastError = error;
      } finally {
        cancellation.removeListener(abort);
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
            // The temp file can be cleaned by the caller later.
          }
        }
      }
    }
    if (lastError != null) throw lastError;
    throw FormatException('整合包文件没有可用的 HTTPS 下载地址：${entry.path}');
  }

  Future<String> _createModpackClient({
    required MinecraftVersion profile,
    required String baseVersionId,
    required String clientName,
  }) async {
    final source = Directory(profile.directoryPath);
    final target = Directory(
      '${source.parent.path}${Platform.pathSeparator}$clientName',
    );
    if (await target.exists()) {
      throw FileSystemException('客户端目录已存在', target.path);
    }
    final sourceName = lastPathSegment(source.path);
    final sourceConfig = File(
      '${source.path}${Platform.pathSeparator}$sourceName.json',
    );
    if (!await sourceConfig.exists()) {
      throw FileSystemException('版本配置不存在', sourceConfig.path);
    }
    final decoded = jsonDecode(await sourceConfig.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('版本配置不是 JSON 对象。');
    }
    await target.create(recursive: true);
    decoded['id'] = clientName;
    decoded['minecraftVersion'] = baseVersionId;
    if (decoded['inheritsFrom'] == null && decoded['jar'] == null) {
      decoded['jar'] = baseVersionId;
    }
    await File('${target.path}${Platform.pathSeparator}$clientName.json')
        .writeAsString(jsonEncode(decoded), flush: true);

    final sourceJar = File(
      '${source.path}${Platform.pathSeparator}$sourceName.jar',
    );
    if (await sourceJar.exists()) {
      await sourceJar.copy(
        '${target.path}${Platform.pathSeparator}$clientName.jar',
      );
    }
    return target.path;
  }

  String _uniqueModpackClientName(String rawName, String targetPath) {
    var base = rawName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (base.isEmpty) base = '整合包';
    if (base.length > 48) base = base.substring(0, 48).trim();
    final versionsDirectory = Directory(
      '$targetPath${Platform.pathSeparator}versions',
    );
    var candidate = base;
    var counter = 2;
    while (!isValidMinecraftClientName(candidate) ||
        Directory(
          '${versionsDirectory.path}${Platform.pathSeparator}$candidate',
        ).existsSync()) {
      candidate = '$base $counter';
      counter++;
    }
    return candidate;
  }
}
