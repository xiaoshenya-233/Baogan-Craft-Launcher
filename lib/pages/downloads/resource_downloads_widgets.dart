part of 'resource_downloads_page.dart';

/// Candidate sheet, loader heuristics and the version picker UI.
extension _ResourceCandidatesSheet on _ResourceDownloadsPageState {
  void _showResourceCandidates() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final candidates = _candidateManager.items;
          return Container(
            height: MediaQuery.sizeOf(context).height * 0.72,
            decoration: BoxDecoration(
              color: _panelColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: Border.all(color: _panelBorderColor),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '候选资源 (${candidates.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _candidatesToRemove.isEmpty
                            ? null
                            : () {
                                _setPageState(() {
                                  _candidateManager.removeAll(
                                    _candidatesToRemove,
                                  );
                                  _candidatesToRemove.clear();
                                });
                                setSheetState(() {});
                              },
                        icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                        label: Text('删除所选 (${_candidatesToRemove.length})'),
                      ),
                      OutlinedButton.icon(
                        onPressed: candidates.isEmpty
                            ? null
                            : () {
                                _setPageState(() {
                                  _candidateManager.clear();
                                  _candidatesToRemove.clear();
                                });
                                setSheetState(() {});
                              },
                        icon: const Icon(Icons.clear_all_rounded, size: 17),
                        label: const Text('清空候选'),
                      ),
                      FilledButton.icon(
                        onPressed: candidates.isEmpty || _isDownloadingResources
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                unawaited(_downloadResourceCandidates());
                              },
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: Text(
                          _isDownloadingResources ? '正在下载…' : '一键下载全部',
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: candidates.isEmpty
                      ? Center(
                          child: Text(
                            '候选列表为空。',
                            style: TextStyle(color: _muted),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                          itemCount: candidates.length,
                          itemBuilder: (context, index) {
                            final candidate = candidates[index];
                            final project = candidate.project;
                            final selected = _candidatesToRemove.contains(
                              project.id,
                            );
                            return RepaintBoundary(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _panelAccentColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    leading: Checkbox(
                                      value: selected,
                                      onChanged: (value) {
                                        _setPageState(() {
                                          if (value == true) {
                                            _candidatesToRemove.add(project.id);
                                          } else {
                                            _candidatesToRemove.remove(
                                              project.id,
                                            );
                                          }
                                        });
                                        setSheetState(() {});
                                      },
                                    ),
                                    title:
                                        project.category ==
                                            DownloadCategory.mods
                                        ? LocalizedModTitle(
                                            englishTitle: project.title,
                                          )
                                        : Text(project.displayTitle),
                                    subtitle: Text(
                                      candidate.version == null
                                          ? '${project.category.label} · '
                                                '${formatDownloadCount(project.downloads)} 下载 · '
                                                '下载时选择版本'
                                          : '${candidate.version!.name} · '
                                                '${candidate.loader == null ? '加载器未标注' : resourceLoaderLabel(candidate.loader!)} · '
                                                '${project.category.label}',
                                    ),
                                    trailing: IconButton(
                                      tooltip: '从候选移除',
                                      onPressed: () {
                                        _setPageState(() {
                                          _candidateManager.remove(project.id);
                                          _candidatesToRemove.remove(
                                            project.id,
                                          );
                                        });
                                        setSheetState(() {});
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<String> _orderedResourceLoaderKeys(Iterable<String> keys) {
    final order = [...resourceLoaderKeys, unknownResourceLoaderKey];
    final ordered = keys.where(order.contains).toSet().toList();
    ordered.sort(
      (left, right) => order.indexOf(left).compareTo(order.indexOf(right)),
    );
    return ordered;
  }

  List<String> _projectLoaderKeys(ModrinthProject project) {
    if (project.category != DownloadCategory.mods) return const [];
    final keys = <String>{};
    for (final version in project.versions) {
      for (final loader in version.loaders) {
        final key = resourceLoaderKey(loader);
        if (key.isNotEmpty) keys.add(key);
      }
    }
    for (final tag in project.tags) {
      final key = resourceLoaderKey(tag);
      if (key.isNotEmpty) keys.add(key);
    }
    return _orderedResourceLoaderKeys(keys);
  }

  String _projectLoaderSupportText(ModrinthProject project) {
    final projectLoaders = _projectLoaderKeys(project);
    final labels = projectLoaders.map(resourceLoaderLabel).toList();
    final hasUnknown =
        project.category == DownloadCategory.mods &&
        project.versions.any(
          (version) => _versionLoaderKeys(
            project,
            version,
            projectLoaders: projectLoaders,
          ).contains(unknownResourceLoaderKey),
        );
    if (hasUnknown) labels.add('未标注');
    return labels.isEmpty ? '支持加载器：未标注' : '支持加载器：${labels.join(' · ')}';
  }

  bool _isLegacyMinecraftVersion(String value) {
    final parts = baseGameVersion(value).split('.');
    if (parts.length < 2) return false;
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    return major == 1 && minor != null && minor <= 13;
  }

  /// Resolves the loaders for one file.
  ///
  /// CurseForge files for older Minecraft versions often omit loader labels
  /// from `gameVersions`. Treating an empty loader list as "compatible with
  /// everything" made a Forge-only 1.12.2 file appear under Fabric. Unknown
  /// files are inferred from the filename, the project's known loaders, or the
  /// Minecraft generation; if none applies they are not assigned to an
  /// unrelated loader.
  List<String> _versionLoaderKeys(
    ModrinthProject project,
    ModrinthVersion version, {
    List<String>? projectLoaders,
  }) {
    if (project.category != DownloadCategory.mods) return const [];
    final direct = <String>{};
    for (final loader in version.loaders) {
      final key = resourceLoaderKey(loader);
      if (key.isNotEmpty) direct.add(key);
    }
    if (direct.isNotEmpty) return _orderedResourceLoaderKeys(direct);

    final filename = version.files.firstOrNull?.filename ?? version.name;
    final inferredFromName = resourceLoaderKey(filename);
    if (inferredFromName.isNotEmpty) return [inferredFromName];

    final knownProjectLoaders = projectLoaders ?? _projectLoaderKeys(project);
    final gameVersion = version.gameVersions.firstOrNull ?? '';
    if (_isLegacyMinecraftVersion(gameVersion) &&
        knownProjectLoaders.contains('forge')) {
      return const ['forge'];
    }
    if (knownProjectLoaders.length == 1) return knownProjectLoaders;

    // Keep files that have no usable loader metadata visible. Returning an
    // empty list would silently hide those versions as soon as a loader chip
    // is selected, which is how historical Forge files disappeared from the
    // version list on mixed-loader projects.
    return const [unknownResourceLoaderKey];
  }

  bool _versionMatchesLoader(
    ModrinthProject project,
    ModrinthVersion version,
    String? loaderKey, {
    List<String>? projectLoaders,
  }) {
    if (loaderKey == null) return true;
    return _versionLoaderKeys(
      project,
      version,
      projectLoaders: projectLoaders,
    ).contains(loaderKey);
  }

  List<String> _loaderKeysForFamily(
    ModrinthProject project,
    String family, {
    List<String>? projectLoaders,
  }) {
    if (project.category != DownloadCategory.mods) return const [];
    final knownProjectLoaders = projectLoaders ?? _projectLoaderKeys(project);
    final keys = <String>{};
    for (final version in project.versions) {
      if (!version.gameVersions.any(
        (gameVersion) => resourceVersionMajorFamily(gameVersion) == family,
      )) {
        continue;
      }
      keys.addAll(
        _versionLoaderKeys(
          project,
          version,
          projectLoaders: knownProjectLoaders,
        ),
      );
    }
    return _orderedResourceLoaderKeys(keys);
  }

  String? _preferredLoaderForFamily(
    ModrinthProject project,
    String family, {
    List<String>? projectLoaders,
  }) {
    String? best;
    var bestCount = -1;
    final knownProjectLoaders = projectLoaders ?? _projectLoaderKeys(project);
    for (final loader in _loaderKeysForFamily(
      project,
      family,
      projectLoaders: knownProjectLoaders,
    )) {
      final count = project.versions.where((version) {
        return version.gameVersions.any(
              (gameVersion) =>
                  resourceVersionMajorFamily(gameVersion) == family,
            ) &&
            _versionMatchesLoader(
              project,
              version,
              loader,
              projectLoaders: knownProjectLoaders,
            );
      }).length;
      if (count > bestCount) {
        bestCount = count;
        best = loader;
      }
    }
    return best;
  }

  List<String> _projectGameVersions(
    ModrinthProject project, {
    String? loaderKey,
    List<String>? projectLoaders,
  }) {
    final knownProjectLoaders = projectLoaders ?? _projectLoaderKeys(project);
    final versions = <String>{};
    if (loaderKey == null) {
      versions.addAll(project.supportedGameVersions);
    }
    for (final version in project.versions) {
      if (!_versionMatchesLoader(
        project,
        version,
        loaderKey,
        projectLoaders: knownProjectLoaders,
      )) {
        continue;
      }
      versions.addAll(normalizeResourceGameVersions(version.gameVersions));
    }
    return versions.toList()
      ..sort((left, right) => compareGameVersions(right, left));
  }

  List<ModrinthVersion> _projectVersionsForGame(
    ModrinthProject project, {
    String? loaderKey,
    List<String>? projectLoaders,
    required String gameVersion,
  }) {
    final knownProjectLoaders = projectLoaders ?? _projectLoaderKeys(project);
    return project.versions
        .where(
          (version) =>
              version.gameVersions.any(
                (candidate) => resourceVersionFamily(candidate) == gameVersion,
              ) &&
              _versionMatchesLoader(
                project,
                version,
                loaderKey,
                projectLoaders: knownProjectLoaders,
              ),
        )
        .toList()
      ..sort((left, right) => right.downloads.compareTo(left.downloads));
  }

  bool _isVersionCandidate(ModrinthProject project, ModrinthVersion version) {
    final candidate = _candidateManager.find(project.id)?.version;
    return candidate != null &&
        (identical(candidate, version) ||
            (candidate.name == version.name &&
                candidate.gameVersions.join(',') ==
                    version.gameVersions.join(',')));
  }
}

class ResourceVersionPickerSheet extends StatefulWidget {
  const ResourceVersionPickerSheet({
    super.key,
    required this.project,
    required this.loadProject,
    required this.loadersFor,
    required this.gameVersionsFor,
    required this.panelColor,
    required this.accentColor,
    required this.borderColor,
    required this.mutedColor,
    this.initialLoader,
    this.allowDefer = false,
  });

  final ModrinthProject project;
  final Future<ModrinthProject> Function() loadProject;

  /// Loaders reported for the hydrated project index.
  final List<String> Function(ModrinthProject project) loadersFor;

  /// Minecraft versions reported for the hydrated project index.
  final List<String> Function(ModrinthProject project) gameVersionsFor;

  final String? initialLoader;
  final bool allowDefer;
  final Color panelColor;
  final Color accentColor;
  final Color borderColor;
  final Color mutedColor;

  @override
  State<ResourceVersionPickerSheet> createState() =>
      ResourceVersionPickerSheetState();
}

class ResourceVersionPickerSheetState
    extends State<ResourceVersionPickerSheet> {
  late String _selectedLoader;
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _hasLoadedPage = false;
  bool _hasMoreVersions = false;
  String? _loadError;
  String? _pageError;
  int _loadedVersionOffset = 0;

  final Set<String> _loadedVersionIds = <String>{};
  ModrinthProject? _loadedProject;
  List<String> _projectLoaders = const [];

  /// Concrete versions grouped by major release, newest first.
  Map<String, List<String>> _majorGroups = const {};

  /// Downloadable file count per concrete version of the selected major.
  Map<String, int> _fileCounts = const {};
  String? _selectedMajor;
  String? _selectedGameVersion;
  List<_ResourceVersionRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _selectedLoader = allResourceLoaderKey;
    // Render the loading sheet first; never let a synchronous part of the
    // loader delay the route's first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadProjectData());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectData() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _pageError = null;
      _hasLoadedPage = false;
      _rows = const [];
      _loadedVersionOffset = 0;
      _hasMoreVersions = false;
      _loadedVersionIds.clear();
    });
    try {
      final project = await widget.loadProject();
      if (!mounted) return;
      final loaders = widget.loadersFor(project);
      final gameVersions = widget.gameVersionsFor(project);
      final options =
          <String>{
              ...project.supportedGameVersions,
              ...gameVersions,
            }.where((version) => version.trim().isNotEmpty).toList()
            ..sort((left, right) => compareGameVersions(right, left));
      final groups = resourceVersionGroups(options);
      if (groups.isEmpty) {
        throw StateError('该资源没有可用于选择的 Minecraft 版本。');
      }
      final initialLoader = widget.initialLoader;
      final loader = initialLoader != null && loaders.contains(initialLoader)
          ? initialLoader
          : allResourceLoaderKey;
      final major = _defaultMajor(project, groups, loader);
      final counts = _countsFor(project, groups, major, loader);

      setState(() {
        _loadedProject = project;
        _projectLoaders = loaders;
        _majorGroups = groups;
        _selectedMajor = major;
        _selectedGameVersion = null;
        _selectedLoader = loader;
        _fileCounts = counts;
        _loading = false;
        _loadError = null;
        _rows = const [];
        _loadedVersionOffset = 0;
        _hasMoreVersions = false;
        _hasLoadedPage = false;
        _pageError = null;
        _loadedVersionIds.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _rows = const [];
        _majorGroups = const {};
        _fileCounts = const {};
        _selectedMajor = null;
        _selectedGameVersion = null;
        _loadedVersionOffset = 0;
        _hasMoreVersions = false;
        _hasLoadedPage = false;
        _loadedVersionIds.clear();
        _loadError = error is TimeoutException
            ? '加载失败，网络较慢，点击重试。'
            : '加载失败，点击重试：$error';
      });
    }
  }

  /// Picks the newest major release that actually ships a file for
  /// [loaderKey], falling back to the newest major when nothing matches.
  ///
  /// A single pass over the hydrated project index keeps this cheap even when
  /// the index holds thousands of files.
  String _defaultMajor(
    ModrinthProject project,
    Map<String, List<String>> groups,
    String loaderKey,
  ) {
    final loader = loaderKey == allResourceLoaderKey ? null : loaderKey;
    final availableFamilies = <String>{};
    for (final version in project.versions) {
      if (!version.files.any((file) => file.url.isNotEmpty)) continue;
      if (loader != null &&
          !_loaderMatches(version, loader, project: project)) {
        continue;
      }
      for (final gameVersion in version.gameVersions) {
        final family = resourceVersionFamily(gameVersion);
        if (family.isNotEmpty) availableFamilies.add(family);
      }
    }
    for (final major in groups.keys) {
      if (groups[major]!.any(availableFamilies.contains)) return major;
    }
    return groups.keys.first;
  }

  /// Counts downloadable files for every concrete version of [major].
  ///
  /// Uses the exact same [_matches] predicate as the file list, so a card's
  /// count and the list behind it can never disagree.
  Map<String, int> _countsFor(
    ModrinthProject project,
    Map<String, List<String>> groups,
    String major,
    String loaderKey,
  ) {
    final loader = loaderKey == allResourceLoaderKey ? null : loaderKey;
    final versions = groups[major] ?? const <String>[];
    final counts = <String, int>{};
    for (final version in versions) {
      final count = project.versions
          .where((entry) => _matches(project, entry, version, loader))
          .length;
      counts[version] = count;
      debugPrint(
        '[FileList] 统计: gameVersion=$version, '
        'loader=${loader ?? allResourceLoaderKey}, count=$count',
      );
    }
    return counts;
  }

  bool _matches(
    ModrinthProject project,
    ModrinthVersion version,
    String gameVersion,
    String? loaderKey,
  ) {
    final family = resourceVersionFamily(gameVersion);
    if (family.isEmpty) return false;
    if (!version.gameVersions.any(
      (candidate) => resourceVersionFamily(candidate) == family,
    )) {
      return false;
    }
    if (loaderKey != null &&
        !_loaderMatches(version, loaderKey, project: project)) {
      return false;
    }
    return version.files.any((file) => file.url.isNotEmpty);
  }

  /// Loader match shared by filtering and the default-version pick.
  bool _loaderMatches(
    ModrinthVersion version,
    String loaderKey, {
    ModrinthProject? project,
  }) {
    final direct = version.loaders
        .map(resourceLoaderKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    if (direct.isNotEmpty) return direct.contains(loaderKey);
    final filename = version.files.firstOrNull?.filename ?? version.name;
    final inferred = resourceLoaderKey(filename);
    if (inferred.isNotEmpty) return inferred == loaderKey;
    final knownLoaders = widget.loadersFor(
      project ?? _loadedProject ?? widget.project,
    );
    return knownLoaders.length == 1 && knownLoaders.first == loaderKey;
  }

  void _selectLoader(String loader) {
    if (_selectedLoader == loader) return;
    final project = _loadedProject;
    final major = _selectedMajor;
    setState(() {
      _selectedLoader = loader;
      // A loader change invalidates the file view; show the version cards of
      // the same major with fresh counts instead of refetching files.
      _selectedGameVersion = null;
      _resetVersionList();
      if (project != null && major != null) {
        _fileCounts = _countsFor(project, _majorGroups, major, loader);
      }
    });
    _scrollToTop();
  }

  void _selectMajor(String major) {
    if (_selectedMajor == major) return;
    final project = _loadedProject;
    if ((_majorGroups[major] ?? const <String>[]).isEmpty) return;
    setState(() {
      _selectedMajor = major;
      _selectedGameVersion = null;
      _resetVersionList();
      if (project != null) {
        _fileCounts = _countsFor(project, _majorGroups, major, _selectedLoader);
      }
    });
    _scrollToTop();
  }

  /// View A -> View B: only now are files loaded.
  void _openGameVersion(String version) {
    final count = _fileCounts[version] ?? 0;
    if (count <= 0) return;
    if (_selectedGameVersion == version) return;
    debugPrint(
      '[FileList] 点击具体版本: gameVersion=$version, '
      'loader=$_selectedLoader, 统计数量=$count',
    );
    setState(() {
      _selectedGameVersion = version;
      _resetVersionList();
    });
    _scrollToTop();
    _loadVersions();
  }

  void _backToVersionCards() {
    if (_selectedGameVersion == null) return;
    setState(() {
      _selectedGameVersion = null;
      _resetVersionList();
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _resetVersionList() {
    _rows = const [];
    _loadedVersionIds.clear();
    _loadedVersionOffset = 0;
    _hasMoreVersions = false;
    _hasLoadedPage = false;
    _pageError = null;
  }

  String _versionKey(ModrinthVersion version) =>
      version.versionId ??
      '${version.name}|${version.files.map((file) => file.filename).join(',')}';

  /// Loads the next page of 20 files from the already hydrated project index.
  ///
  /// Counting ([_countsFor]) and paging now share [_matches], so the number on
  /// a version card can never disagree with the file list. The project index is
  /// already required for the cards, so there is no extra network request here:
  /// the CurseForge page endpoint ignores version/loader filters, which made a
  /// card with 232 files open an empty list.
  void _loadVersions() {
    final project = _loadedProject;
    final gameVersion = _selectedGameVersion;
    if (project == null || gameVersion == null) return;
    final loaderKey = _selectedLoader == allResourceLoaderKey
        ? null
        : _selectedLoader;
    final offset = _loadedVersionOffset;
    debugPrint(
      '[FileList] 请求参数: gameVersion=$gameVersion, '
      'loader=${loaderKey ?? allResourceLoaderKey}, '
      'offset=$offset, limit=$resourceVersionPageSize',
    );
    try {
      final filtered = _localVersions(project, gameVersion, loaderKey);
      debugPrint(
        '[FileList] API 返回数据长度: ${project.versions.length}, '
        '过滤后数据长度: ${filtered.length}',
      );
      final start = offset.clamp(0, filtered.length);
      final page = filtered
          .skip(start)
          .take(resourceVersionPageSize)
          .toList(growable: false);
      debugPrint(
        '[FileList] 本次返回数据长度: ${page.length}, '
        '累计 ${start + page.length}/${filtered.length}',
      );
      setState(() {
        for (final version in page) {
          if (_loadedVersionIds.add(_versionKey(version))) {
            _rows = <_ResourceVersionRow>[..._rows, _rowFor(version)];
          }
        }
        _loadedVersionOffset = start + page.length;
        _hasMoreVersions = _loadedVersionOffset < filtered.length;
        _pageError = null;
        _hasLoadedPage = true;
      });
    } catch (error, stackTrace) {
      debugPrint('[FileList] 加载文件列表失败: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _hasLoadedPage = true;
        _pageError = '加载失败：$error';
      });
    }
  }

  List<ModrinthVersion> _localVersions(
    ModrinthProject project,
    String gameVersion,
    String? loaderKey,
  ) {
    // Deliberately the same predicate as `_countsFor`; a source-specific filter
    // with different loader/version semantics must never be used here.
    return project.versions
        .where((version) => _matches(project, version, gameVersion, loaderKey))
        .toList(growable: false)
      ..sort((left, right) => right.downloads.compareTo(left.downloads));
  }

  _ResourceVersionRow _rowFor(ModrinthVersion version) {
    final filename = version.files.firstOrNull?.filename.trim() ?? '';
    final versionName = version.name.trim();
    final title = filename.isNotEmpty
        ? filename
        : (versionName.isEmpty ? '未命名版本' : versionName);
    final loaderLabel = version.loaders.isEmpty
        ? '加载器未标注'
        : version.loaders.map(resourceLoaderLabel).join(' / ');
    final subtitle = <String>[
      if (versionName.isNotEmpty && versionName != title) versionName,
      if (version.gameVersions.isNotEmpty) version.gameVersions.join(' · '),
      loaderLabel,
    ].join(' · ');
    return _ResourceVersionRow(
      version: version,
      title: title,
      subtitle: subtitle,
      loader: _loaderFor(version),
    );
  }

  String? _loaderFor(ModrinthVersion version) {
    if (_selectedLoader != allResourceLoaderKey) return _selectedLoader;
    return version.loaders
        .map(resourceLoaderKey)
        .where((key) => key.isNotEmpty)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final title = _loadedProject?.displayTitle ?? widget.project.displayTitle;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.78,
      decoration: BoxDecoration(
        color: widget.panelColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        children: [
          _buildHeader(context, title),
          const Divider(height: 1),
          if (_loading)
            const Expanded(
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (_loadError != null)
            Expanded(child: _buildLoadError(context))
          else ...[
            _buildFilters(),
            Expanded(
              child: _selectedGameVersion == null
                  ? _buildVersionCards(context)
                  : _buildFileList(context),
            ),
          ],
          if (widget.allowDefer) _buildDeferButton(context),
        ],
      ),
    );
  }

  Widget _buildLoadError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: widget.mutedColor),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadProjectData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '选择版本与加载器 · $title',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final majors = _majorGroups.keys.toList(growable: false);
    final loaders = <String>[allResourceLoaderKey, ..._projectLoaders];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterLabel('Minecraft 大版本'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              for (final major in majors)
                ChoiceChip(
                  key: ValueKey('picker-major-$major'),
                  label: Text(major),
                  selected: _selectedMajor == major,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _selectMajor(major),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildFilterLabel('模组加载器'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              for (final loader in loaders)
                ChoiceChip(
                  key: ValueKey('picker-loader-$loader'),
                  label: Text(
                    loader == allResourceLoaderKey
                        ? '全部加载器'
                        : resourceLoaderLabel(loader),
                  ),
                  selected: _selectedLoader == loader,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _selectLoader(loader),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterLabel(String label) => Text(
    label,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: widget.mutedColor,
    ),
  );

  /// View A: concrete version cards for the selected major and loader.
  ///
  /// This is the default body; files are requested only after a card is tapped.
  Widget _buildVersionCards(BuildContext context) {
    final versions = _selectedMajor == null
        ? const <String>[]
        : _majorGroups[_selectedMajor] ?? const <String>[];
    if (versions.isEmpty) {
      return Center(
        child: Text(
          '该大版本没有可选的具体版本。',
          style: TextStyle(color: widget.mutedColor),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('resource-version-cards'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      itemCount: versions.length,
      itemBuilder: (context, index) {
        final version = versions[index];
        final count = _fileCounts[version] ?? 0;
        final enabled = count > 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: enabled ? widget.accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              key: ValueKey('version-card-$version'),
              borderRadius: BorderRadius.circular(10),
              onTap: enabled ? () => _openGameVersion(version) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            version,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: enabled
                                  ? null
                                  : widget.mutedColor.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            enabled ? '$count 个可下载文件' : '该版本没有可下载文件',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (enabled)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: widget.mutedColor,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// View B: the paged file list of the concrete version chosen in View A.
  Widget _buildFileList(BuildContext context) {
    final project = _loadedProject;
    if (project == null || _selectedGameVersion == null) {
      return _buildVersionCards(context);
    }
    return Column(
      children: [
        _buildSelectedVersionBar(),
        Expanded(
          child: ListView.builder(
            key: const ValueKey('resource-version-file-list'),
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
            itemCount: _rows.length + 1,
            itemBuilder: (context, index) {
              if (index >= _rows.length) return _buildListFooter();
              return _buildFileRow(context, project, _rows[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedVersionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 14, 0),
      child: Row(
        children: [
          TextButton.icon(
            key: const ValueKey('version-picker-back'),
            onPressed: _backToVersionCards,
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: const Text('具体版本'),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              'Minecraft ${_selectedGameVersion ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: widget.mutedColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListFooter() {
    if (!_hasLoadedPage) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_pageError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton.icon(
            onPressed: _loadVersions,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(_pageError!),
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            '当前筛选条件下没有可下载文件。',
            style: TextStyle(color: widget.mutedColor, fontSize: 12),
          ),
        ),
      );
    }
    if (_hasMoreVersions) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: _loadVersions,
            icon: const Icon(Icons.expand_more_rounded, size: 18),
            label: const Text('加载更多文件'),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          '已加载全部 ${_rows.length} 个文件',
          style: TextStyle(color: widget.mutedColor, fontSize: 11.5),
        ),
      ),
    );
  }

  Widget _buildFileRow(
    BuildContext context,
    ModrinthProject project,
    _ResourceVersionRow row,
  ) {
    return SizedBox(
      height: 64,
      child: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Material(
            color: widget.accentColor,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                Navigator.pop(
                  context,
                  ResourceVersionChoice(
                    project: project,
                    version: row.version,
                    loader: row.loader,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            row.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: widget.mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeferButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.pop(
            context,
            ResourceVersionChoice(
              project: _loadedProject ?? widget.project,
              defer: true,
            ),
          );
        },
        icon: const Icon(Icons.schedule_rounded, size: 18),
        label: const Text('稍后选择'),
      ),
    );
  }
}

/// Precomputed row of the resource version list.
///
/// Title/subtitle strings are built once when filters change so `itemBuilder`
/// never joins game versions or maps loader labels while scrolling.
class _ResourceVersionRow {
  const _ResourceVersionRow({
    required this.version,
    required this.title,
    required this.subtitle,
    required this.loader,
  });

  final ModrinthVersion version;
  final String title;
  final String subtitle;
  final String? loader;
}
