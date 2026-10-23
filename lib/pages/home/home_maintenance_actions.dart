part of '../launcher_home_page.dart';

/// Repair and reinstall actions with a modal progress dialog.
extension _VersionMaintenanceActions on _LauncherHomePageState {
  Future<void> _repairVersionFiles(LauncherVersion version) async {
    if (_isVersionMaintenanceRunning) {
      _showVersionMessage('已有修复或重装任务正在进行，请稍候。');
      return;
    }
    if (version.minecraftPath.trim().isEmpty) {
      _showVersionMessage('未找到 ${version.name} 所属的 .minecraft 目录。');
      return;
    }
    final cancellation = DownloadCancellationToken();
    _setPageState(() {
      _isVersionMaintenanceRunning = true;
      _versionMaintenanceStatus = '正在检查 ${version.name} 的文件完整性…';
      _versionMaintenanceCancellation = cancellation;
    });
    try {
      await _showVersionProgressDialog(
        title: '修复 ${version.name}',
        cancellation: cancellation,
        task: (report) => _downloadService.repairVersion(
          minecraftDirectory: version.minecraftPath,
          versionId: version.name,
          source: _minecraftDownloadSource,
          downloadManager: _downloadManager,
          groupLabel: '修复 · ${version.name}',
          cancellation: cancellation,
          onProgress: (status) {
            report(status);
            if (mounted) {
              _setPageState(() => _versionMaintenanceStatus = status);
            }
          },
        ),
      );
      cancellation.throwIfCancelled();
      await _catalog.loadVersions();
      _refreshSelectedVersion();
      _showVersionMessage('${version.name} 修复完成。');
    } on DownloadCancelledException {
      _showVersionMessage('已取消修复 ${version.name}。');
    } on Object catch (error) {
      _showVersionMessage('修复失败：$error');
    } finally {
      if (mounted) {
        _setPageState(() {
          _isVersionMaintenanceRunning = false;
          _versionMaintenanceStatus = null;
          _versionMaintenanceCancellation = null;
        });
      }
    }
  }

  Future<void> _reinstallVersion(LauncherVersion version) async {
    if (_isVersionMaintenanceRunning) {
      _showVersionMessage('已有修复或重装任务正在进行，请稍候。');
      return;
    }
    if (version.minecraftPath.trim().isEmpty) {
      _showVersionMessage('未找到 ${version.name} 所属的 .minecraft 目录。');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重新安装客户端'),
        content: Text(
          '将重新下载「${version.name}」的全部核心文件。\n'
          'mods、存档、配置、资源包与光影会被保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('重新安装'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final configFile = File(joinPath(version.path, '${version.name}.json'));
    if (!await configFile.exists()) {
      _showVersionMessage('找不到 ${version.name} 的版本配置，无法重新安装。');
      return;
    }
    final configBytes = await configFile.readAsBytes();
    if (!mounted) return;

    final cancellation = DownloadCancellationToken();
    _setPageState(() {
      _isVersionMaintenanceRunning = true;
      _versionMaintenanceStatus = '准备重新安装 ${version.name}…';
      _versionMaintenanceCancellation = cancellation;
    });
    try {
      await _showVersionProgressDialog(
        title: '重新安装 ${version.name}',
        cancellation: cancellation,
        task: (report) async {
          final reinstaller = VersionReinstaller(
            minecraftDirectory: version.minecraftPath,
            versionName: version.name,
            onProgress: (message) {
              report(message);
              if (mounted) {
                _setPageState(() => _versionMaintenanceStatus = message);
              }
            },
            reinstallVersion: (versionName) async {
              // The reinstaller removed the folder; restore the original
              // version JSON so the repair pipeline can rebuild every library,
              // asset and the client jar for this exact profile.
              final directory = Directory(
                joinPath(version.minecraftPath, 'versions/$versionName'),
              );
              await directory.create(recursive: true);
              await File(
                joinPath(directory.path, '$versionName.json'),
              ).writeAsBytes(configBytes, flush: true);
              await _downloadService.repairVersion(
                minecraftDirectory: version.minecraftPath,
                versionId: versionName,
                source: _minecraftDownloadSource,
                downloadManager: _downloadManager,
                groupLabel: '重装 · $versionName',
                cancellation: cancellation,
                onProgress: (status) {
                  report(status);
                  if (mounted) {
                    _setPageState(() => _versionMaintenanceStatus = status);
                  }
                },
              );
            },
          );
          await reinstaller.reinstall();
        },
      );
      cancellation.throwIfCancelled();
      await _catalog.loadVersions();
      _refreshSelectedVersion();
      _showVersionMessage('${version.name} 已重新安装。');
    } on DownloadCancelledException {
      _showVersionMessage('已取消重新安装 ${version.name}。');
    } on VersionReinstallException catch (error) {
      _showVersionMessage('重新安装失败：${error.message}');
    } on Object catch (error) {
      _showVersionMessage('重新安装失败：$error');
    } finally {
      if (mounted) {
        _setPageState(() {
          _isVersionMaintenanceRunning = false;
          _versionMaintenanceStatus = null;
          _versionMaintenanceCancellation = null;
        });
      }
    }
  }

  /// Re-resolves the open detail page against the refreshed catalog.
  ///
  /// Repair and reinstall replace the on-disk files, so the previously selected
  /// [LauncherVersion] instance becomes stale. If the client disappeared
  /// entirely, the detail view is closed instead of rendering old data.
  void _refreshSelectedVersion() {
    final selected = _selectedVersion;
    if (selected == null || !mounted) return;
    final updated = _versions
        .where((candidate) => _samePath(candidate.path, selected.path))
        .firstOrNull;
    if (updated == null) {
      _setPageState(() {
        _selectedVersion = null;
        _managedMods = [];
        _isLoadingManagedMods = false;
      });
      _shell.closeVersionDetails();
      return;
    }
    _setPageState(() => _selectedVersion = updated);
  }

  /// Runs [task] behind a modal progress dialog.
  ///
  /// Closing the dialog cancels [cancellation], so the download queue and the
  /// installer stop at their next checkpoint instead of finishing silently.
  Future<void> _showVersionProgressDialog({
    required String title,
    required DownloadCancellationToken cancellation,
    required Future<void> Function(void Function(String status) report) task,
  }) async {
    final status = ValueNotifier<String>('准备中…');
    BuildContext? dialogContext;
    var dialogOpen = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          return AlertDialog(
            title: Text(title),
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: status,
                    builder: (context, value, _) =>
                        Text(value, style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  cancellation.cancel();
                  Navigator.of(ctx).pop();
                },
                child: const Text('取消'),
              ),
            ],
          );
        },
      ).whenComplete(() => dialogOpen = false),
    );
    try {
      await task((message) => status.value = message);
    } finally {
      final ctx = dialogContext;
      if (dialogOpen && ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop();
      }
    }
  }
}
