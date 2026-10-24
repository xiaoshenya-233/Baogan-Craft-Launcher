import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/installer/version_models.dart';
import '../../services/network/api_service.dart';
import '../../services/translation/database_service.dart';
import '../../widgets/launcher/activity_banner.dart';
import '../../widgets/localized_mod_title.dart';
import '../../widgets/launcher/launcher_common.dart';
import '../launcher/controllers/download_activity_controller.dart';
import '../launcher/launcher_palette.dart';
import '../versions/controllers/version_catalog_controller.dart';
import 'controllers/resource_download_controller.dart';

part 'resource_downloads_detail.dart';
part 'resource_downloads_widgets.dart';

class ResourceDownloadsPage extends StatefulWidget {
  const ResourceDownloadsPage({
    super.key,
    required this.resource,
    required this.activity,
    required this.catalog,
    required this.palette,
    required this.isDark,
    required this.isDownloadLocked,
    required this.minecraftEntryBuilder,
    required this.onLoadResults,
    required this.onScheduleSearch,
    required this.onToggleCandidate,
    required this.onOpenProject,
    required this.onBackToList,
    required this.onInstallProject,
    required this.onDownloadCandidates,
    required this.onToggleVersionCandidate,
    required this.onOpenDownloadTasks,
    required this.onCancelActiveDownload,
  });

  final ResourceDownloadController resource;
  final DownloadActivityController activity;
  final VersionCatalogController catalog;
  final LauncherPalette palette;
  final bool isDark;
  final bool isDownloadLocked;
  final Widget Function(bool compact) minecraftEntryBuilder;
  final Future<void> Function() onLoadResults;
  final VoidCallback onScheduleSearch;
  final Future<void> Function(ModrinthProject) onToggleCandidate;
  final Future<void> Function(ModrinthProject) onOpenProject;
  final VoidCallback onBackToList;
  final Future<void> Function(ModrinthProject, ModrinthVersion?)
  onInstallProject;
  final Future<void> Function() onDownloadCandidates;
  final void Function(ModrinthProject, ModrinthVersion)
  onToggleVersionCandidate;
  final VoidCallback onOpenDownloadTasks;
  final VoidCallback onCancelActiveDownload;

  @override
  State<ResourceDownloadsPage> createState() => _ResourceDownloadsPageState();
}

class _ResourceDownloadsPageState extends State<ResourceDownloadsPage> {
  ResourceDownloadController get resource => widget.resource;
  DownloadActivityController get activity => widget.activity;
  VersionCatalogController get catalog => widget.catalog;
  LauncherPalette get palette => widget.palette;

  static const _green = Color(0xFF8BC34A);

  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{
    '资源来源': GlobalKey(debugLabel: '资源来源'),
    '资源分类': GlobalKey(debugLabel: '资源分类'),
    '资源搜索': GlobalKey(debugLabel: '资源搜索'),
  };

  /// Number of files currently revealed inside each expanded detail card.
  ///
  /// This is deliberately local to the detail page: opening a card only reveals
  /// the first 20 rows, and the card's own footer reveals the next 20. There is
  /// no page-level "load more" state anymore.
  final Map<String, int> _detailCardVisibleCounts = <String, int>{};
  String? _detailCardVisibleProjectId;
  String? get _activeDownloadTask => activity.activeTask;
  DownloadCategory get _downloadCategory => resource.category;
  set _downloadCategory(DownloadCategory value) => resource.category = value;
  ResourceSource get _resourceSource => resource.source;
  set _resourceSource(ResourceSource value) => resource.source = value;
  AggregatePreference get _aggregatePreference => resource.aggregatePreference;
  List<ModrinthProject> get _resourceResults => resource.results;
  int get _resourceTotalHits => resource.totalHits;
  bool get _isLoadingResources => resource.isLoading;
  String? get _resourceLoadError => resource.loadError;
  int get _resourcePage => resource.page;
  set _resourcePage(int value) => resource.page = value;
  CandidateManager get _candidateManager => resource.candidateManager;
  Set<String> get _candidatesToRemove => resource.candidatesToRemove;
  ModrinthProject? get _resourceDetailProject => resource.detailProject;
  bool get _isLoadingResourceDetail => resource.isLoadingDetail;
  String? get _resourceDetailError => resource.detailError;
  String? get _resourceSelectedLoader => resource.selectedLoader;
  set _resourceSelectedLoader(String? value) => resource.selectedLoader = value;
  String? get _resourceSelectedGameFamily => resource.selectedGameFamily;
  set _resourceSelectedGameFamily(String? value) =>
      resource.selectedGameFamily = value;
  String? get _resourceExpandedGameVersion => resource.expandedGameVersion;
  set _resourceExpandedGameVersion(String? value) =>
      resource.expandedGameVersion = value;
  bool get _isDownloadingResources => resource.isDownloading;
  TextEditingController get _resourceSearchController =>
      resource.searchController;
  Color get _muted => palette.muted;
  Color get _panelColor => palette.panelColor;
  Color get _panelBorderColor => palette.panelBorderColor;
  Color get _panelAccentColor => palette.panelAccentColor;
  Color get _selectedSurfaceColor => palette.selectedSurfaceColor;
  Color get _selectedForegroundColor => palette.selectedForegroundColor;
  Color get _buttonForeground => palette.buttonForeground;
  bool get _usesDarkPalette => widget.isDark;
  String get _resourceSourceDisplayLabel =>
      _resourceSource == ResourceSource.aggregate
      ? 'Modrinth + CurseForge'
      : _resourceSource.label;
  String get _resourceSourceFooterLabel {
    if (_resourceSource != ResourceSource.aggregate ||
        _aggregatePreference == AggregatePreference.balanced) {
      return _resourceSourceDisplayLabel;
    }
    return '$_resourceSourceDisplayLabel（${_aggregatePreference.label}）';
  }

  @override
  void initState() {
    super.initState();
    resource.addListener(_onResourceChanged);
  }

  @override
  void dispose() {
    resource.removeListener(_onResourceChanged);
    super.dispose();
  }

  void _onResourceChanged() {
    if (mounted) setState(() {});
  }

  void _setPageState(VoidCallback callback) => setState(callback);
  void _scheduleResourceSearch() => widget.onScheduleSearch();
  Future<void> _loadResourceResults() => widget.onLoadResults();
  Future<void> _toggleResourceCandidate(ModrinthProject project) =>
      widget.onToggleCandidate(project);
  Future<void> _openResourceProject(ModrinthProject project) =>
      widget.onOpenProject(project);
  void _backToResourceList() => widget.onBackToList();
  Future<void> _installModrinthProject(
    ModrinthProject project, [
    ModrinthVersion? version,
  ]) => widget.onInstallProject(project, version);
  Future<void> _downloadResourceCandidates() => widget.onDownloadCandidates();
  Widget _translucentButton(Widget button, {double radius = 10}) {
    return TranslucentButtonSurface(radius: radius, child: button);
  }

  Widget _buildActiveDownloadBanner() =>
      ActivityBanner(onOpenDownloads: _openDownloadTasks);

  Widget _buildVersionEmptyState({
    required IconData icon,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _panelBorderColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: const Color(0xFF778171)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            _translucentButton(
              TextButton(onPressed: onAction, child: Text(actionLabel)),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleVersionCandidate(
    ModrinthProject project,
    ModrinthVersion version,
  ) => widget.onToggleVersionCandidate(project, version);
  void _changeResourcePage(int page) => resource.loadNextPage(page);
  void _openDownloadTasks() => widget.onOpenDownloadTasks();

  @override
  Widget build(BuildContext context) => _buildResourceDownloads();

  Widget _buildResourceDownloads() {
    if (_resourceDetailProject != null) return _buildResourceProjectDetail();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final visibleProjects = _resourceResults;
        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                compact ? 20 : 36,
                30,
                compact ? 20 : 36,
                _candidateManager.isEmpty ? 32 : 104,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '资源下载',
                        style: TextStyle(
                          fontSize: compact ? 26 : 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '浏览游戏模组、材质包、光影与地图资源。',
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                      if (_activeDownloadTask != null) ...[
                        const SizedBox(height: 14),
                        _buildActiveDownloadBanner(),
                      ],
                      const SizedBox(height: 22),
                      widget.minecraftEntryBuilder(compact),
                      const SizedBox(height: 22),
                      KeyedSubtree(
                        key: _sectionKeys['资源来源'],
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '资源来源',
                              style: TextStyle(fontSize: 11, color: _muted),
                            ),
                            ...ResourceSource.values.map((source) {
                              final selected = _resourceSource == source;
                              return _translucentButton(
                                ChoiceChip(
                                  label: Text(source.label),
                                  selected: selected,
                                  onSelected: (_) {
                                    if (_resourceSource == source) return;
                                    _setPageState(() {
                                      _resourceSource = source;
                                      _resourcePage = 0;
                                    });
                                    _loadResourceResults();
                                  },
                                  selectedColor: _selectedSurfaceColor,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    color: selected
                                        ? _selectedForegroundColor
                                        : _muted,
                                  ),
                                  showCheckmark: false,
                                ),
                                radius: 22,
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      KeyedSubtree(
                        key: _sectionKeys['资源分类'],
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: DownloadCategory.values.map((category) {
                            final selected = _downloadCategory == category;
                            return _translucentButton(
                              ChoiceChip(
                                label: Text(category.label),
                                selected: selected,
                                onSelected: (_) {
                                  _setPageState(() {
                                    _downloadCategory = category;
                                    _resourcePage = 0;
                                  });
                                  _loadResourceResults();
                                },
                                selectedColor: _selectedSurfaceColor,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: selected
                                      ? _selectedForegroundColor
                                      : _muted,
                                ),
                                showCheckmark: false,
                              ),
                              radius: 22,
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      KeyedSubtree(
                        key: _sectionKeys['资源搜索'],
                        child: TextField(
                          key: const ValueKey('modrinth-search'),
                          controller: _resourceSearchController,
                          onChanged: (value) {
                            _setPageState(() {
                              resource.searchQuery = value;
                              _resourcePage = 0;
                            });
                            _scheduleResourceSearch();
                          },
                          onSubmitted: (_) => _loadResourceResults(),
                          decoration: InputDecoration(
                            hintText: _downloadCategory == DownloadCategory.mods
                                ? '搜索 $_resourceSourceDisplayLabel 模组'
                                : '搜索 $_resourceSourceDisplayLabel 资源',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: _muted,
                            ),
                            suffixIcon: IconButton(
                              tooltip: '搜索',
                              onPressed: _loadResourceResults,
                              icon: Icon(
                                Icons.arrow_forward_rounded,
                                color: _green,
                              ),
                            ),
                            filled: true,
                            fillColor: _panelColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '数据来源：$_resourceSourceFooterLabel · 显示项目下载人数',
                          style: TextStyle(fontSize: 10, color: _muted),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingResources)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_resourceLoadError != null)
                        _buildVersionEmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: '暂时无法加载资源',
                          description: _resourceLoadError!,
                          actionLabel: '重试',
                          onAction: _loadResourceResults,
                        )
                      else if (visibleProjects.isEmpty)
                        _buildVersionEmptyState(
                          icon: Icons.search_off_rounded,
                          title: '没有找到资源',
                          description: '调整搜索词或切换资源分类后重试。',
                        )
                      else
                        ...visibleProjects.map(
                          (project) => RepaintBoundary(
                            child: _buildModrinthProjectCard(project),
                          ),
                        ),
                      if (!_isLoadingResources &&
                          _resourceLoadError == null &&
                          _resourceResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _resourcePage == 0
                                  ? null
                                  : () =>
                                        _changeResourcePage(_resourcePage - 1),
                              icon: const Icon(Icons.chevron_left_rounded),
                              label: const Text('上一页'),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text('第 ${_resourcePage + 1} 页'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  (_resourcePage + 1) * 20 >= _resourceTotalHits
                                  ? null
                                  : () =>
                                        _changeResourcePage(_resourcePage + 1),
                              icon: const Icon(Icons.chevron_right_rounded),
                              label: const Text('下一页'),
                              iconAlignment: IconAlignment.end,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (!_candidateManager.isEmpty)
              Positioned(
                right: compact ? 18 : 30,
                bottom: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    FloatingActionButton(
                      heroTag: 'resource-candidates',
                      onPressed: _showResourceCandidates,
                      tooltip: '查看候选资源',
                      child: const Icon(Icons.playlist_add_check_rounded),
                    ),
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE45858),
                          border: Border.all(color: _panelColor, width: 2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_candidateManager.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
