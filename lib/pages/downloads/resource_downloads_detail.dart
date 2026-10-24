part of 'resource_downloads_page.dart';

/// Project cards and the resource detail view.
extension _ResourceDetailWidgets on _ResourceDownloadsPageState {
  Widget _buildModrinthProjectCard(ModrinthProject project) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => unawaited(_openResourceProject(project)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _panelColor.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _panelBorderColor),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 540;
              final tags = resourceTagsWithoutLoaders(project.tags);
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProjectIcon(project),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            project.category == DownloadCategory.mods
                                ? LocalizedModTitle(
                                    englishTitle: project.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : Text(
                                    project.displayTitle,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                            const SizedBox(height: 4),
                            Text(
                              project.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: _muted),
                            ),
                            if (project.category == DownloadCategory.mods) ...[
                              const SizedBox(height: 5),
                              Text(
                                _projectLoaderSupportText(project),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedForegroundColor,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              '${project.category.label} · ${formatDownloadCount(project.downloads)} 下载'
                              ' · ${project.source.label}'
                              '${project.source == ResourceSource.modrinth ? ' · ${project.followers} 关注' : ''}',
                              style: TextStyle(
                                fontSize: 10,
                                color: _selectedForegroundColor,
                              ),
                            ),
                            if (tags.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 6,
                                runSpacing: 5,
                                children: tags
                                    .map((tag) => _buildModTag(tag))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 12),
                        _buildProjectDownloadButton(project),
                      ],
                    ],
                  ),
                  if (compact) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildProjectDownloadButton(project),
                    ),
                  ],
                ],
              );
              return content;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProjectIcon(
    ModrinthProject project, {
    double size = 46,
    double radius = 9,
  }) {
    final imageUrl = project.iconUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl == null
            ? ColoredBox(
                color: _panelAccentColor,
                child: Icon(
                  Icons.extension_rounded,
                  color: _ResourceDownloadsPageState._green,
                  size: size * 0.48,
                ),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: _panelAccentColor,
                  child: Icon(
                    Icons.extension_rounded,
                    color: _ResourceDownloadsPageState._green,
                    size: size * 0.48,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildModTag(String label) {
    final appearance = resourceTagAppearance(label, dark: _usesDarkPalette);
    final translated = ModTagTranslationService.instance.translate(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: appearance.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: appearance.border),
      ),
      child: Text(
        translated,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: appearance.foreground,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildProjectDownloadButton(ModrinthProject project) {
    final isCandidate = _candidateManager.contains(project.id);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _translucentButton(
          OutlinedButton.icon(
            onPressed: _isDownloadingResources
                ? null
                : () => _installModrinthProject(project),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('下载'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _buttonForeground,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        _translucentButton(
          OutlinedButton.icon(
            onPressed: _isDownloadingResources
                ? null
                : () => unawaited(_toggleResourceCandidate(project)),
            icon: Icon(
              isCandidate ? Icons.check_circle_outline : Icons.playlist_add,
              size: 16,
            ),
            label: Text(isCandidate ? '已选' : '候选'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isCandidate
                  ? _selectedForegroundColor
                  : _buttonForeground,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResourceProjectDetail() {
    final project = _resourceDetailProject;
    if (project == null) return const SizedBox.shrink();
    final tags = resourceTagsWithoutLoaders(project.tags);
    final supportedLoaders = project.category == DownloadCategory.mods
        ? _projectLoaderSupportText(project)
        : null;
    return _buildResourcePageFrame(
      backLabel: '返回资源列表',
      onBack: _backToResourceList,
      children: [
        _buildResourceHero(project),
        const SizedBox(height: 18),
        if (_isLoadingResourceDetail) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 12),
        ],
        if (supportedLoaders != null) ...[
          const SizedBox(height: 8),
          Text(
            supportedLoaders,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _selectedForegroundColor,
            ),
          ),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map(_buildModTag).toList(),
          ),
        ],
        if (_resourceDetailError != null) ...[
          const SizedBox(height: 14),
          Text(
            _resourceDetailError!,
            style: const TextStyle(color: Color(0xFFE58A7A), fontSize: 11),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => unawaited(_openResourceProject(project)),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('加载失败，请重试'),
          ),
        ],
        const SizedBox(height: 24),
        if (_isLoadingResourceDetail && project.versions.isEmpty)
          Text('正在获取最新版本…', style: TextStyle(color: _muted))
        else
          _buildResourceVersionContent(project),
      ],
    );
  }

  Widget _buildResourceLoaderSelector({
    required List<String> loaders,
    required String? selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '模组加载器',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('全部'),
              selected: selected == null,
              onSelected: (_) {
                _setPageState(() {
                  _resourceSelectedLoader = allResourceLoaderKey;
                  _resourceExpandedGameVersion = null;
                  _detailCardVisibleCounts.clear();
                });
              },
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
            ),
            ...loaders.map((key) {
              return ChoiceChip(
                label: Text(resourceLoaderLabel(key)),
                selected: selected == key,
                onSelected: (_) {
                  _setPageState(() {
                    _resourceSelectedLoader = key;
                    _resourceExpandedGameVersion = null;
                    _detailCardVisibleCounts.clear();
                  });
                },
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildResourceFamilySelector(
    ModrinthProject project,
    List<String> families,
    String? selectedFamily, {
    List<String>? projectLoaders,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Minecraft 大版本',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (families.isEmpty)
          Text('当前筛选没有收录游戏版本。', style: TextStyle(color: _muted))
        else
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: families.map((family) {
              final selected = selectedFamily == family;
              return ChoiceChip(
                label: Text(family),
                selected: selected,
                onSelected: (_) {
                  _setPageState(() {
                    _resourceSelectedGameFamily = family;
                    _detailCardVisibleCounts.clear();
                    if (!_loaderKeysForFamily(
                      project,
                      family,
                      projectLoaders: projectLoaders,
                    ).contains(_resourceSelectedLoader)) {
                      _resourceSelectedLoader = allResourceLoaderKey;
                    }
                    _resourceExpandedGameVersion = null;
                  });
                },
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildResourceMinorVersionOutline(
    ModrinthProject project, {
    required String family,
    required String gameVersion,
    required String? loaderKey,
    List<String>? projectLoaders,
  }) {
    final versions =
        _projectVersionsForGame(
          project,
          loaderKey: loaderKey,
          projectLoaders: projectLoaders,
          gameVersion: gameVersion,
        ).where((version) {
          final file = version.files.firstOrNull;
          return file != null && file.url.isNotEmpty;
        }).toList();
    final count = versions.length;
    final expanded = _resourceExpandedGameVersion == gameVersion;
    final cardKey = _detailVersionCardKey(family, gameVersion, loaderKey);
    final visibleCount =
        _detailCardVisibleCounts[cardKey] ?? resourceVersionPageSize;
    final shown = versions.take(visibleCount).toList();
    final hasMore = shown.length < count;
    final enabled = count > 0;
    debugPrint(
      '[VersionPicker] 当前版本: $gameVersion, '
      '总版本数据源长度: ${project.versions.length}, 过滤后数量: $count',
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expanded ? _selectedForegroundColor : _panelBorderColor,
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: enabled
                  ? () {
                      debugPrint(
                        '[VersionPicker] 请求: $gameVersion, '
                        '加载器: ${loaderKey ?? allResourceLoaderKey}',
                      );
                      _setPageState(() {
                        _resourceSelectedGameFamily = family;
                        if (expanded) {
                          _resourceExpandedGameVersion = null;
                          _detailCardVisibleCounts.remove(cardKey);
                        } else {
                          _resourceExpandedGameVersion = gameVersion;
                          _detailCardVisibleCounts.putIfAbsent(
                            cardKey,
                            () => resourceVersionPageSize,
                          );
                        }
                      });
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Minecraft $gameVersion',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: enabled
                                  ? null
                                  : _muted.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$count 个可下载文件',
                            style: TextStyle(fontSize: 10, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    if (enabled)
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: _muted,
                      ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: shown.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '没有与当前加载器匹配的文件。',
                              style: TextStyle(color: _muted, fontSize: 11),
                            ),
                          )
                        : Column(
                            children: [
                              ...shown.map(
                                (version) => _buildResourceVersionRow(
                                  project,
                                  version,
                                  nested: true,
                                ),
                              ),
                              if (hasMore) ...[
                                const SizedBox(height: 4),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      _setPageState(() {
                                        _detailCardVisibleCounts[cardKey] =
                                            visibleCount +
                                            resourceVersionPageSize;
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.expand_more_rounded,
                                      size: 17,
                                    ),
                                    label: Text(
                                      '加载更多文件'
                                      '（${count - shown.length} 个剩余）',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _detailVersionCardKey(
    String family,
    String gameVersion,
    String? loaderKey,
  ) => '$family|$gameVersion|${loaderKey ?? allResourceLoaderKey}';

  String _versionTypeLabel(String versionType) => switch (versionType) {
    'release' => '正式版',
    'beta' => '测试版',
    'alpha' => '预览版',
    _ => versionType,
  };

  Widget _buildResourceVersionRow(
    ModrinthProject project,
    ModrinthVersion version, {
    bool nested = false,
  }) {
    final isCandidate = _isVersionCandidate(project, version);
    final fileInfo = version.files.firstOrNull;
    final loaderText = version.loaders.isEmpty
        ? '加载器未标注'
        : version.loaders.map(resourceLoaderLabel).join(' / ');
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          version.name.isEmpty ? '未命名版本' : version.name,
          style: TextStyle(
            fontSize: nested ? 12 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${_versionTypeLabel(version.versionType)} · $loaderText · '
          '${formatDownloadCount(version.downloads)} 下载',
          style: TextStyle(fontSize: 10, color: _muted),
        ),
        if (fileInfo != null) ...[
          const SizedBox(height: 3),
          Text(
            fileInfo.filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: _muted),
          ),
        ],
      ],
    );
    final actions = Wrap(
      spacing: 7,
      runSpacing: 6,
      children: [
        OutlinedButton.icon(
          onPressed: fileInfo == null
              ? null
              : () => unawaited(_installModrinthProject(project, version)),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('下载'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _buttonForeground,
            visualDensity: VisualDensity.compact,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _toggleVersionCandidate(project, version),
          icon: Icon(
            isCandidate ? Icons.check_circle_outline : Icons.playlist_add,
            size: 16,
          ),
          label: Text(isCandidate ? '已选' : '候选'),
          style: OutlinedButton.styleFrom(
            foregroundColor: isCandidate
                ? _selectedForegroundColor
                : _buttonForeground,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
    return Container(
      margin: EdgeInsets.only(bottom: nested ? 7 : 9),
      padding: EdgeInsets.all(nested ? 10 : 12),
      decoration: BoxDecoration(
        color: nested ? _panelAccentColor : _panelColor,
        borderRadius: BorderRadius.circular(nested ? 8 : 11),
        border: Border.all(color: _panelBorderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildResourceVersionContent(ModrinthProject project) {
    if (_detailCardVisibleProjectId != project.id) {
      _detailCardVisibleProjectId = project.id;
      _detailCardVisibleCounts.clear();
    }
    final isMod = project.category == DownloadCategory.mods;
    final projectLoaders = _projectLoaderKeys(project);
    final allGameVersions = _projectGameVersions(
      project,
      projectLoaders: projectLoaders,
    );
    final groups = resourceVersionGroups(allGameVersions);
    final families = groups.keys.toList();
    final selectedFamily = families.contains(_resourceSelectedGameFamily)
        ? _resourceSelectedGameFamily
        : families.firstOrNull;
    final loaders = selectedFamily == null
        ? const <String>[]
        : _loaderKeysForFamily(
            project,
            selectedFamily,
            projectLoaders: projectLoaders,
          );
    final selectedLoader = _resourceSelectedLoader == allResourceLoaderKey
        ? null
        : loaders.contains(_resourceSelectedLoader)
        ? _resourceSelectedLoader
        : (selectedFamily == null
              ? null
              : _preferredLoaderForFamily(
                  project,
                  selectedFamily,
                  projectLoaders: projectLoaders,
                ));
    final gameVersions = _projectGameVersions(
      project,
      loaderKey: isMod ? selectedLoader : null,
      projectLoaders: projectLoaders,
    );
    final filteredGroups = resourceVersionGroups(gameVersions);
    final minorVersions = selectedFamily == null
        ? const <String>[]
        : filteredGroups[selectedFamily] ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResourceFamilySelector(
          project,
          families,
          selectedFamily,
          projectLoaders: projectLoaders,
        ),
        if (isMod && loaders.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildResourceLoaderSelector(
            loaders: loaders,
            selected: selectedLoader,
          ),
        ],
        if (selectedFamily != null) ...[
          const SizedBox(height: 12),
          if (minorVersions.isEmpty)
            Text('该分类下没有可下载版本。', style: TextStyle(color: _muted))
          else
            Column(
              children: minorVersions
                  .map(
                    (gameVersion) => _buildResourceMinorVersionOutline(
                      project,
                      family: selectedFamily,
                      gameVersion: gameVersion,
                      loaderKey: isMod ? selectedLoader : null,
                      projectLoaders: projectLoaders,
                    ),
                  )
                  .toList(),
            ),
        ] else ...[
          const SizedBox(height: 12),
          Text('当前项目没有可显示的游戏版本。', style: TextStyle(color: _muted)),
        ],
      ],
    );
  }

  Widget _buildResourcePageFrame({
    required String backLabel,
    required VoidCallback onBack,
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final readingMaskColor = _usesDarkPalette
            ? Colors.black.withValues(alpha: 0.38)
            : Colors.white.withValues(alpha: 0.38);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 背景图与详情内容之间的阅读遮罩：提高正文对比度，
            // 同时保留背景图的可见层次。
            IgnorePointer(child: ColoredBox(color: readingMaskColor)),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                compact ? 20 : 36,
                22,
                compact ? 20 : 36,
                40,
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _translucentButton(
                        OutlinedButton.icon(
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: Text(backLabel),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _buttonForeground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResourceHero(
    ModrinthProject project, {
    double iconSize = 84,
    double titleSize = 28,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProjectIcon(project, size: iconSize, radius: 14),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              project.category == DownloadCategory.mods
                  ? LocalizedModTitle(
                      englishTitle: project.title,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    )
                  : Text(
                      project.displayTitle,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
              const SizedBox(height: 8),
              Text(
                project.description.isEmpty
                    ? '该资源没有提供简介。'
                    : project.description,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 8),
              Text(
                '${project.category.label} · ${project.source.label} · '
                '${formatDownloadCount(project.downloads)} 下载',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
