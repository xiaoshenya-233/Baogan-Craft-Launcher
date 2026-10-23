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
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                          itemCount: candidates.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final candidate = candidates[index];
                            final project = candidate.project;
                            final selected = _candidatesToRemove.contains(
                              project.id,
                            );
                            return Container(
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
                                        _candidatesToRemove.remove(project.id);
                                      }
                                    });
                                    setSheetState(() {});
                                  },
                                ),
                                title: project.category == DownloadCategory.mods
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
                                      _candidatesToRemove.remove(project.id);
                                    });
                                    setSheetState(() {});
                                  },
                                  icon: const Icon(Icons.delete_outline),
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
    required this.versionsFor,
    required this.panelColor,
    required this.accentColor,
    required this.borderColor,
    required this.mutedColor,
    this.initialLoader,
    this.allowDefer = false,
  });

  final ModrinthProject project;
  final Future<ModrinthProject> Function() loadProject;
  final List<String> Function(ModrinthProject project) loadersFor;
  final List<String> Function(ModrinthProject project) gameVersionsFor;
  final List<ModrinthVersion> Function(
    ModrinthProject project,
    String gameVersion,
    String? loaderKey,
  )
  versionsFor;
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
  bool _loading = true;
  String? _loadError;
  ModrinthProject? _loadedProject;
  List<String> _projectLoaders = const [];
  Map<String, List<String>> _groups = const {};
  String? _selectedMajor;
  String? _selectedMinor;
  List<_ResourceVersionRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _selectedLoader = allResourceLoaderKey;
    unawaited(_loadProjectData());
  }

  Future<void> _loadProjectData() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _rows = const [];
    });
    try {
      final project = await widget.loadProject();
      if (!mounted) return;

      final loaders = widget.loadersFor(project);
      final gameVersions = widget.gameVersionsFor(project);
      final groups = resourceVersionGroups(gameVersions);
      final firstMajor = groups.keys.firstOrNull;
      final initialLoader = widget.initialLoader;

      setState(() {
        _loadedProject = project;
        _projectLoaders = loaders;
        _groups = groups;
        _selectedMajor = firstMajor;
        _selectedMinor = firstMajor == null
            ? null
            : groups[firstMajor]!.firstOrNull;
        _selectedLoader =
            initialLoader != null && loaders.contains(initialLoader)
            ? initialLoader
            : allResourceLoaderKey;
        _loading = false;
        _loadError = gameVersions.isEmpty ? '该资源没有可用于选择的 Minecraft 版本。' : null;
        _refreshRows();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _rows = const [];
        _loadError = '获取版本列表失败：$error';
      });
    }
  }

  /// Builds the display rows once per filter change.
  ///
  /// Filtering, sorting and string joins for hundreds of versions must not run
  /// inside `itemBuilder`, otherwise every scroll frame repeats that work.
  void _refreshRows() {
    final project = _loadedProject;
    final minor = _selectedMinor;
    if (project == null || minor == null) {
      _rows = const [];
      return;
    }
    final versions = widget.versionsFor(
      project,
      minor,
      _selectedLoader == allResourceLoaderKey ? null : _selectedLoader,
    );
    _rows = versions.map(_rowFor).toList(growable: false);
  }

  _ResourceVersionRow _rowFor(ModrinthVersion version) {
    final title = version.name.trim().isEmpty
        ? version.files.firstOrNull?.filename ?? '未命名版本'
        : version.name;
    final loaderLabel = version.loaders.isEmpty
        ? '加载器未标注'
        : version.loaders.map(resourceLoaderLabel).join(' / ');
    final subtitle = version.gameVersions.isEmpty
        ? loaderLabel
        : '${version.gameVersions.join(' · ')} · $loaderLabel';
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
            _buildFilters(context),
            Expanded(child: _buildVersionList(context)),
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

  Widget _buildFilters(BuildContext context) {
    final majors = _groups.keys.toList();
    final minors = _selectedMajor == null
        ? const <String>[]
        : _groups[_selectedMajor] ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Minecraft 大版本',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: widget.mutedColor,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: majors
                .map(
                  (major) => ChoiceChip(
                    label: Text(major),
                    selected: _selectedMajor == major,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      setState(() {
                        _selectedMajor = major;
                        _selectedMinor = _groups[major]!.firstOrNull;
                        _refreshRows();
                      });
                    },
                  ),
                )
                .toList(),
          ),
          if (minors.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '具体版本',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: widget.mutedColor,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: minors
                  .map(
                    (minor) => ChoiceChip(
                      label: Text(minor),
                      selected: _selectedMinor == minor,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) {
                        setState(() {
                          _selectedMinor = minor;
                          _refreshRows();
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
          if (_projectLoaders.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedLoader,
              decoration: const InputDecoration(labelText: '模组加载器'),
              items: [allResourceLoaderKey, ..._projectLoaders]
                  .map(
                    (loader) => DropdownMenuItem(
                      value: loader,
                      child: Text(
                        loader == allResourceLoaderKey
                            ? '全部加载器'
                            : resourceLoaderLabel(loader),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedLoader = value;
                  _refreshRows();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVersionList(BuildContext context) {
    final project = _loadedProject;
    if (project == null || _selectedMinor == null) {
      return Center(
        child: Text('请选择具体版本。', style: TextStyle(color: widget.mutedColor)),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Text(
          '当前版本和加载器没有可下载文件。',
          style: TextStyle(color: widget.mutedColor),
        ),
      );
    }

    // `ListView.builder` + fixed extent builds only the visible rows. The parent
    // `Expanded` supplies the bounded height inside the fixed-height sheet, so
    // the list scrolls on its own (never shrinkWrap + NeverScrollablePhysics,
    // which would measure every version up front).
    return ListView.builder(
      key: const ValueKey('resource-version-list'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _rows.length,
      itemExtent: 64,
      itemBuilder: (context, index) {
        final row = _rows[index];
        return RepaintBoundary(
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
        );
      },
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
