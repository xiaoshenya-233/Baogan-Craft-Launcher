part of '../launcher_home_page.dart';

extension _VersionSettingsActions on _LauncherHomePageState {
  Future<void> _loadManagedMods(LauncherVersion version) async {
    if (mounted) {
      _setPageState(() => _isLoadingManagedMods = true);
    }
    try {
      final gameDirectory = version.gameDirectory ?? version.path;
      final modsDirectory = Directory(
        '$gameDirectory${Platform.pathSeparator}mods',
      );
      final mods = <ManagedMod>[];
      if (await modsDirectory.exists()) {
        await for (final entity in modsDirectory.list(followLinks: false)) {
          if (entity is! File) continue;
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final parsed = ResourceScanService.parseResourceFileName(fileName);
          if (!parsed.name.toLowerCase().endsWith('.jar')) continue;
          mods.add(
            ManagedMod(
              file: entity,
              name: parsed.name,
              enabled: !parsed.disabled,
            ),
          );
        }
      }
      mods.sort((left, right) => left.name.compareTo(right.name));
      if (!mounted) return;
      _setPageState(() => _managedMods = mods);
    } on FileSystemException catch (error) {
      _showVersionMessage('读取模组列表失败：${error.message}');
    } finally {
      if (mounted) _setPageState(() => _isLoadingManagedMods = false);
    }
  }

  Future<void> _toggleManagedMod(ManagedMod mod) async {
    try {
      final path = mod.file.path;
      final nextPath = mod.enabled
          ? ResourceScanService.disabledPathOf(path)
          : ResourceScanService.enabledPathOf(path);
      await mod.file.rename(nextPath);
      final version = _selectedVersion;
      if (version != null) await _loadManagedMods(version);
    } on FileSystemException catch (error) {
      _showVersionMessage('切换模组状态失败：${error.message}');
    }
  }

  Future<void> _deleteManagedMod(ManagedMod mod) async {
    try {
      await mod.file.delete();
      final version = _selectedVersion;
      if (version != null) await _loadManagedMods(version);
    } on FileSystemException catch (error) {
      _showVersionMessage('删除模组失败：${error.message}');
    }
  }

  Future<void> _deleteVersion(LauncherVersion version) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除客户端'),
        content: Text('确定删除“${version.name}”及其全部文件吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final versionsRoot = joinPath(version.minecraftPath, 'versions');
    if (!isPathInside(version.path, versionsRoot)) {
      _showVersionMessage('已拒绝删除：客户端目录不在 versions 文件夹内。');
      return;
    }
    _setPageState(() => _isDeletingVersion = true);
    try {
      final directory = Directory(version.path);
      if (await directory.exists()) await directory.delete(recursive: true);
      await _catalog.loadVersions();
      if (!mounted) return;
      // Leave the detail view: the client no longer exists, so keeping the
      // page open would render a deleted version.
      _setPageState(() {
        _selectedVersion = null;
        _managedMods = [];
        _isLoadingManagedMods = false;
      });
      _shell.closeVersionDetails();
      _showVersionMessage('已删除 ${version.name}。');
    } on FileSystemException catch (error) {
      _showVersionMessage('删除失败：${error.message}');
    } finally {
      if (mounted) _setPageState(() => _isDeletingVersion = false);
    }
  }

  Future<void> _showGameLogs(LauncherVersion version) async {
    final directory = version.gameDirectory ?? version.path;
    final result = await readMinecraftLatestLog(directory);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('游戏日志'),
        content: SizedBox(
          width: 720,
          height: 460,
          child: result.path == null
              ? const Text('尚未找到游戏日志。')
              : SingleChildScrollView(
                  child: SelectableText(
                    result.content.isEmpty ? '日志内容为空。' : result.content,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseWallpaper({required bool dark}) async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
      dialogTitle: '选择壁纸',
    );
    final path = files.isEmpty ? null : files.first.path;
    if (path == null) return;
    final crop = await _pickWallpaperCrop(
      path: path,
      initialCrop: const Rect.fromLTWH(0, 0, 1, 1),
    );
    if (crop == null) return;
    await _appearance.setWallpaper(dark: dark, path: path, crop: crop);
  }

  Future<void> _recropWallpaper({required bool dark}) async {
    final path = dark ? _darkWallpaperPath : _lightWallpaperPath;
    if (path == null) {
      await _chooseWallpaper(dark: dark);
      return;
    }
    final crop = await _pickWallpaperCrop(
      path: path,
      initialCrop: _appearance.wallpaperCrop(dark),
    );
    if (crop == null) return;
    _appearance.setWallpaperCrop(dark: dark, crop: crop);
  }

  /// Opens the crop dialog and returns the selected area in 0..1 coordinates.
  Future<Rect?> _pickWallpaperCrop({
    required String path,
    required Rect initialCrop,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      _showVersionMessage('壁纸文件不存在：$path');
      return null;
    }
    if (!mounted) return null;
    final size = MediaQuery.sizeOf(context);
    final aspectRatio = size.height <= 0
        ? 16 / 9
        : (size.width / size.height).clamp(0.4, 4.0).toDouble();
    return showDialog<Rect>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WallpaperCropDialog(
        file: file,
        aspectRatio: aspectRatio,
        initialCrop: initialCrop,
      ),
    );
  }

  Future<void> _runWindowCommand(String command) async {
    switch (command) {
      case 'minimize':
        await windowManager.minimize();
      case 'toggleMaximize':
        final maximized = await windowManager.isMaximized();
        if (maximized) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
        _shell.setWindowMaximized(!maximized);
      case 'close':
        await windowManager.close();
      case 'startDrag':
        await windowManager.startDragging();
    }
  }

  Future<void> _openClientFolder(String path) async {
    if (path.trim().isEmpty) return;
    final executable = Platform.isWindows
        ? 'explorer'
        : Platform.isMacOS
        ? 'open'
        : 'xdg-open';
    try {
      await Process.start(executable, [path], runInShell: false);
    } on ProcessException catch (error) {
      if (mounted) _showVersionMessage('无法打开客户端文件夹：${error.message}');
    }
  }
}

extension _ClientSourceActions on _LauncherHomePageState {
  Future<void> _addExistingFolder() async {
    String? path;
    try {
      path = await FilePicker.getDirectoryPath(
        dialogTitle: '选择 .minecraft 文件夹',
        initialDirectory: _minecraftPath.isEmpty ? null : _minecraftPath,
      );
    } on FormatException catch (error) {
      path = await _promptDirectoryPath(
        title: '选择 .minecraft 文件夹',
        initialPath: _minecraftPath,
        pickerError: error.message,
      );
    } on PlatformException catch (error) {
      path = await _promptDirectoryPath(
        title: '选择 .minecraft 文件夹',
        initialPath: _minecraftPath,
        pickerError: error.message ?? error.code,
      );
    }
    if (!mounted || path == null || path.trim().isEmpty) return;
    final selectedPath = path.trim();
    try {
      final versionsDirectory = Directory(
        '$selectedPath${Platform.pathSeparator}versions',
      );
      if (!await versionsDirectory.exists()) {
        _showVersionMessage('所选目录中没有 versions 文件夹，请选择 .minecraft 文件夹本身。');
        return;
      }
      _environment.selectSource(selectedPath);
      _setPageState(() => _selectedVersion = null);
      _catalog.clearVersions();
      _shell.closeVersionDetails();
      await _saveMinecraftSources();
      await _catalog.loadVersions();
      if (mounted) {
        _showVersionMessage('已扫描 .minecraft 文件夹，共发现 ${_versions.length} 个客户端。');
      }
    } on FileSystemException catch (error) {
      _showVersionMessage('无法读取 .minecraft 文件夹：${error.message}');
    }
  }

  Future<void> _showClientSourcePicker() async {
    final sources = _effectiveMinecraftSources();
    if (sources.isEmpty) {
      await _addExistingFolder();
      return;
    }
    if (sources.length == 1) {
      await _changeMinecraftSource(sources.first);
      return;
    }
    final current = _minecraftPath.isNotEmpty ? _minecraftPath : sources.first;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
        ),
        decoration: BoxDecoration(
          color: _panelColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border.all(color: _panelBorderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: _panelBorderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_copy_outlined,
                    size: 18,
                    color: _LauncherHomePageState._green,
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    '客户端来源',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '${sources.length} 个来源',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < sources.length; index++) ...[
                      if (index > 0) const SizedBox(height: 8),
                      _buildSourcePickerRow(
                        sources[index],
                        current,
                        sheetContext,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, 'action:add'),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('添加来源'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pop(sheetContext, 'action:change'),
                    icon: const Icon(Icons.drive_file_move_outline, size: 16),
                    label: const Text('更换当前文件夹'),
                  ),
                  if (sources.length > 1)
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pop(sheetContext, 'action:remove'),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text(
                        '移除当前来源',
                        style: TextStyle(color: Color(0xFFE58A7A)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    switch (selected) {
      case 'action:add':
        await _addExistingFolder();
        return;
      case 'action:change':
        await _changeMinecraftSource(current);
        return;
      case 'action:remove':
        await _removeMinecraftSource(current);
        return;
    }
    final match = sources
        .where((source) => _samePath(source, selected))
        .firstOrNull;
    if (match == null) return;
    LauncherLog.info('Sources', '切换 Minecraft 来源：$match');
    _environment.selectSource(match);
    _setPageState(() => _selectedVersion = null);
    _catalog.clearVersions();
    _shell.closeVersionDetails();
    await _saveMinecraftSources();
    await _catalog.loadVersions();
    if (!mounted) return;
    _showVersionMessage('当前客户端来源已切换为 $match。');
  }

  Widget _buildSourcePickerRow(
    String source,
    String current,
    BuildContext sheetContext,
  ) {
    final selected = _samePath(source, current);
    final count = selected ? _localVersions.length : null;
    return Material(
      color: selected ? _selectedSurfaceColor : _panelAccentColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.pop(sheetContext, source),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? _LauncherHomePageState._green
                  : _panelBorderColor,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_open_outlined,
                size: 18,
                color: selected ? _LauncherHomePageState._green : _muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selected ? '$count 个客户端 · 当前来源' : '点击切换到此来源',
                      style: TextStyle(fontSize: 10, color: _muted),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: _LauncherHomePageState._green,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeMinecraftSource(String source) async {
    String? path;
    try {
      path = await FilePicker.getDirectoryPath(
        dialogTitle: '选择新的 .minecraft 文件夹',
        initialDirectory: source,
      );
    } on FormatException catch (error) {
      path = await _promptDirectoryPath(
        title: '选择新的 .minecraft 文件夹',
        initialPath: source,
        pickerError: error.message,
      );
    } on PlatformException catch (error) {
      path = await _promptDirectoryPath(
        title: '选择新的 .minecraft 文件夹',
        initialPath: source,
        pickerError: error.message ?? error.code,
      );
    }
    if (!mounted || path == null || path.trim().isEmpty) return;
    final selectedPath = path.trim();
    final versionsDirectory = Directory(
      '$selectedPath${Platform.pathSeparator}versions',
    );
    if (!await versionsDirectory.exists()) {
      _showVersionMessage('所选目录中没有 versions 文件夹，请选择 .minecraft 文件夹本身。');
      return;
    }
    _environment.replaceSource(source, selectedPath);
    _setPageState(() => _selectedVersion = null);
    _catalog.clearVersions();
    _shell.closeVersionDetails();
    await _saveMinecraftSources();
    await _catalog.loadVersions();
    _showVersionMessage('客户端来源已更换为 $selectedPath。');
  }

  Future<void> _removeMinecraftSource(String source) async {
    if (_environment.minecraftSources.length <= 1) {
      _showVersionMessage('至少需要保留一个客户端来源。');
      return;
    }
    if (!_environment.removeSource(source)) return;
    _setPageState(() => _selectedVersion = null);
    _catalog.clearVersions();
    _shell.closeVersionDetails();
    await _saveMinecraftSources();
    await _catalog.loadVersions();
    _showVersionMessage('已移除客户端来源：$source');
  }

  Future<String?> _promptDirectoryPath({
    required String title,
    required String initialPath,
    required String pickerError,
  }) async {
    final controller = TextEditingController(text: initialPath);
    final path = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件夹选择器无法打开（$pickerError）。请直接输入目标文件夹的完整路径。'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: '文件夹路径'),
              onSubmitted: (value) =>
                  Navigator.pop(dialogContext, value.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('选择'),
          ),
        ],
      ),
    );
    controller.dispose();
    return path;
  }
}

extension _VersionPageBuilders on _LauncherHomePageState {
  Widget _buildVersionsTab() {
    if (_shell.showVersionDetails && _selectedVersion != null) {
      return VersionDetailsPage(
        version: _selectedVersion!,
      catalog: _catalog,
      environment: _environment,
      java: _java,
      palette: _palette,
      isDark: _usesDarkPalette,
      isDownloadLocked: isDownloadLocked,
      versionFilter: _versionFilter,
      versionSearchQuery: _versionSearchQuery,
      isLoadingManagedMods: _isLoadingManagedMods,
      managedMods: _managedMods,
      maintenanceStatus: _versionMaintenanceStatus,
      maintenanceRunning: _isVersionMaintenanceRunning,
      isDeletingVersion: _isDeletingVersion,
      isInstallingMinecraft: _isInstallingMinecraft,
      isDownloadingResources: _isDownloadingResources,
      memoryGb: _bgucMemoryGb,
      maxMemoryGb: _maxMemoryGb,
      memoryError: _memoryDetectionError,
      setPageState: _setPageState,
      onVersionFilterChanged: (value) {
        _setPageState(() => _versionFilter = value);
      },
      onSearchChanged: (value) {
        _setPageState(() => _versionSearchQuery = value);
      },
      onImportModpack: _importModpack,
      onAddFolder: _addExistingFolder,
      onShowSourcePicker: _showClientSourcePicker,
      onDownloadMinecraft: _openMinecraftDownload,
      onReload: _catalog.loadVersions,
      onOpenDetails: (version) {
        _setPageState(() => _selectedVersion = version);
        _selectedVersionSettings = const ClientLaunchSettings();
        unawaited(_loadSelectedVersionSettings(version));

        _shell.openVersionDetails();
        unawaited(_loadManagedMods(version));
      },
      onDeleteVersion: (version) => unawaited(_deleteVersion(version)),
      onRepairVersion: (version) => unawaited(_repairVersionFiles(version)),
      onReinstallVersion: (version) => unawaited(_reinstallVersion(version)),
      onShowLogs: (version) => unawaited(_showGameLogs(version)),
      onOpenFolder: (version) =>
          unawaited(_openClientFolder(version.gameDirectory ?? version.path)),
      onLoadManagedMods: (version) => unawaited(_loadManagedMods(version)),
      onToggleManagedMod: (mod) => unawaited(_toggleManagedMod(mod)),
      onDeleteManagedMod: (mod) => unawaited(_deleteManagedMod(mod)),
      onCloseDetails: _shell.closeVersionDetails,
      clientSettings: _selectedVersionSettings,
      onClientJavaChanged: (value) => unawaited(_saveClientJava(value)),
      onClientMemoryChanged: (value) => unawaited(_saveClientMemory(value)),
      onMessage: _showVersionMessage,
      onCancelMaintenance: () => _versionMaintenanceCancellation?.cancel(),
      onOpenResourceSearch: () {
        _shell.showDownloads();
        _resourceDownloads.category = DownloadCategory.mods;
        unawaited(_loadResourceResults());
      },
      onFastJoinServer: _fastJoinServer,
      minecraftInstallStatus: _minecraftInstallStatus,
      minecraftInstallError: _minecraftInstallError,
      maintenanceCancellable: _versionMaintenanceCancellation != null,
      );
    }
    return VersionManagementPage(
      catalog: _catalog,
      environment: _environment,
      java: _java,
      palette: _palette,
      isDark: _usesDarkPalette,
      isDownloadLocked: isDownloadLocked,
      versionFilter: _versionFilter,
      versionSearchQuery: _versionSearchQuery,
      isLoadingManagedMods: _isLoadingManagedMods,
      managedMods: _managedMods,
      maintenanceStatus: _versionMaintenanceStatus,
      maintenanceRunning: _isVersionMaintenanceRunning,
      isDeletingVersion: _isDeletingVersion,
      isInstallingMinecraft: _isInstallingMinecraft,
      isDownloadingResources: _isDownloadingResources,
      memoryGb: _bgucMemoryGb,
      maxMemoryGb: _maxMemoryGb,
      memoryError: _memoryDetectionError,
      setPageState: _setPageState,
      onVersionFilterChanged: (value) {
        _setPageState(() => _versionFilter = value);
      },
      onSearchChanged: (value) {
        _setPageState(() => _versionSearchQuery = value);
      },
      onImportModpack: _importModpack,
      onAddFolder: _addExistingFolder,
      onShowSourcePicker: _showClientSourcePicker,
      onDownloadMinecraft: _openMinecraftDownload,
      onReload: _catalog.loadVersions,
      onOpenDetails: (version) {
        _setPageState(() => _selectedVersion = version);
        _selectedVersionSettings = const ClientLaunchSettings();
        unawaited(_loadSelectedVersionSettings(version));

        _shell.openVersionDetails();
        unawaited(_loadManagedMods(version));
      },
      onDeleteVersion: (version) => unawaited(_deleteVersion(version)),
      onRepairVersion: (version) => unawaited(_repairVersionFiles(version)),
      onReinstallVersion: (version) => unawaited(_reinstallVersion(version)),
      onShowLogs: (version) => unawaited(_showGameLogs(version)),
      onOpenFolder: (version) =>
          unawaited(_openClientFolder(version.gameDirectory ?? version.path)),
      onLoadManagedMods: (version) => unawaited(_loadManagedMods(version)),
      onToggleManagedMod: (mod) => unawaited(_toggleManagedMod(mod)),
      onDeleteManagedMod: (mod) => unawaited(_deleteManagedMod(mod)),
      onCloseDetails: _shell.closeVersionDetails,
      onMemoryChanged: (value) {
        _setPageState(() => _bgucMemoryGb = value);
      },
      onMessage: _showVersionMessage,
      onPickJava: () => unawaited(_pickJavaExecutable()),
      onSaveJava: () => unawaited(_saveCustomJavaPath()),
      onCancelMaintenance: () => _versionMaintenanceCancellation?.cancel(),
      onOpenResourceSearch: () {
        _shell.showDownloads();
        _resourceDownloads.category = DownloadCategory.mods;
        unawaited(_loadResourceResults());
      },
      javaPathController: _javaPathController,
      minecraftInstallStatus: _minecraftInstallStatus,
      minecraftInstallError: _minecraftInstallError,
      maintenanceCancellable: _versionMaintenanceCancellation != null,
    );
  }
}
