// CurseForge requests sent through the self-hosted Cloudflare Worker proxy.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Which CurseForge API endpoint the launcher talks to.
enum CurseForgeEndpoint { proxy, mcim, official }

class CurseForgeService {
  static const int _minecraftGameId = 432;

  /// Endpoint used by every subsequent request (MCIM by default).
  static CurseForgeEndpoint endpoint = CurseForgeEndpoint.mcim;

  static String get _apiHost => switch (endpoint) {
    CurseForgeEndpoint.official => 'api.curseforge.com',
    CurseForgeEndpoint.mcim => 'mod.mcimirror.top',
    CurseForgeEndpoint.proxy => 'cf-api-proxy.xiaoshenya233.workers.dev',
  };

  /// MCIM mounts CurseForge under `/curseforge`, the others expose `/v1`.
  static String get _apiPrefix =>
      endpoint == CurseForgeEndpoint.mcim ? '/curseforge/v1' : '/v1';

  static int classIdFor(DownloadCategory category) => switch (category) {
    DownloadCategory.mods => 6,
    DownloadCategory.shaders => 6552,
    DownloadCategory.resourcePacks => 12,
    DownloadCategory.dataPacks => 17,
  };

  static Future<ModrinthSearchPage> search({
    required String query,
    required DownloadCategory category,
    required int offset,
    int limit = 20,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'BlockLauncher/26.1alpha2.1 (resource browser)';
    try {
      final parameters = <String, String>{
        'gameId': '$_minecraftGameId',
        'classId': '${classIdFor(category)}',
        'index': '$offset',
        'pageSize': '$limit',
        'sortField': '6',
        'sortOrder': 'desc',
      };
      final trimmedQuery = query.trim();
      if (trimmedQuery.isNotEmpty) {
        parameters['searchFilter'] = trimmedQuery;
      }
      final json = await _getJson(
        client,
        Uri.https(_apiHost, '$_apiPrefix/mods/search', parameters),
      );
      if (json is! Map<String, dynamic> || json['data'] is! List) {
        throw const FormatException('CurseForge 搜索响应缺少 data 列表。');
      }
      final pagination = json['pagination'];
      final totalCount = pagination is Map<String, dynamic>
          ? pagination['totalCount']
          : null;
      final projects = (json['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((row) => _projectFromMod(row, category))
          .toList();
      return ModrinthSearchPage(
        projects: projects,
        totalHits: totalCount is int && totalCount >= 0
            ? totalCount
            : projects.length,
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<ModrinthProject> fetchProjectById(
    String id, {
    required DownloadCategory category,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'BlockLauncher/26.1alpha2.1 (resource browser)';
    try {
      final json = await _getJson(
        client,
        Uri.https(_apiHost, '$_apiPrefix/mods/$id'),
      ).timeout(const Duration(seconds: 10));
      if (json is! Map<String, dynamic> ||
          json['data'] is! Map<String, dynamic>) {
        throw const FormatException('CurseForge 项目详情响应格式无效。');
      }
      return _projectFromMod(json['data'] as Map<String, dynamic>, category);
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<ModrinthVersion>> fetchVersionPage(
    String id, {
    int offset = 0,
    int limit = resourceVersionPageSize,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'BlockLauncher/26.1alpha2.1 (resource browser)';
    try {
      final json = await _getJson(
        client,
        Uri.https(_apiHost, '$_apiPrefix/mods/$id/files', {
          'index': '$offset',
          'pageSize': '$limit',
        }),
      ).timeout(const Duration(seconds: 10));
      if (json is! Map<String, dynamic> || json['data'] is! List) {
        throw const FormatException('CurseForge 文件列表响应格式无效。');
      }
      final versions = (json['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(_versionFromFile)
          .whereType<ModrinthVersion>()
          .toList(growable: false);
      if (versions.length <= limit) return versions;
      final start = offset < 0
          ? 0
          : (offset > versions.length ? versions.length : offset);
      if (start >= versions.length) return const <ModrinthVersion>[];
      final next = start + limit;
      final end = next > versions.length ? versions.length : next;
      return versions.sublist(start, end);
    } finally {
      client.close(force: true);
    }
  }

  /// Fetches all file metadata for card counts. File rows are still loaded in
  /// 20-entry pages by [fetchVersionPage].
  static Future<List<ModrinthVersion>> fetchVersionIndex(String id) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'BlockLauncher/26.1alpha2.1 (resource browser)';
    try {
      const pageSize = 50;
      const maxPages = 1000;
      final versions = <ModrinthVersion>[];
      final seen = <String>{};
      var offset = 0;
      for (var page = 0; page < maxPages; page++) {
        final json = await _getJson(
          client,
          Uri.https(_apiHost, '$_apiPrefix/mods/$id/files', {
            'index': '$offset',
            'pageSize': '$pageSize',
          }),
        ).timeout(const Duration(seconds: 10));
        if (json is! Map<String, dynamic> || json['data'] is! List) {
          throw const FormatException('CurseForge 文件列表响应格式无效。');
        }
        final rows = (json['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        if (rows.isEmpty) break;
        for (final row in rows) {
          final version = _versionFromFile(row);
          if (version == null) continue;
          final key =
              version.versionId ??
              '${version.name}|'
                  '${version.files.map((file) => file.filename).join(',')}';
          if (seen.add(key)) versions.add(version);
        }
        offset += rows.length;
        if (rows.length < pageSize) break;
      }
      return versions;
    } finally {
      client.close(force: true);
    }
  }

  static ModrinthProject _projectFromMod(
    Map<String, dynamic> row,
    DownloadCategory category,
  ) {
    final rawId = row['id'];
    final id = rawId is int
        ? '$rawId'
        : rawId is String
        ? rawId
        : '';
    final name = row['name'];
    final summary = row['summary'];
    final logo = row['logo'];
    String? iconUrl;
    if (logo is Map<String, dynamic>) {
      final thumbnail = logo['thumbnailUrl'];
      final full = logo['url'];
      if (thumbnail is String && thumbnail.isNotEmpty) {
        iconUrl = mcimMirrorUrl(thumbnail);
      } else if (full is String && full.isNotEmpty) {
        iconUrl = mcimMirrorUrl(full);
      }
    }
    final categories = row['categories'];
    final tags = categories is List
        ? categories
              .whereType<Map<String, dynamic>>()
              .map((entry) => entry['name'])
              .whereType<String>()
              .where((entry) => entry.isNotEmpty)
              .take(5)
              .toList()
        : const <String>[];
    final downloads = row['downloadCount'];
    final thumbsUp = row['thumbsUpCount'];
    final supportedGameVersions = <String>{};
    final supportedLoaders = <String>{};
    final indexes = row['latestFilesIndexes'];
    if (indexes is List) {
      for (final entry in indexes.whereType<Map<String, dynamic>>()) {
        final gameVersion = entry['gameVersion'];
        if (gameVersion is String && gameVersion.isNotEmpty) {
          final normalized = apiNormalizeGameVersions(<String>[gameVersion]);
          supportedGameVersions.addAll(normalized);
        }
        final loader = _loaderFromTypeId(entry['modLoader']);
        if (loader != null) supportedLoaders.add(loader);
      }
    }
    return ModrinthProject(
      id: id,
      title: name is String && name.isNotEmpty ? name : '未命名资源',
      description: summary is String ? summary : '',
      category: category,
      downloads: downloads is int ? downloads : 0,
      followers: thumbsUp is int ? thumbsUp : 0,
      iconUrl: iconUrl,
      versions: _versionsFromMod(row),
      tags: tags,
      source: ResourceSource.curseForge,
      supportedGameVersions: supportedGameVersions.toList(growable: false),
      supportedLoaders: supportedLoaders.toList(growable: false),
    );
  }

  static List<ModrinthVersion> _versionsFromMod(Map<String, dynamic> mod) {
    final versions = <ModrinthVersion>[];
    final files = mod['latestFiles'];
    if (files is List) {
      for (final row in files.whereType<Map<String, dynamic>>()) {
        final version = _versionFromFile(row);
        if (version != null) versions.add(version);
      }
    }
    if (versions.isNotEmpty) return versions;

    final indexes = mod['latestFilesIndexes'];
    if (indexes is List) {
      for (final row in indexes.whereType<Map<String, dynamic>>()) {
        final fileId = row['fileId'];
        final filename = row['filename'];
        if (fileId is! int || filename is! String || filename.isEmpty) {
          continue;
        }
        final gameVersion = row['gameVersion'];
        final loader = _loaderFromTypeId(row['modLoader']);
        final isSnapshot =
            gameVersion is String && apiIsSnapshotVersion(gameVersion);
        var gameVersions = gameVersion is String
            ? apiNormalizeGameVersions([gameVersion])
            : <String>[];
        if (gameVersions.isEmpty && !isSnapshot) {
          gameVersions = apiNormalizeGameVersions(
            apiInferMinecraftVersions(filename),
          );
        }
        versions.add(
          ModrinthVersion(
            name: filename,
            versionType: _releaseTypeName(row['releaseType']),
            downloads: 0,
            gameVersions: gameVersions,
            loaders: loader == null ? const [] : [loader],
            files: [
              ModrinthFile(
                filename: filename,
                url: _cdnDownloadUrl(fileId, filename),
              ),
            ],
            versionId: '$fileId',
          ),
        );
      }
    }
    return versions;
  }

  static ModrinthVersion? _versionFromFile(Map<String, dynamic> row) {
    final filename = row['fileName'] ?? row['displayName'];
    if (filename is! String || filename.isEmpty) return null;
    final remoteUrl = row['downloadUrl'];
    final fileId = row['id'];
    final url = remoteUrl is String && remoteUrl.isNotEmpty
        ? mcimMirrorUrl(remoteUrl)
        : fileId is int
        ? _cdnDownloadUrl(fileId, filename)
        : null;
    if (url == null) return null;
    final rawGameVersions = row['gameVersions'];
    final rawValues = rawGameVersions is List
        ? rawGameVersions.whereType<String>().toList()
        : const <String>[];
    final hasRawSnapshot = rawValues.any(apiIsSnapshotVersion);
    final gameVersions = <String>[];
    final loaders = <String>[];
    for (final value in rawValues) {
      final loader = _normalizeLoader(value);
      if (loader != null) {
        if (!loaders.contains(loader)) loaders.add(loader);
        continue;
      }
      for (final base in apiNormalizeGameVersions([value])) {
        if (!gameVersions.contains(base)) gameVersions.add(base);
      }
    }
    final displayName = row['displayName'];
    if (gameVersions.isEmpty && !hasRawSnapshot) {
      final sortable = row['sortableGameVersions'];
      if (sortable is List) {
        for (final entry in sortable.whereType<Map<String, dynamic>>()) {
          for (final value in [
            entry['gameVersionName'],
            entry['gameVersion'],
          ]) {
            if (value is! String) continue;
            for (final base in apiNormalizeGameVersions([value])) {
              if (!gameVersions.contains(base)) gameVersions.add(base);
            }
          }
        }
      }
    }
    if (gameVersions.isEmpty && !hasRawSnapshot) {
      final hint = '$filename ${displayName is String ? displayName : ''}';
      gameVersions.addAll(
        apiNormalizeGameVersions(apiInferMinecraftVersions(hint)),
      );
    }
    final downloads = row['downloadCount'];
    return ModrinthVersion(
      name: displayName is String && displayName.isNotEmpty
          ? displayName
          : filename,
      versionType: _releaseTypeName(row['releaseType']),
      downloads: downloads is int ? downloads : 0,
      gameVersions: gameVersions,
      loaders: loaders,
      files: [ModrinthFile(filename: filename, url: url)],
      versionId: fileId is int ? '$fileId' : null,
    );
  }

  static String _releaseTypeName(Object? releaseType) => switch (releaseType) {
    2 => 'beta',
    3 => 'alpha',
    _ => 'release',
  };

  static String? _loaderFromTypeId(Object? typeId) {
    if (typeId is! int) return null;
    return switch (typeId) {
      1 => 'forge',
      4 => 'fabric',
      5 => 'quilt',
      6 => 'neoforge',
      _ => null,
    };
  }

  static String? _normalizeLoader(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('neoforge')) return 'neoforge';
    if (normalized.contains('fabric')) return 'fabric';
    if (normalized.contains('quilt')) return 'quilt';
    if (normalized.contains('forge')) return 'forge';
    return null;
  }

  static String _cdnDownloadUrl(int fileId, String filename) {
    return 'https://$mcimApiHost/files/${fileId ~/ 1000}/'
        '${fileId % 1000}/${Uri.encodeComponent(filename)}';
  }

  static Future<dynamic> _getJson(HttpClient client, Uri uri) async {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}: $body', uri: uri);
    }
    return jsonDecode(body);
  }
}
