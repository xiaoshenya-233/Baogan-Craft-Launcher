import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/launcher_log.dart';
import '../../../services/installer/version_models.dart';
import '../../../services/network/api_service.dart';
import '../../../services/translation/database_service.dart';
import '../../../services/translation/mod_search_service.dart';

/// State for resource search, filters, candidates and the detail view.
class ResourceDownloadController extends ChangeNotifier {
  DownloadCategory category = DownloadCategory.mods;
  ResourceSource source = ResourceSource.aggregate;
  AggregatePreference aggregatePreference = AggregatePreference.balanced;
  final TextEditingController searchController = TextEditingController();
  Timer? _searchDebounce;
  String searchQuery = '';
  bool isLoading = false;
  String? loadError;
  List<ModrinthProject> results = [];
  int totalHits = 0;
  final CandidateManager candidateManager = CandidateManager();
  final Set<String> candidatesToRemove = {};
  ModrinthProject? detailProject;
  bool isLoadingDetail = false;
  String? detailError;
  String? selectedLoader;
  String? selectedGameFamily;
  String? expandedGameVersion;
  int page = 0;
  int requestId = 0;
  bool isDownloading = false;

  void beginRequest() {
    requestId++;
    isLoading = true;
    loadError = null;
    notifyListeners();
  }

  bool isCurrentRequest(int id) => id == requestId;

  void applyResults(List<ModrinthProject> projects, {int? hits}) {
    results = projects;
    totalHits = hits ?? projects.length;
    isLoading = false;
    loadError = null;
    notifyListeners();
  }

  void fail(String message) {
    loadError = message;
    isLoading = false;
    notifyListeners();
  }

  void resetResults() {
    results = [];
    totalHits = 0;
    loadError = null;
    isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    if (searchQuery == value) return;
    searchQuery = value;
    notifyListeners();
  }

  void scheduleSearch() {
    _searchDebounce?.cancel();
    requestId++;
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(loadResults()),
    );
  }

  void changePage(int nextPage) {
    page = nextPage;
    notifyListeners();
  }

  void loadNextPage(int nextPage) {
    if (nextPage < 0 || nextPage == page) return;
    page = nextPage;
    notifyListeners();
    unawaited(loadResults());
  }

  bool isCandidate(String projectId) => candidateManager.contains(projectId);

  bool isMarkedForRemoval(String projectId) =>
      candidatesToRemove.contains(projectId);

  void addCandidate(CandidateMod candidate) {
    candidateManager.add(candidate);
    candidatesToRemove.remove(candidate.projectId);
    notifyListeners();
  }

  void removeCandidate(String projectId) {
    candidateManager.remove(projectId);
    candidatesToRemove.remove(projectId);
    notifyListeners();
  }

  void toggleCandidateRemoval(String projectId) {
    if (!candidatesToRemove.add(projectId)) {
      candidatesToRemove.remove(projectId);
    }
    notifyListeners();
  }

  void clearCandidates() {
    candidateManager.clear();
    candidatesToRemove.clear();
    notifyListeners();
  }

  void removeSelectedCandidates() {
    if (candidatesToRemove.isEmpty) return;
    candidateManager.removeAll(candidatesToRemove);
    candidatesToRemove.clear();
    notifyListeners();
  }

  void openDetail(ModrinthProject project) {
    detailProject = project;
    detailError = null;
    isLoadingDetail = true;
    selectedLoader = null;
    selectedGameFamily = null;
    expandedGameVersion = null;
    notifyListeners();
  }

  void closeDetail() {
    detailProject = null;
    detailError = null;
    isLoadingDetail = false;
    selectedLoader = null;
    selectedGameFamily = null;
    expandedGameVersion = null;
    notifyListeners();
  }

  Future<void> loadResults() async {
    final request = ++requestId;
    final query = searchQuery.trim();
    LauncherLog.info(
      'Resources',
      '开始搜索资源：来源 ${source.name} · '
          '分类 ${category.name} · 关键词 ${query.isEmpty ? '（空）' : query}',
    );
    final chineseSearch =
        category == DownloadCategory.mods &&
        RegExp(r'[\u4e00-\u9fff]').hasMatch(query);
    final sourceLabel = switch (source) {
      ResourceSource.aggregate => 'Modrinth / CurseForge',
      ResourceSource.modrinth => 'Modrinth',
      ResourceSource.curseForge => 'CurseForge',
    };
    isLoading = true;
    loadError = null;
    notifyListeners();
    try {
      if (chineseSearch) {
        final projects = <ModrinthProject>[];
        final seenKeys = <String>{};
        Object? firstFailure;

        Future<void> collect(Future<List<ModrinthProject>> task) async {
          try {
            final fetched = await task;
            for (final project in fetched) {
              if (seenKeys.add('${project.source.name}:${project.id}')) {
                projects.add(project);
              }
            }
          } on Exception catch (error) {
            firstFailure ??= error;
          }
        }

        final tasks = <Future<void>>[];
        if (source != ResourceSource.curseForge) {
          tasks.add(collect(_searchChineseModrinth(query)));
        }
        if (source != ResourceSource.modrinth) {
          tasks.add(collect(_searchChineseCurseForge(query)));
        }
        await Future.wait(tasks);
        if (!isCurrentRequest(request)) return;
        final failure = firstFailure;
        if (projects.isEmpty && failure is Exception) throw failure;
        final results = _applyAggregatePreference(projects, source);
        if (source == ResourceSource.aggregate) {
          results.sort(
            (left, right) => right.downloads.compareTo(left.downloads),
          );
        }
        this.results = results;
        totalHits = results.length;
        isLoading = false;
        notifyListeners();
        return;
      }

      final pages = <ModrinthSearchPage>[];
      Object? firstFailure;

      Future<void> collectPage(Future<ModrinthSearchPage> task) async {
        try {
          pages.add(await task);
        } on Exception catch (error) {
          firstFailure ??= error;
        }
      }

      final tasks = <Future<void>>[];
      if (source != ResourceSource.curseForge) {
        tasks.add(
          collectPage(
            ModrinthService.search(
              query: query,
              category: category,
              offset: page * 20,
              includeVersions: false,
            ),
          ),
        );
      }
      if (source != ResourceSource.modrinth) {
        tasks.add(
          collectPage(
            CurseForgeService.search(
              query: query,
              category: category,
              offset: page * 20,
            ),
          ),
        );
      }
      await Future.wait(tasks);
      if (!isCurrentRequest(request)) return;
      final failure = firstFailure;
      if (pages.isEmpty && failure is Exception) throw failure;
      final merged = pages.expand((page) => page.projects).toList();
      var projects = _applyAggregatePreference(merged, source);
      if (category == DownloadCategory.mods && query.isNotEmpty) {
        projects = projects
            .where(
              (project) => resourceSearchMatchesQuery(
                query,
                project.title,
                project.description,
              ),
            )
            .toList();
      }
      projects.sort((left, right) => right.downloads.compareTo(left.downloads));
      final pageTotalHits = pages.fold<int>(
        0,
        (total, page) => total + page.totalHits,
      );
      final localizedProjects = category == DownloadCategory.mods
          ? projects
                .map((project) {
                  final cached = McmodTitleService.instance.cachedChineseTitle(
                    project.title,
                  );
                  return cached == null
                      ? project
                      : project.withChineseTitle(cached);
                })
                .toList(growable: false)
          : projects;
      results = localizedProjects;
      totalHits = pageTotalHits;
      isLoading = false;
      notifyListeners();
    } on SocketException catch (error) {
      _failRequest(request, '无法连接 $sourceLabel：${error.message}');
    } on HttpException catch (error) {
      _failRequest(request, '$sourceLabel 请求失败：${error.message}');
    } on HandshakeException catch (error) {
      _failRequest(request, '$sourceLabel TLS 连接失败：${error.message}');
    } on FormatException catch (error) {
      _failRequest(request, '$sourceLabel 返回的数据格式无效：${error.message}');
    } on TimeoutException {
      _failRequest(request, '连接 $sourceLabel 超时，请检查网络后重试。');
    }
  }

  void _failRequest(int request, String message) {
    if (!isCurrentRequest(request)) return;
    loadError = message;
    isLoading = false;
    notifyListeners();
  }

  Future<List<ModrinthProject>> _searchChineseModrinth(String query) async {
    final englishIds = await ModSearchService.instance
        .searchChineseToEnglishIds(query);
    if (englishIds.isEmpty) return const [];
    Object? firstFailure;
    final fetched = await Future.wait(
      englishIds.map((id) async {
        try {
          return await ModrinthService.fetchProjectById(id, category: category);
        } on Exception catch (error) {
          firstFailure ??= error;
          return null;
        }
      }),
    );
    final projects = fetched.whereType<ModrinthProject>().toList();
    final failure = firstFailure;
    if (projects.isEmpty && failure is Exception) throw failure;
    return projects;
  }

  Future<List<ModrinthProject>> _searchChineseCurseForge(String query) async {
    final curseForgeIds = await ModSearchService.instance
        .searchChineseToCurseForgeIds(query);
    if (curseForgeIds.isEmpty) return const [];
    Object? firstFailure;
    final fetched = await Future.wait(
      curseForgeIds.map((id) async {
        try {
          return await CurseForgeService.fetchProjectById(
            '$id',
            category: category,
          );
        } on Exception catch (error) {
          firstFailure ??= error;
          return null;
        }
      }),
    );
    final projects = fetched.whereType<ModrinthProject>().toList();
    final failure = firstFailure;
    if (projects.isEmpty && failure is Exception) throw failure;
    return projects;
  }

  List<ModrinthProject> _applyAggregatePreference(
    List<ModrinthProject> projects,
    ResourceSource source,
  ) {
    if (source != ResourceSource.aggregate ||
        aggregatePreference == AggregatePreference.balanced) {
      return List<ModrinthProject>.of(projects);
    }
    final preferredSource = aggregatePreference == AggregatePreference.modrinth
        ? ResourceSource.modrinth.name
        : ResourceSource.curseForge.name;
    return dedupeAggregateResults<ModrinthProject>(
      items: projects,
      titleOf: (project) => project.title,
      sourceOf: (project) => project.source.name,
      preferredSource: preferredSource,
    );
  }

  void clear() {
    results = [];
    totalHits = 0;
    loadError = null;
    isLoading = false;
    detailProject = null;
    detailError = null;
    isLoadingDetail = false;
    candidateManager.clear();
    candidatesToRemove.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    candidateManager.clear();
    candidatesToRemove.clear();
    super.dispose();
  }

  List<String> _orderedResourceLoaderKeys(Iterable<String> keys) {
    final order = [...resourceLoaderKeys, unknownResourceLoaderKey];
    final ordered = keys.where(order.contains).toSet().toList();
    ordered.sort(
      (left, right) => order.indexOf(left).compareTo(order.indexOf(right)),
    );
    return ordered;
  }

  void _update(VoidCallback action) {
    action();
    notifyListeners();
  }

  List<String> projectLoaderKeys(ModrinthProject project) {
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

  bool isLegacyMinecraftVersion(String value) {
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
  List<String> versionLoaderKeys(
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

    final knownProjectLoaders = projectLoaders ?? projectLoaderKeys(project);
    final gameVersion = version.gameVersions.firstOrNull ?? '';
    if (isLegacyMinecraftVersion(gameVersion) &&
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

  bool versionMatchesLoader(
    ModrinthProject project,
    ModrinthVersion version,
    String? loaderKey, {
    List<String>? projectLoaders,
  }) {
    if (loaderKey == null) return true;
    return versionLoaderKeys(
      project,
      version,
      projectLoaders: projectLoaders,
    ).contains(loaderKey);
  }

  List<String> projectGameVersions(
    ModrinthProject project, {
    String? loaderKey,
    List<String>? projectLoaders,
  }) {
    final knownProjectLoaders = projectLoaders ?? projectLoaderKeys(project);
    final versions = <String>{};
    for (final version in project.versions) {
      if (!versionMatchesLoader(
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

  List<ModrinthVersion> projectVersionsForGame(
    ModrinthProject project, {
    String? loaderKey,
    List<String>? projectLoaders,
    required String gameVersion,
  }) {
    final knownProjectLoaders = projectLoaders ?? projectLoaderKeys(project);
    return project.versions
        .where(
          (version) =>
              version.gameVersions.any(
                (candidate) => resourceVersionFamily(candidate) == gameVersion,
              ) &&
              versionMatchesLoader(
                project,
                version,
                loaderKey,
                projectLoaders: knownProjectLoaders,
              ),
        )
        .toList()
      ..sort((left, right) => right.downloads.compareTo(left.downloads));
  }

  bool isVersionCandidate(ModrinthProject project, ModrinthVersion version) {
    final candidate = candidateManager.find(project.id)?.version;
    return candidate != null &&
        (identical(candidate, version) ||
            (candidate.name == version.name &&
                candidate.gameVersions.join(',') ==
                    version.gameVersions.join(',')));
  }

  void toggleVersionCandidate(
    ModrinthProject project,
    ModrinthVersion version,
  ) {
    _update(() {
      if (isVersionCandidate(project, version)) {
        candidateManager.remove(project.id);
      } else {
        final loaderKey =
            selectedLoader == null ||
                selectedLoader == allResourceLoaderKey
            ? version.loaders
                  .map(resourceLoaderKey)
                  .where((key) => key.isNotEmpty)
                  .firstOrNull
            : selectedLoader;
        candidateManager.add(
          CandidateMod.fromChoice(
            ResourceVersionChoice(
              project: project,
              version: version,
              loader: loaderKey,
            ),
          ),
        );
      }
    });
  }

  void selectDefaultResourceVersion(ModrinthProject project) {
    final projectLoaders = projectLoaderKeys(project);
    final allGameVersions = projectGameVersions(
      project,
      projectLoaders: projectLoaders,
    );
    final groups = resourceVersionGroups(allGameVersions);
    selectedLoader = allResourceLoaderKey;
    selectedGameFamily = groups.keys.firstOrNull;
    expandedGameVersion = null;
  }

}
