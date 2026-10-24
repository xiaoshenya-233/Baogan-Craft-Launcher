import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../../../services/download/download_service.dart';
import '../../../services/installer/version_models.dart';
import '../../../services/network/api_service.dart';
import '../../launcher/controllers/download_activity_controller.dart';
import '../../launcher/launcher_palette.dart';
import '../resource_downloads_page.dart';
import '../widgets/target_client_picker.dart';
import 'minecraft_download_controller.dart';
import 'minecraft_download_types.dart';
import 'resource_download_controller.dart';

/// Resource download actions: dialogs, candidate resolution and installs.
class ResourceDownloadActions {
  ResourceDownloadActions({
    required this.resource,
    required this.minecraft,
    required this.activity,
    required this.manager,
    required this.context,
    required this.minecraftPath,
    required this.localClients,
    required this.selectedVersion,
    this.selectedLaunchVersionPath,
    required this.minecraftClientNameController,
    required this.onLoadManagedMods,
    required this.onChooseDownloadClient,
    required this.onShowDownloadLockedDialog,
    required this.onCloseMinecraftDownload,
    required this.resourceSearchQuery,
    required this.resourceSearchController,
    required this.palette,
    required this.isDark,
    required this.isDownloadLocked,
    required this.setPageState,
    required this.showMessage,
    required this.onScheduleResourceSearch,
    required this.onLoadResourceResults,
    required this.onToggleResourceCandidate,
    required this.onOpenResourceProject,
    required this.onBackResourceList,
    required this.onShowResourceCandidates,
    required this.onChangeResourcePage,
    required this.onInstallModrinthProject,
    required this.onDownloadResourceCandidates,
    required this.onConfirmRemoveCandidate,
    required this.onDownloadModrinthProject,
    required this.onHydrateResourceProject,
    required this.onPickResourceVersionAndLoader,
    required this.onChooseWorldFolderForDataPack,
    required this.onToggleVersionCandidate,
    required this.onSelectDefaultResourceVersion,
    required this.onLoadMinecraftCatalog,
    required this.onLoadLoaderVersions,
    required this.onSelectMinecraftVersion,
    required this.onInstallSelectedMinecraft,
    required this.onCancelActiveDownload,
    required this.onOpenDownloadTasks,
    required this.onOpenMinecraftDownload,
    required this.onShowDownloads,
  });

  final ResourceDownloadController resource;
  final MinecraftDownloadController minecraft;
  final DownloadActivityController activity;
  final DownloadManager manager;
  final BuildContext context;
  final String minecraftPath;

  /// All installed clients; read lazily so the list stays current.
  final List<MinecraftVersion> Function() localClients;
  final LauncherVersion? selectedVersion;

  /// Directory path of the client currently selected for launching.
  ///
  /// This is the authoritative "current client" for resource installs; it comes
  /// from `VersionCatalogController.selectedLaunchVersionId`.
  final String? selectedLaunchVersionPath;
  final TextEditingController minecraftClientNameController;
  final Future<void> Function(LauncherVersion) onLoadManagedMods;
  final Future<MinecraftVersion?> Function({List<MinecraftVersion>? candidates})
  onChooseDownloadClient;
  final Future<void> Function(BuildContext) onShowDownloadLockedDialog;
  final VoidCallback onCloseMinecraftDownload;
  DownloadCancellationToken? _activeDownloadToken;
  final Map<String, Future<ModrinthProject>> _resourceHydrations =
      <String, Future<ModrinthProject>>{};
  final Set<String> _resourceCandidatePickers = <String>{};
  bool _pickingDownloadTarget = false;
  final String resourceSearchQuery;
  final TextEditingController resourceSearchController;
  final LauncherPalette palette;
  final bool isDark;
  final bool isDownloadLocked;
  final void Function(VoidCallback) setPageState;
  final ValueChanged<String> showMessage;
  final VoidCallback onScheduleResourceSearch;
  final Future<void> Function() onLoadResourceResults;
  final Future<void> Function(ModrinthProject) onToggleResourceCandidate;
  final Future<void> Function(ModrinthProject) onOpenResourceProject;
  final VoidCallback onBackResourceList;
  final VoidCallback onShowResourceCandidates;
  final void Function(int) onChangeResourcePage;
  final Future<void> Function(ModrinthProject) onInstallModrinthProject;
  final Future<void> Function() onDownloadResourceCandidates;
  final Future<bool> Function(String) onConfirmRemoveCandidate;
  final Future<void> Function(ModrinthProject) onDownloadModrinthProject;
  final Future<ModrinthProject> Function(ModrinthProject)
  onHydrateResourceProject;
  final Future<ResourceVersionChoice?> Function(ModrinthProject)
  onPickResourceVersionAndLoader;
  final Future<String?> Function() onChooseWorldFolderForDataPack;
  final void Function(ModrinthProject, ModrinthVersion)
  onToggleVersionCandidate;
  final void Function(ModrinthProject) onSelectDefaultResourceVersion;
  final Future<void> Function() onLoadMinecraftCatalog;
  final Future<void> Function(MinecraftLoader) onLoadLoaderVersions;
  final void Function(String) onSelectMinecraftVersion;
  final Future<void> Function() onInstallSelectedMinecraft;
  final VoidCallback onCancelActiveDownload;
  final VoidCallback onOpenDownloadTasks;
  final VoidCallback onOpenMinecraftDownload;
  final VoidCallback onShowDownloads;

  CandidateManager get _candidateManager => resource.candidateManager;
  Set<String> get _candidatesToRemove => resource.candidatesToRemove;
  set _resourceDetailProject(ModrinthProject? value) =>
      resource.detailProject = value;
  set _isLoadingResourceDetail(bool value) => resource.isLoadingDetail = value;
  set _resourceDetailError(String? value) => resource.detailError = value;
  set _resourceSelectedLoader(String? value) => resource.selectedLoader = value;
  set _resourceSelectedGameFamily(String? value) =>
      resource.selectedGameFamily = value;
  set _resourceExpandedGameVersion(String? value) =>
      resource.expandedGameVersion = value;
  bool get _isDownloadingResources => resource.isDownloading;
  set _isDownloadingResources(bool value) => resource.isDownloading = value;
  bool get _isInstallingMinecraft => minecraft.isInstalling;
  set _activeDownloadTask(String? value) => activity.updateTask(value);
  DownloadManager get _downloadManager => manager;

  LauncherVersion? get _selectedVersion => selectedVersion;
  Color get _muted => palette.muted;
  Color get _panelColor => palette.panelColor;
  Color get _panelBorderColor => palette.panelBorderColor;
  Color get _panelAccentColor => palette.panelAccentColor;

  void _setPageState(VoidCallback callback) => setPageState(callback);
  void _showVersionMessage(String message) => showMessage(message);

  /// Installed clients converted to the picker's [LauncherVersion] model.
  List<LauncherVersion> _clientsForPicker() => [
    for (final version in localClients())
      LauncherVersion(
        name: version.id,
        path: version.directoryPath,
        kind: version.loaderType == null
            ? VersionKind.vanilla
            : VersionKind.modded,
        minecraftPath: version.minecraftPath,
        minecraftVersion: version.minecraftVersion,
        versionType: version.type,
        loaderType: version.loaderType,
        loaderVersion: version.loaderVersion,
      ),
  ];

  /// Asks the player where the resource should be installed.
  ///
  /// `customRoot` is non-null when a directory was chosen by hand; a `null`
  /// result means the picker was dismissed and the download must be cancelled.
  Future<({MinecraftVersion client, String? customRoot})?> _pickDownloadTarget({
    required String modTitle,
    required List<String> gameVersions,
    required List<String> loaders,
  }) async {
    if (_pickingDownloadTarget) return null;
    _pickingDownloadTarget = true;
    try {
      final selection = await TargetClientPicker.show(
        context,
        clients: _clientsForPicker(),
        gameVersions: gameVersions,
        loaders: loaders,
        modTitle: modTitle,
        preferredClientPath:
            selectedLaunchVersionPath ?? _selectedVersion?.path,
      );
      if (selection == null) return null;
      final customPath = selection.customPath;
      if (customPath != null) {
        return (
          client: MinecraftVersion(
            id: lastPathSegment(customPath),
            type: null,
            directoryPath: customPath,
            minecraftPath: customPath,
            minecraftVersion: gameVersions.firstOrNull,
            loaderType: loaders.firstOrNull,
          ),
          customRoot: customPath,
        );
      }
      final client = selection.client!;
      return (
        client: MinecraftVersion(
          id: client.name,
          type: client.versionType,
          directoryPath: client.gameDirectory ?? client.path,
          minecraftPath: client.minecraftPath,
          minecraftVersion: client.minecraftVersion,
          loaderType: client.loaderType,
          loaderVersion: client.loaderVersion,
        ),
        customRoot: null,
      );
    } finally {
      _pickingDownloadTarget = false;
    }
  }

  Future<void> _loadManagedMods(LauncherVersion version) =>
      onLoadManagedMods(version);

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
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return path;
  }

  Future<void> _toggleResourceCandidate(ModrinthProject project) async {
    if (_candidateManager.contains(project.id)) {
      _setPageState(() => _candidateManager.remove(project.id));
      return;
    }
    if (!_resourceCandidatePickers.add(project.id)) return;

    try {
      final choice = await _pickResourceVersionAndLoader(
        project,
        allowDefer: true,
      );
      if (choice == null) return;

      _setPageState(() {
        _candidateManager.add(
          choice.defer
              ? CandidateMod.deferred(choice.project)
              : CandidateMod.fromChoice(choice),
        );
      });
      _showVersionMessage(choice.defer ? '已加入清单，下载时需选择版本。' : '已加入候选清单。');
    } finally {
      _resourceCandidatePickers.remove(project.id);
    }
  }

  /// Shared version/loader picker used by candidate actions and completion.
  ///
  /// The sheet is shown immediately; API hydration happens inside it so the
  /// candidate button never waits for the network before giving feedback.
  Future<ResourceVersionChoice?> _pickResourceVersionAndLoader(
    ModrinthProject project, {
    String? initialLoader,
    bool allowDefer = false,
  }) {
    Future<ModrinthProject> loadProject() async {
      final versions = await _loadResourceVersionIndex(project);
      if (versions.isEmpty) {
        throw StateError('${project.source.label} 没有返回任何版本。');
      }
      return project.withVersions(versions);
    }

    return showModalBottomSheet<ResourceVersionChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ResourceVersionPickerSheet(
        project: project,
        initialLoader: initialLoader,
        allowDefer: allowDefer,
        panelColor: _panelColor,
        accentColor: _panelAccentColor,
        borderColor: _panelBorderColor,
        mutedColor: _muted,
        loadProject: loadProject,
        loadersFor: resource.projectLoaderKeys,
        gameVersionsFor: (loaded) {
          final loaders = resource.projectLoaderKeys(loaded);
          final versions = <String>{
            ...loaded.supportedGameVersions,
            ...resource.projectGameVersions(loaded, projectLoaders: loaders),
          };
          return versions.toList()
            ..sort((left, right) => compareGameVersions(right, left));
        },
      ),
    );
  }

  Future<void> _openResourceProject(ModrinthProject source) async {
    _setPageState(() {
      _resourceDetailProject = source;
      _resourceDetailError = null;
      _isLoadingResourceDetail = true;
      resource.detailVersionOffset = 0;
      resource.detailHasMoreVersions = false;
      resource.isLoadingMoreDetailVersions = false;
      resource.detailPageError = null;
      resource.selectDefaultResourceVersion(source);
    });
    try {
      final versions = await _loadResourceVersionIndex(source);
      debugPrint(
        '[VersionPicker] 当前版本: ${source.title}, '
        '总版本数据源长度: ${versions.length}, 过滤后数量: ${versions.length}',
      );
      if (versions.isEmpty) {
        throw StateError('${source.source.label} 没有返回任何版本。');
      }
      final loaded = source.withVersions(versions);
      _setPageState(() {
        _resourceDetailProject = loaded;
        _isLoadingResourceDetail = false;
        resource.detailVersionOffset = versions.length;
        resource.detailHasMoreVersions = false;
        resource.detailPageError = null;
        resource.selectDefaultResourceVersion(loaded);
      });
    } catch (error) {
      _setPageState(() {
        _isLoadingResourceDetail = false;
        _resourceDetailError = '无法读取项目版本：$error';
        resource.detailPageError = null;
        resource.detailHasMoreVersions = false;
      });
    }
  }

  void _backToResourceList() {
    _setPageState(() {
      _resourceDetailProject = null;
      _resourceDetailError = null;
      resource.detailVersionOffset = 0;
      resource.detailHasMoreVersions = false;
      resource.isLoadingMoreDetailVersions = false;
      resource.detailPageError = null;
      _resourceSelectedLoader = null;
      _resourceSelectedGameFamily = null;
      _resourceExpandedGameVersion = null;
    });
  }

  Future<ModrinthProject> _hydrateResourceProject(
    ModrinthProject project, {
    bool force = false,
  }) {
    if (!force && project.versions.isNotEmpty) {
      return Future<ModrinthProject>.value(project);
    }
    final inFlight = _resourceHydrations[project.id];
    if (inFlight != null) return inFlight;

    late final Future<ModrinthProject> request;
    request = _fetchResourceProjectVersions(project).whenComplete(() {
      if (identical(_resourceHydrations[project.id], request)) {
        _resourceHydrations.remove(project.id);
      }
    });
    _resourceHydrations[project.id] = request;
    return request;
  }

  Future<ModrinthProject> _fetchResourceProjectVersions(
    ModrinthProject project,
  ) async {
    try {
      final versions = await _loadResourceVersionPage(project, offset: 0);
      if (versions.isNotEmpty) return project.withVersions(versions);
    } on Exception {
      // Network errors keep the versions that came with the search result.
    }
    return project;
  }

  Future<void> _installModrinthProject(
    ModrinthProject project, [
    ModrinthVersion? requestedVersion,
  ]) async {
    if (_isDownloadingResources || _isInstallingMinecraft) {
      _showVersionMessage('已有下载任务正在进行，请等待完成或先取消当前任务。');
      return;
    }
    final targetVersion = requestedVersion ?? project.versions.firstOrNull;
    // Start fetching every version immediately; the target picker must open
    // without waiting for the network.
    final hydration = project.versions.isEmpty
        ? _hydrateResourceProject(project, force: true)
        : Future<ModrinthProject>.value(project);
    unawaited(hydration.catchError((Object _) => project));
    final target = await _pickDownloadTarget(
      modTitle: project.displayTitle,
      gameVersions: targetVersion?.gameVersions ?? const <String>[],
      loaders: targetVersion?.loaders ?? const <String>[],
    );
    if (target == null) return;
    final selected = target.client;
    final cancellation = DownloadCancellationToken();
    _setPageState(() {
      _isDownloadingResources = true;
      _activeDownloadToken = cancellation;
      _activeDownloadTask = '准备下载「${project.title}」';
    });
    try {
      try {
        final effectiveProject = await hydration;
        await _downloadModrinthProject(
          effectiveProject,
          selected,
          requestedVersion: requestedVersion,
          cancellation: cancellation,
          customRootPath: target.customRoot,
        );
      } on DownloadCancelledException {
        _showVersionMessage('下载已取消，临时文件已清理。');
      } on FileSystemException catch (error) {
        _showVersionMessage('无法保存「${project.title}」：${error.message}');
      } on HandshakeException catch (error) {
        _showVersionMessage('下载「${project.title}」时 TLS 连接失败：${error.message}');
      } on IOException catch (error) {
        _showVersionMessage('下载「${project.title}」失败：$error');
      } on TimeoutException {
        _showVersionMessage('下载「${project.title}」超时，请稍后重试。');
      }
    } finally {
      {
        _setPageState(() {
          _isDownloadingResources = false;
          if (identical(_activeDownloadToken, cancellation)) {
            _activeDownloadToken = null;
          }
          _activeDownloadTask = null;
        });
      }
    }
  }

  Future<void> _downloadResourceCandidates() async {
    if (_isDownloadingResources ||
        _isInstallingMinecraft ||
        _candidateManager.isEmpty) {
      if (_isInstallingMinecraft) {
        _showVersionMessage('已有下载任务正在进行，请等待完成或先取消当前任务。');
      }
      return;
    }

    final target = await _pickDownloadTarget(
      modTitle: '候选清单（${_candidateManager.length} 项）',
      gameVersions: const <String>[],
      loaders: const <String>[],
    );
    if (target == null) return;
    final selected = target.client;

    final cancellation = DownloadCancellationToken();
    _setPageState(() {
      _isDownloadingResources = true;
      _activeDownloadToken = cancellation;
      _activeDownloadTask = '准备下载候选资源…';
    });

    try {
      final candidates = _candidateManager.items;
      if (candidates.isEmpty) {
        _showVersionMessage('候选列表为空，请重新添加资源。');
        return;
      }
      final failed = <String>[];
      final unmatched = <String>[];
      var completed = 0;

      for (final candidate in candidates) {
        if (cancellation.isCancelled) break;
        _setPageState(() {
          _activeDownloadTask = '正在获取「${candidate.englishName}」的完整版本列表…';
        });

        ModrinthVersion? matched;
        try {
          matched = await _findMatchingVersion(candidate.project, selected);
        } on TimeoutException {
          failed.add(candidate.englishName);
          _showVersionMessage('获取「${candidate.englishName}」的版本分页超时，已跳过。');
          continue;
        } on Exception catch (error) {
          failed.add(candidate.englishName);
          _showVersionMessage('获取「${candidate.englishName}」的匹配版本失败：$error');
          continue;
        }
        if (cancellation.isCancelled) break;

        if (matched == null) {
          unmatched.add(candidate.englishName);
          continue;
        }

        var resolvedLoader = candidate.loader;
        if (resolvedLoader == null && selected.loaderType != null) {
          resolvedLoader = resourceLoaderKey(selected.loaderType!);
        }
        resolvedLoader ??= matched.loaders
            .map(resourceLoaderKey)
            .where((key) => key.isNotEmpty)
            .firstOrNull;
        final resolvedProject = candidate.project.withVersions(
          <ModrinthVersion>[matched],
        );
        final resolvedCandidate = CandidateMod(
          englishName: candidate.englishName,
          projectId: candidate.projectId,
          project: resolvedProject,
          version: matched,
          versionId: matched.versionId,
          loader: resolvedLoader,
        );
        _setPageState(() => _candidateManager.add(resolvedCandidate));

        var downloaded = false;
        try {
          downloaded = await _downloadModrinthProject(
            resolvedProject,
            selected,
            requestedVersion: matched,
            cancellation: cancellation,
            customRootPath: target.customRoot,
            renameOnConflict: true,
          );
        } on DownloadCancelledException {
          break;
        } on FileSystemException catch (error) {
          _showVersionMessage(
            '无法保存「${resolvedProject.title}」：${error.message}',
          );
        } on HandshakeException catch (error) {
          _showVersionMessage(
            '下载「${resolvedProject.title}」时 TLS 连接失败：${error.message}',
          );
        } on IOException catch (error) {
          _showVersionMessage('下载「${resolvedProject.title}」失败：$error');
        } on TimeoutException {
          _showVersionMessage('下载「${resolvedProject.title}」超时，请稍后重试。');
        }

        if (downloaded) {
          completed++;
          _setPageState(() {
            _candidateManager.remove(candidate.projectId);
            _candidatesToRemove.remove(candidate.projectId);
          });
        } else if (!cancellation.isCancelled) {
          failed.add(resolvedProject.title);
        }
      }

      _setPageState(() {});
      if (cancellation.isCancelled) {
        _showVersionMessage('下载已取消，临时文件已清理。');
        return;
      }
      final messages = <String>['已完成 $completed 个候选资源的下载'];
      if (failed.isNotEmpty) {
        messages.add('${failed.length} 个获取或下载失败：${failed.join('、')}');
      }
      if (unmatched.isNotEmpty) {
        messages.add(
          '${unmatched.length} 个没有匹配「${selected.id}」的版本：'
          '${unmatched.join('、')}',
        );
      }
      _showVersionMessage('${messages.join('；')}。');
    } finally {
      {
        _setPageState(() {
          _isDownloadingResources = false;
          if (identical(_activeDownloadToken, cancellation)) {
            _activeDownloadToken = null;
          }
          _activeDownloadTask = null;
        });
      }
    }
  }

  Future<List<ModrinthVersion>> _loadResourceVersionIndex(
    ModrinthProject project,
  ) {
    if (project.source == ResourceSource.modrinth) {
      return ModrinthService.fetchVersionIndex(project.id);
    }
    return CurseForgeService.fetchVersionIndex(project.id);
  }

  Future<List<ModrinthVersion>> _loadResourceVersionPage(
    ModrinthProject project, {
    required int offset,
    int limit = resourceVersionPageSize,
    List<String>? gameVersions,
    List<String>? loaders,
  }) {
    if (project.source == ResourceSource.modrinth) {
      return ModrinthService.fetchVersionPage(
        project.id,
        offset: offset,
        limit: limit,
        gameVersions: gameVersions,
        loaders: loaders,
      );
    }
    return CurseForgeService.fetchVersionPage(
      project.id,
      offset: offset,
      limit: limit,
    );
  }

  Future<ModrinthVersion?> _findMatchingVersion(
    ModrinthProject project,
    MinecraftVersion client,
  ) async {
    final minecraftVersion = client.minecraftVersion?.trim();
    final loader = client.loaderType?.trim();
    if (project.source == ResourceSource.modrinth) {
      final gameFilters = <String>{};
      if (minecraftVersion != null && minecraftVersion.isNotEmpty) {
        gameFilters.add(minecraftVersion);
        final family = resourceVersionFamily(minecraftVersion);
        if (family.isNotEmpty) gameFilters.add(family);
      }
      final versions = await ModrinthService.fetchVersionPage(
        project.id,
        gameVersions: gameFilters.toList(growable: false),
        loaders: loader == null || loader.isEmpty
            ? null
            : <String>[loader.toLowerCase()],
      );
      return resource.matchVersionForClient(
        project.withVersions(versions),
        client,
      );
    }

    var offset = 0;
    for (var page = 0; page < 20; page++) {
      final versions = await CurseForgeService.fetchVersionPage(
        project.id,
        offset: offset,
      );
      if (versions.isEmpty) return null;
      final matched = resource.matchVersionForClient(
        project.withVersions(versions),
        client,
      );
      if (matched != null) return matched;
      if (versions.length < resourceVersionPageSize) return null;
      offset += versions.length;
    }
    return null;
  }

  Future<bool> _downloadModrinthProject(
    ModrinthProject project,
    MinecraftVersion selected, {
    ModrinthVersion? requestedVersion,
    DownloadCancellationToken? cancellation,
    String? customRootPath,
    bool renameOnConflict = false,
  }) async {
    cancellation?.throwIfCancelled();

    _setPageState(() => _activeDownloadTask = '正在下载：${project.title}');
    final Iterable<ModrinthVersion> compatible;
    if (customRootPath != null) {
      // A hand-picked folder carries no client metadata to validate against.
      compatible = requestedVersion == null
          ? project.versions
          : <ModrinthVersion>[requestedVersion];
    } else {
      compatible = project.versions.where((version) {
        final gameVersion = selected.minecraftVersion;
        final hasGameVersion =
            gameVersion == null || version.gameVersions.contains(gameVersion);
        final selectedLoader = selected.loaderType?.toLowerCase();
        final hasLoader =
            project.category != DownloadCategory.mods ||
            selectedLoader == null ||
            version.loaders.any(
              (loader) => loader.toLowerCase() == selectedLoader,
            );
        return hasGameVersion && hasLoader;
      });
    }
    // The player explicitly picked this client in the target picker, so an
    // incompatible version is allowed on purpose (e.g. Sinytra Connector).
    // Prefer the requested file, then the best compatible one, then any file.
    final version =
        requestedVersion ??
        compatible.firstOrNull ??
        project.versions.firstOrNull;
    if (version == null) {
      _showVersionMessage(
        '${project.source.label} 没有为「${project.title}」提供可下载文件。',
      );
      return false;
    }
    final fileInfo = version.files.firstOrNull;
    if (fileInfo == null) {
      _showVersionMessage(
        '${project.source.label} 没有为「${project.title}」提供可下载文件。',
      );
      return false;
    }
    final downloadUri = Uri.tryParse(fileInfo.url);
    if (downloadUri == null ||
        downloadUri.scheme != 'https' ||
        !isTrustedResourceHost(downloadUri) ||
        fileInfo.filename.isEmpty ||
        fileInfo.filename.contains('/') ||
        fileInfo.filename.contains('\\') ||
        fileInfo.filename == '.' ||
        fileInfo.filename == '..') {
      _showVersionMessage('${project.source.label} 返回了无效的下载地址或文件名，已取消下载。');
      return false;
    }
    final basePath = customRootPath ?? selected.directoryPath;
    String folder;
    String targetDirectoryPath;
    switch (project.category) {
      case DownloadCategory.mods:
        folder = 'mods';
        targetDirectoryPath = minecraftVersionSubfolder(basePath, 'mods');
      case DownloadCategory.shaders:
        folder = 'shaderpacks';
        targetDirectoryPath = minecraftVersionSubfolder(
          basePath,
          'shaderpacks',
        );
      case DownloadCategory.resourcePacks:
        folder = 'resourcepacks';
        targetDirectoryPath = minecraftVersionSubfolder(
          basePath,
          'resourcepacks',
        );
      case DownloadCategory.dataPacks:
        if (project.source == ResourceSource.curseForge) {
          folder = 'saves';
          targetDirectoryPath = minecraftVersionSubfolder(basePath, 'saves');
        } else {
          final worldPath = await _chooseWorldFolderForDataPack(selected);
          if (worldPath == null) return false;
          folder = 'datapacks';
          targetDirectoryPath = minecraftVersionSubfolder(
            worldPath,
            'datapacks',
          );
        }
    }
    final targetDirectory = Directory(targetDirectoryPath);
    var targetFile = File(
      '${targetDirectory.path}${Platform.pathSeparator}${fileInfo.filename}',
    );
    if (await targetFile.exists()) {
      if (!renameOnConflict) {
        _showVersionMessage('「${fileInfo.filename}」已经存在。');
        return false;
      }
      // One-click batches may contain two files with the same name.
      targetFile = await _uniqueTargetFile(targetDirectory, fileInfo.filename);
    }
    HttpClient? client;
    void abort() => client?.close(force: true);
    cancellation?.addListener(abort);
    Future<void> performDownload(DownloadJob? job) async {
      await targetDirectory.create(recursive: true);
      client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      final request = await client!.getUrl(downloadUri);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      cancellation?.throwIfCancelled();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: downloadUri);
      }
      final totalBytes = response.contentLength > 0
          ? response.contentLength
          : 0;
      job?.updateProgress(0, totalBytes: totalBytes);
      final sink = targetFile.openWrite();
      var receivedBytes = 0;
      try {
        await for (final chunk in response.timeout(
          const Duration(seconds: 30),
        )) {
          cancellation?.throwIfCancelled();
          sink.add(chunk);
          receivedBytes += chunk.length;
          job?.updateProgress(receivedBytes, totalBytes: totalBytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      cancellation?.throwIfCancelled();
      job?.updateProgress(totalBytes, totalBytes: totalBytes);
    }

    try {
      final job = DownloadJob(
        id: _downloadManager.createJobId('resource'),
        label: fileInfo.filename,
        groupLabel: '${project.title} · ${selected.id}',
        kind: project.category.label,
        path: targetFile.path,
        cancellation: cancellation,
      );
      await _downloadManager.enqueue(job, (job) => performDownload(job));
      _showVersionMessage('已下载「${fileInfo.filename}」到 $folder。');
      final selectedDetail = _selectedVersion;
      if (selectedDetail?.path == selected.directoryPath) {
        await _loadManagedMods(selectedDetail!);
      }
      return true;
    } on DownloadCancelledException {
      if (await targetFile.exists()) await targetFile.delete();
      rethrow;
    } on SocketException catch (error) {
      if (await targetFile.exists()) await targetFile.delete();
      _showVersionMessage('下载失败：${error.message}');
      return false;
    } on HttpException catch (error) {
      if (await targetFile.exists()) await targetFile.delete();
      _showVersionMessage('下载失败：${error.message}');
      return false;
    } on HandshakeException catch (error) {
      if (await targetFile.exists()) await targetFile.delete();
      _showVersionMessage('下载 TLS 连接失败：${error.message}');
      return false;
    } on TimeoutException {
      if (await targetFile.exists()) await targetFile.delete();
      _showVersionMessage('下载超时，请检查网络后重试。');
      return false;
    } on FileSystemException catch (error) {
      if (await targetFile.exists()) await targetFile.delete();
      _showVersionMessage('无法保存模组文件：${error.message}');
      return false;
    } finally {
      cancellation?.removeListener(abort);
      client?.close(force: true);
      _setPageState(() => _activeDownloadTask = null);
    }
  }

  /// Picks a free `<name> (n).ext` path inside [directory].
  Future<File> _uniqueTargetFile(Directory directory, String filename) async {
    final separator = Platform.pathSeparator;
    final dot = filename.lastIndexOf('.');
    final stem = dot > 0 ? filename.substring(0, dot) : filename;
    final extension = dot > 0 ? filename.substring(dot) : '';
    for (var index = 1; index < 1000; index++) {
      final candidate = File(
        '${directory.path}$separator$stem ($index)$extension',
      );
      if (!await candidate.exists()) return candidate;
    }
    return File('${directory.path}$separator$filename');
  }

  Future<String?> _chooseWorldFolderForDataPack(
    MinecraftVersion selected,
  ) async {
    final savesPath = minecraftVersionSubfolder(
      selected.directoryPath,
      'saves',
    );
    String? path;
    try {
      path = await FilePicker.getDirectoryPath(
        dialogTitle: '选择要安装数据包的世界文件夹（包含 level.dat）',
        initialDirectory: savesPath,
      );
    } on FormatException catch (error) {
      path = await _promptDirectoryPath(
        title: '选择 Minecraft 世界文件夹',
        initialPath: savesPath,
        pickerError: error.message,
      );
    } on PlatformException catch (error) {
      path = await _promptDirectoryPath(
        title: '选择 Minecraft 世界文件夹',
        initialPath: savesPath,
        pickerError: error.message ?? error.code,
      );
    }
    if (path == null) return null;
    final levelData = File('$path${Platform.pathSeparator}level.dat');
    if (!await levelData.exists()) {
      _showVersionMessage('所选目录不是 Minecraft 世界文件夹（未找到 level.dat）。');
      return null;
    }
    return path;
  }

  Future<void> handleToggleResourceCandidate(ModrinthProject project) =>
      _toggleResourceCandidate(project);

  Future<void> handleOpenResourceProject(ModrinthProject project) =>
      _openResourceProject(project);

  void handleBackToResourceList() => _backToResourceList();

  Future<void> handleInstallModrinthProject(
    ModrinthProject project, [
    ModrinthVersion? version,
  ]) => _installModrinthProject(project, version);

  Future<void> handleDownloadResourceCandidates() =>
      _downloadResourceCandidates();

  void handleToggleVersionCandidate(
    ModrinthProject project,
    ModrinthVersion version,
  ) => resource.toggleVersionCandidate(project, version);
}
