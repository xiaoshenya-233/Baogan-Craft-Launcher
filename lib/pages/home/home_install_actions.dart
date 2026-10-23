part of '../launcher_home_page.dart';

extension _MinecraftActions on _LauncherHomePageState {
  Future<MinecraftVersion?> _chooseDownloadClient({
    List<MinecraftVersion>? candidates,
  }) async {
    if (_isChoosingDownloadClient) return null;
    final installedVersions = candidates ?? _localVersions;
    if (installedVersions.isEmpty) {
      _showVersionMessage(_l10n.homeNoClientsFound);
      _shell.selectTab(LauncherTab.versions);
      return null;
    }

    final remembered = installedVersions.where(
      (version) => version.directoryPath == _preferredDownloadVersionId,
    );
    if (remembered.isNotEmpty) return remembered.first;

    _setPageState(() => _isChoosingDownloadClient = true);
    var selection =
        installedVersions.any(
          (version) => version.directoryPath == _selectedLaunchVersionId,
        )
        ? _selectedLaunchVersionId
        : installedVersions.first.directoryPath;
    try {
      final chosenId = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              candidates == null
                  ? _l10n.homeInstallPickClientTitle
                  : _l10n.homeInstallPickFabricClientTitle,
            ),
            content: SizedBox(
              width: 420,
              child: DropdownButtonFormField<String>(
                initialValue: selection,
                decoration: InputDecoration(
                  labelText: _l10n.homeInstallTargetLabel,
                ),
                items: installedVersions
                    .map(
                      (version) => DropdownMenuItem(
                        value: version.directoryPath,
                        child: Text(
                          '${version.id} · ${version.loaderType ?? _l10n.versionVanilla}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => selection = value),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_l10n.actionCancel),
              ),
              FilledButton(
                onPressed: selection == null
                    ? null
                    : () => Navigator.pop(dialogContext, selection),
                child: Text(_l10n.homeRememberAndContinue),
              ),
            ],
          ),
        ),
      );
      if (!mounted || chosenId == null) return null;
      await _catalog.savePreferredDownloadVersion(chosenId);
      return _localVersions
          .where((version) => version.directoryPath == chosenId)
          .firstOrNull;
    } on FormatException catch (error) {
      _showVersionMessage(
        _l10n.homeSaveClientSelectionFailed(error.message),
      );
      return null;
    } on FileSystemException catch (error) {
      _showVersionMessage(
        _l10n.homeSaveClientSelectionFailed(error.message),
      );
      return null;
    } finally {
      if (mounted) _setPageState(() => _isChoosingDownloadClient = false);
    }
  }

  Future<void> _loadMinecraftCatalog() async {
    if (_isLoadingMinecraftCatalog || _minecraftCatalog.isNotEmpty) return;
    LauncherLog.info('Catalog', '开始获取 Minecraft 版本列表');
    final requestId = ++_minecraftCatalogRequestId;
    _setPageState(() {
      _isLoadingMinecraftCatalog = true;
      _minecraftCatalogError = null;
    });
    try {
      final versions = await _catalogService.fetchMinecraftVersions();
      if (!mounted || requestId != _minecraftCatalogRequestId) return;
      final selectedVersion = _selectedMinecraftVersion;
      final nextVersion =
          versions.any((version) => version.id == selectedVersion)
          ? selectedVersion
          : versions
                    .where(
                      (version) =>
                          MinecraftReleaseCategory.forVersion(version) ==
                          MinecraftReleaseCategory.release,
                    )
                    .firstOrNull
                    ?.id ??
                versions.firstOrNull?.id;
      _setPageState(() {
        _minecraftCatalog = versions;
        _selectedMinecraftVersion = nextVersion;
        _isLoadingMinecraftCatalog = false;
      });
    } on HttpException catch (error) {
      _finishMinecraftCatalogLoad(requestId, error.message);
    } on SocketException catch (error) {
      _finishMinecraftCatalogLoad(
        requestId,
        _l10n.homeNetworkFailed(error.message),
      );
    } on IOException catch (error) {
      _finishMinecraftCatalogLoad(
        requestId,
        _l10n.homeCatalogReadFailed('$error'),
      );
    } on TimeoutException {
      _finishMinecraftCatalogLoad(requestId, _l10n.homeCatalogTimeout);
    } on FormatException catch (error) {
      _finishMinecraftCatalogLoad(
        requestId,
        _l10n.homeVersionDataInvalid(error.message),
      );
    }
  }

  void _finishMinecraftCatalogLoad(int requestId, String error) {
    if (!mounted || requestId != _minecraftCatalogRequestId) return;
    _setPageState(() {
      _minecraftCatalogError = error;
      _isLoadingMinecraftCatalog = false;
    });
  }

  Future<void> _loadLoaderVersions(MinecraftLoader loader) async {
    final minecraftVersion = _selectedMinecraftVersion;
    if (minecraftVersion == null || minecraftVersion.isEmpty) return;
    LauncherLog.info(
      'Catalog',
      _l10n.homeLoaderFetchStatus(loader.label, minecraftVersion),
    );
    if (_loaderVersions.containsKey(loader) ||
        _loadingLoaderVersions.contains(loader)) {
      return;
    }
    final requestId = (_loaderRequestIds[loader] ?? 0) + 1;
    _loaderRequestIds[loader] = requestId;
    _setPageState(() {
      _loadingLoaderVersions.add(loader);
      _loaderVersionErrors.remove(loader);
    });
    try {
      final versions = await _catalogService.fetchLoaderVersions(
        loader.apiName,
        minecraftVersion,
      );
      if (!mounted || _loaderRequestIds[loader] != requestId) return;
      _setPageState(() {
        _loaderVersions[loader] = versions;
        _loadingLoaderVersions.remove(loader);
        _selectedLoaderVersion = versions.firstOrNull;
      });
    } on HttpException catch (error) {
      _finishLoaderVersionLoad(loader, requestId, error.message);
    } on SocketException catch (error) {
      _finishLoaderVersionLoad(
        loader,
        requestId,
        _l10n.homeNetworkFailed(error.message),
      );
    } on IOException catch (error) {
      _finishLoaderVersionLoad(
        loader,
        requestId,
        _l10n.homeCatalogReadFailed('$error'),
      );
    } on TimeoutException {
      _finishLoaderVersionLoad(loader, requestId, _l10n.homeCatalogTimeout);
    } on FormatException catch (error) {
      _finishLoaderVersionLoad(
        loader,
        requestId,
        _l10n.homeLoaderDataInvalid(error.message),
      );
    }
  }

  void _finishLoaderVersionLoad(
    MinecraftLoader loader,
    int requestId,
    String error,
  ) {
    if (!mounted || _loaderRequestIds[loader] != requestId) return;
    _setPageState(() {
      _loadingLoaderVersions.remove(loader);
      _loaderVersionErrors[loader] = error;
    });
  }

  void _selectMinecraftVersion(String? version) {
    if (version == null || version == _selectedMinecraftVersion) return;
    _setPageState(() {
      _selectedMinecraftVersion = version;
      _selectedLoaderVersion = null;
      _loaderVersions.clear();
      _loaderVersionErrors.clear();
      _loadingLoaderVersions.clear();
      for (final loader in MinecraftLoader.values) {
        _loaderRequestIds[loader] = (_loaderRequestIds[loader] ?? 0) + 1;
      }
    });
    final selectedLoader = _selectedMinecraftLoader;
    if (selectedLoader != null) unawaited(_loadLoaderVersions(selectedLoader));
  }

  String _defaultMinecraftDirectory() {
    final gameRoot = PathManager.instance.gameRoot;
    if (gameRoot != null) return gameRoot;
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return joinPath(appData, '.minecraft');
      }
    }
    final home = Platform.environment['HOME'];
    if (Platform.isMacOS && home != null && home.isNotEmpty) {
      return joinPath(home, 'Library/Application Support/minecraft');
    }
    if (home != null && home.isNotEmpty) {
      return joinPath(home, '.minecraft');
    }
    throw const FileSystemException(
      '无法确定默认 Minecraft 目录，请先在版本管理中选择 .minecraft 文件夹。',
    );
  }

  Future<void> _installSelectedMinecraft() async {
    if (_isInstallingMinecraft || _isDownloadingResources) {
      _showVersionMessage(_l10n.homeDownloadBusy);
      return;
    }
    final version = _selectedMinecraftVersion;
    if (version == null || version.isEmpty) {
      _showVersionMessage(_l10n.homeSelectMinecraftVersionFirst);
      return;
    }
    if (_selectedMinecraftLoader != null &&
        (_selectedLoaderVersion == null || _selectedLoaderVersion!.isEmpty)) {
      _showVersionMessage(
        _l10n.homeSelectLoaderVersionFirst(_selectedMinecraftLoader!.label),
      );
      return;
    }
    final requestedName = _minecraftClientNameController.text.trim();
    if (requestedName.isNotEmpty &&
        !isValidMinecraftClientName(requestedName)) {
      _showVersionMessage(_l10n.homeInvalidClientName);
      return;
    }
    late final String targetPath;
    try {
      final currentPath = _minecraftPath.trim();
      targetPath = currentPath.isNotEmpty
          ? currentPath
          : _defaultMinecraftDirectory();
    } on FileSystemException {
      _showVersionMessage(_l10n.homeChooseMinecraftFolder);
      return;
    }
    final requestedClientDirectory = requestedName.isEmpty
        ? null
        : Directory(
            '$targetPath${Platform.pathSeparator}versions'
            '${Platform.pathSeparator}$requestedName',
          );
    if (requestedClientDirectory != null &&
        await requestedClientDirectory.exists()) {
      _showVersionMessage(_l10n.homeClientNameExists(requestedName));
      return;
    }
    final existingVersionDirectories = await _snapshotVersionDirectories(
      targetPath,
    );
    final cancellation = DownloadCancellationToken();
    _environment.selectSource(targetPath);
    _setPageState(() {
      _isInstallingMinecraft = true;
      _minecraftInstallStatus = _l10n.homePreparingDownload(version);
      _minecraftInstallError = null;
      _activeDownloadToken = cancellation;
      _activeDownloadTask = _minecraftInstallStatus;
    });
    await _saveMinecraftSources();
    final selectedLoader = _selectedMinecraftLoader;
    final loaderVersion = _selectedLoaderVersion;
    var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
    String? installedPath;
    var clientInstalled = false;
    var loaderInstalled = true;
    var fabricApiReady = true;
    try {
      await _downloadService.install(
        minecraftDirectory: targetPath,
        versionId: version,
        source: _minecraftDownloadSource,
        downloadManager: _downloadManager,
        groupLabel:
            'Minecraft $version'
            '${selectedLoader == null ? '' : ' · ${selectedLoader.label} $loaderVersion'}',
        cancellation: cancellation,
        onProgress: (status) {
          final now = DateTime.now();
          if (!mounted ||
              now.difference(lastUpdate) < const Duration(milliseconds: 150) &&
                  !status.startsWith('完成')) {
            return;
          }
          lastUpdate = now;
          _setPageState(() {
            _minecraftInstallStatus = status;
            _activeDownloadTask = status;
          });
        },
      );
      cancellation.throwIfCancelled();
      if (selectedLoader != null) {
        final javaExecutable = await _resolveInstallerJava(
          minecraftDirectory: targetPath,
          versionId: version,
        );
        cancellation.throwIfCancelled();
        loaderInstalled = await _downloadService.installLoader(
          minecraftDirectory: targetPath,
          minecraftVersion: version,
          loader: selectedLoader.apiName,
          loaderVersion: loaderVersion!,
          javaExecutable: javaExecutable,
          source: _minecraftDownloadSource,
          downloadManager: _downloadManager,
          groupLabel: _l10n.homeInstallerLabel(
            selectedLoader.label,
            loaderVersion,
          ),
          cancellation: cancellation,
          onProgress: (status) {
            if (!mounted) return;
            _setPageState(() {
              _minecraftInstallStatus = status;
              _activeDownloadTask = status;
            });
          },
        );
      }
      cancellation.throwIfCancelled();
      await _catalog.loadVersions();
      final newVersions = _localVersions
          .where(
            (candidate) => !existingVersionDirectories.contains(
              _normalizedPathKey(candidate.directoryPath),
            ),
          )
          .toList();
      bool matchesLoader(MinecraftVersion candidate) {
        if (!_samePath(candidate.minecraftPath, targetPath)) return false;
        final type = candidate.loaderType?.toLowerCase();
        final loaderType = selectedLoader!.apiName.toLowerCase();
        return switch (loaderType) {
          'neoforge' => type == 'neoforge',
          'forge' => type == 'forge',
          'fabric' => type == 'fabric',
          'optifine' => type == 'optifine',
          _ => type?.contains(loaderType) ?? false,
        };
      }

      if (selectedLoader != null && loaderInstalled) {
        final matchingNew = newVersions.where(matchesLoader).toList();
        final matchingAll = _localVersions.where(matchesLoader).toList();
        installedPath = matchingNew.isNotEmpty
            ? matchingNew.last.directoryPath
            : matchingAll.isNotEmpty
            ? matchingAll.last.directoryPath
            : null;
      } else if (selectedLoader == null) {
        final baseDirectory =
            '$targetPath${Platform.pathSeparator}versions'
            '${Platform.pathSeparator}$version';
        installedPath =
            newVersions
                .where(
                  (candidate) =>
                      candidate.id == version ||
                      _samePath(candidate.directoryPath, baseDirectory),
                )
                .firstOrNull
                ?.directoryPath ??
            _localVersions
                .where(
                  (candidate) =>
                      _samePath(candidate.directoryPath, baseDirectory),
                )
                .firstOrNull
                ?.directoryPath;
      }
      if (installedPath != null) {
        if (requestedName.isNotEmpty) {
          installedPath = await _finalizeDownloadedClient(
            installedPath: installedPath,
            baseVersionId: version,
            requestedName: requestedName,
            keepSource: selectedLoader == null,
          );
          await _catalog.loadVersions();
        }
        await _catalog.selectLaunchVersion(installedPath);
        clientInstalled = true;
      }
      if (selectedLoader == MinecraftLoader.fabric &&
          loaderInstalled &&
          installedPath != null) {
        fabricApiReady = await _installFabricApiForClient(
          clientDirectory: installedPath,
          minecraftVersion: version,
          cancellation: cancellation,
        );
      }
      cancellation.throwIfCancelled();
      if (!mounted) return;
      final baseSummary =
          'Minecraft $version'
          '${selectedLoader == null ? '' : ' · ${selectedLoader.label} $loaderVersion'}';
      final completionMessage = loaderInstalled
          ? '${_l10n.homeInstallFinished(baseSummary)}'
                '${fabricApiReady ? '' : _l10n.homeFabricApiIncomplete}'
          : _l10n.homeOptifineClosedRescan;
      _setPageState(() {
        _isInstallingMinecraft = false;
        _minecraftInstallStatus = completionMessage;
        _activeDownloadTask = null;
      });
      _minecraftClientNameController.clear();
      _showVersionMessage(
        loaderInstalled
            ? _l10n.homeInstalledTo(
                'Minecraft $version'
                '${selectedLoader == null ? '' : ' · ${selectedLoader.label}'}',
                targetPath,
              )
            : _l10n.homeOptifineClosedConfirm,
      );
    } on DownloadCancelledException {
      if (!clientInstalled) {
        await _deleteNewVersionDirectories(
          targetPath,
          existingVersionDirectories,
        );
      }
      if (mounted) {
        _setPageState(() {
          _isInstallingMinecraft = false;
          _minecraftInstallStatus = clientInstalled
              ? _l10n.homeClientInstallDoneCancelRest
              : null;
          _minecraftInstallError = null;
          _activeDownloadTask = null;
        });
      }
      _showVersionMessage(
        clientInstalled
            ? _l10n.homeClientInstallDoneCancelRest
            : _l10n.homeDownloadCancelled,
      );
    } on HttpException catch (error) {
      await _cleanupFailedVersionInstall(
        targetPath,
        existingVersionDirectories,
      );
      _failMinecraftInstall(_l10n.homeDownloadServerError(error.message));
    } on SocketException catch (error) {
      await _cleanupFailedVersionInstall(
        targetPath,
        existingVersionDirectories,
      );
      _failMinecraftInstall(_l10n.homeDownloadConnectFailed(error.message));
    } on TimeoutException {
      await _cleanupFailedVersionInstall(
        targetPath,
        existingVersionDirectories,
      );
      _failMinecraftInstall(_l10n.homeInstallTimeout);
    } on FormatException catch (error) {
      await _cleanupFailedVersionInstall(
        targetPath,
        existingVersionDirectories,
      );
      _failMinecraftInstall(_l10n.homeMinecraftDataInvalid(error.message));
    } on FileSystemException catch (error) {
      await _cleanupFailedVersionInstall(
        targetPath,
        existingVersionDirectories,
      );
      _failMinecraftInstall(_l10n.homeWriteFilesFailed(error.message));
    } on IOException catch (error) {
      await _cleanupFailedVersionInstall(
        targetPath,
        existingVersionDirectories,
      );
      _failMinecraftInstall(_l10n.homeMinecraftDownloadFailed('$error'));
    } finally {
      if (mounted && identical(_activeDownloadToken, cancellation)) {
        _setPageState(() => _activeDownloadToken = null);
      }
      if (mounted && _isInstallingMinecraft) {
        _setPageState(() => _isInstallingMinecraft = false);
      }
    }
  }

  Future<String> _resolveInstallerJava({
    required String minecraftDirectory,
    required String versionId,
  }) async {
    if (_javaRuntimes.isEmpty) {
      await _java.discover();
    }
    int? requiredMajor;
    try {
      final configFile = File(
        '$minecraftDirectory${Platform.pathSeparator}versions'
        '${Platform.pathSeparator}$versionId'
        '${Platform.pathSeparator}$versionId.json',
      );
      if (await configFile.exists()) {
        final decoded = jsonDecode(await configFile.readAsString());
        if (decoded is Map<String, dynamic>) {
          final javaVersion = decoded['javaVersion'];
          if (javaVersion is Map<String, dynamic> &&
              javaVersion['majorVersion'] is int) {
            requiredMajor = javaVersion['majorVersion'] as int;
          }
        }
      }
    } on Exception {
      requiredMajor = null;
    }
    final sorted = [..._javaRuntimes]
      ..sort((left, right) => right.majorVersion.compareTo(left.majorVersion));
    final matching = sorted.where((runtime) {
      if (requiredMajor == null || runtime.majorVersion == 0) return true;
      return runtime.majorVersion == requiredMajor;
    }).toList();
    final candidates = matching.isNotEmpty ? matching : sorted;
    final javaService = _javaRuntimeService;
    for (final runtime in candidates) {
      final executable = await javaService.versionProbeExecutable(
        runtime.executable,
      );
      if (await File(executable).exists()) return executable;
    }
    for (final command in Platform.isWindows ? ['java', 'javaw'] : ['java']) {
      try {
        final result = await Process.run(
          Platform.isWindows ? 'where.exe' : 'which',
          [command],
          runInShell: false,
          stdoutEncoding: systemEncoding,
          stderrEncoding: systemEncoding,
        );
        if (result.exitCode != 0) continue;
        final executable = decodeProcessOutput(result.stdout)
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .firstOrNull;
        if (executable != null && await File(executable).exists()) {
          return await javaService.versionProbeExecutable(executable);
        }
      } on ProcessException {
        // Continue with the next candidate.
      } on FormatException {
        // Ignore output that cannot be decoded.
      }
    }
    throw const ProcessException('java', [], '未检测到可用于运行加载器安装器的 Java。');
  }
}
