// Modrinth and Mojang version-manifest requests.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'models.dart';

int _compareApiVersionNumbers(String left, String right) {
  final leftList = RegExp(r'\d+|[A-Za-z]+')
      .allMatches(left)
      .map((match) => match[0]!)
      .toList();
  final rightList = RegExp(r'\d+|[A-Za-z]+')
      .allMatches(right)
      .map((match) => match[0]!)
      .toList();

  for (
    var index = 0;
    index < math.max(leftList.length, rightList.length);
    index++
  ) {
    if (index >= leftList.length) return -1;
    if (index >= rightList.length) return 1;

    final leftPart = leftList[index];
    final rightPart = rightList[index];
    final leftNumber = int.tryParse(leftPart);
    final rightNumber = int.tryParse(rightPart);
    final comparison = leftNumber != null && rightNumber != null
        ? leftNumber.compareTo(rightNumber)
        : leftPart.compareTo(rightPart);
    if (comparison != 0) return comparison;
  }
  return 0;
}

class MinecraftCatalogService {
  const MinecraftCatalogService();

  static const _apiHost = 'bmclapi2.bangbang93.com';

  Future<List<MinecraftCatalogVersion>> fetchMinecraftVersions() async {
    final json = await _getJson(
      Uri.https(_apiHost, '/mc/game/version_manifest.json'),
    );
    if (json is! Map<String, dynamic> || json['versions'] is! List) {
      throw const FormatException('版本清单缺少 versions 列表。');
    }
    final versions = <MinecraftCatalogVersion>[];
    for (final row in (json['versions'] as List).whereType<Map>()) {
      final id = row['id'];
      final type = row['type'];
      if (id is! String || type is! String) continue;
      versions.add(
        MinecraftCatalogVersion(
          id: id,
          type: type,
          releaseTime: row['releaseTime'] is String
              ? row['releaseTime'] as String
              : null,
        ),
      );
    }
    if (versions.isEmpty) {
      throw const FormatException('版本清单中没有有效的 Minecraft 版本。');
    }
    return versions;
  }

  Future<List<String>> fetchLoaderVersions(
    String loader,
    String minecraftVersion,
  ) async {
    final encodedVersion = Uri.encodeComponent(minecraftVersion);
    final uri = switch (loader) {
      'forge' => Uri.https(_apiHost, '/forge/minecraft/$encodedVersion'),
      'neoforge' => Uri.https(_apiHost, '/neoforge/list/$encodedVersion'),
      'fabric' => Uri.https(
        _apiHost,
        '/fabric-meta/v2/versions/loader/$encodedVersion',
      ),
      'optifine' => Uri.https(_apiHost, '/optifine/$encodedVersion'),
      _ => throw ArgumentError.value(loader, 'loader', '未知的模组加载器'),
    };
    final json = await _getJson(uri);
    if (json is! List) {
      throw const FormatException('加载器版本响应不是列表。');
    }
    final versionList = <({String version, bool stable})>[];
    for (final row in json.whereType<Map>()) {
      String? version;
      var stable = false;
      switch (loader) {
        case 'forge':
        case 'neoforge':
          version = row['version'] is String ? row['version'] as String : null;
        case 'fabric':
          final loaderInfo = row['loader'];
          if (loaderInfo is Map) {
            version = loaderInfo['version'] is String
                ? loaderInfo['version'] as String
                : null;
            stable = loaderInfo['stable'] == true;
          }
        case 'optifine':
          final type = row['type'];
          final patch = row['patch'];
          if (type is String && patch is String) {
            version = '$type-$patch';
          } else if (type is String) {
            version = type;
          }
      }
      if (version != null && version.isNotEmpty) {
        versionList.add((version: version, stable: stable));
      }
    }
    versionList.sort((left, right) {
      if (loader == 'fabric' && left.stable != right.stable) {
        return left.stable ? -1 : 1;
      }
      return _compareApiVersionNumbers(right.version, left.version);
    });
    return versionList.map((entry) => entry.version).toSet().toList();
  }

  Future<dynamic> _getJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'BlockLauncher/26.1alpha1.1 (Minecraft version catalog)';
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}: $body', uri: uri);
      }
      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }
}

class ModrinthService {
  static Future<ModrinthFile> fetchFabricApiFile(
    String minecraftVersion, {
    DownloadCancellationToken? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'BlockLauncher/26.1alpha1.1 (Fabric API installer)';
    void abort() => client.close(force: true);
    cancellation?.addListener(abort);
    try {
      final response = await _getJson(
        client,
        Uri.https('api.modrinth.com', '/v2/project/P7dR8mSH/version', {
          'game_versions': jsonEncode([minecraftVersion]),
          'loaders': jsonEncode(['fabric']),
          'limit': '20',
        }),
      );
      cancellation?.throwIfCancelled();
      if (response is! List || response.isEmpty) {
        throw FormatException(
          'Minecraft $minecraftVersion 没有可用的 Fabric API 版本。',
        );
      }
      for (final row in response.whereType<Map<String, dynamic>>()) {
        final rawFiles = row['files'];
        if (rawFiles is! List) continue;
        final files = rawFiles
            .whereType<Map<String, dynamic>>()
            .map((file) {
              final filename = file['filename'];
              final url = file['url'];
              if (filename is! String || url is! String) return null;
              return (
                file: ModrinthFile(filename: filename, url: url),
                primary: file['primary'] == true,
              );
            })
            .whereType<({ModrinthFile file, bool primary})>()
            .toList();
        if (files.isEmpty) continue;
        return files
            .firstWhere((file) => file.primary, orElse: () => files.first)
            .file;
      }
      throw const FormatException('Fabric API 版本没有可下载的文件。');
    } catch (_) {
      if (cancellation?.isCancelled ?? false) {
        throw const DownloadCancelledException();
      }
      rethrow;
    } finally {
      cancellation?.removeListener(abort);
      client.close(force: true);
    }
  }

  static Future<String> downloadFile(
    ModrinthFile file,
    Directory directory, {
    DownloadCancellationToken? cancellation,
    void Function(int received, int total)? onProgress,
  }) async {
    cancellation?.throwIfCancelled();
    final uri = Uri.tryParse(file.url);
    if (uri == null ||
        uri.scheme != 'https' ||
        !isTrustedResourceHost(uri) ||
        file.filename.isEmpty ||
        file.filename.contains('/') ||
        file.filename.contains('\\') ||
        file.filename == '.' ||
        file.filename == '..') {
      throw const FormatException('Modrinth 返回了无效的下载地址或文件名。');
    }
    await directory.create(recursive: true);
    final destination = File(
      '${directory.path}${Platform.pathSeparator}${file.filename}',
    );
    if (await destination.exists()) {
      throw FileSystemException('文件已存在。', destination.path);
    }
    final temporary = File(
      '${destination.path}.part-${DateTime.now().microsecondsSinceEpoch}',
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..userAgent = 'BlockLauncher/26.1alpha1.1 (Fabric API installer)';
    void abort() => client.close(force: true);
    cancellation?.addListener(abort);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 30));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      cancellation?.throwIfCancelled();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decoder.bind(response).join();
        throw HttpException('HTTP ${response.statusCode}: $body', uri: uri);
      }
      final totalBytes = response.contentLength > 0
          ? response.contentLength
          : 0;
      onProgress?.call(0, totalBytes);
      final sink = temporary.openWrite();
      var receivedBytes = 0;
      try {
        await for (final chunk in response.timeout(
          const Duration(seconds: 30),
        )) {
          cancellation?.throwIfCancelled();
          sink.add(chunk);
          receivedBytes += chunk.length;
          onProgress?.call(receivedBytes, totalBytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      cancellation?.throwIfCancelled();
      await temporary.rename(destination.path);
      onProgress?.call(totalBytes, totalBytes);
      return destination.path;
    } catch (_) {
      if (cancellation?.isCancelled ?? false) {
        throw const DownloadCancelledException();
      }
      rethrow;
    } finally {
      cancellation?.removeListener(abort);
      client.close(force: true);
      if (await temporary.exists()) await temporary.delete();
    }
  }

  static Future<ModrinthSearchPage> search({
    required String query,
    required DownloadCategory category,
    required int offset,
    int limit = 20,
    bool includeVersions = true,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'BlockLauncher/26.1alpha1.1 (resource browser)';
    try {
      final searchUri = Uri.https('api.modrinth.com', '/v2/search', {
        'query': query,
        'facets': jsonEncode([
          ['project_type:${category.modrinthProjectType}'],
        ]),
        'limit': '$limit',
        'offset': '$offset',
        'index': query.trim().isEmpty ? 'downloads' : 'relevance',
      });
      final searchJson = await _getJson(client, searchUri);
      if (searchJson is! Map<String, dynamic> || searchJson['hits'] is! List) {
        throw const FormatException('搜索响应缺少 hits 列表。');
      }
      final totalHits = searchJson['total_hits'];
      if (totalHits is! int || totalHits < 0) {
        throw const FormatException('搜索响应缺少有效的 total_hits。');
      }
      final projectRows = (searchJson['hits'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      final projects = await Future.wait(
        projectRows.map((project) async {
          final id = project['project_id'] ?? project['id'];
          final title = project['title'];
          if (id is! String || title is! String) {
            throw const FormatException('项目缺少 ID 或标题。');
          }
          final versions = includeVersions
              ? await _fetchProjectVersions(client, id)
              : const <ModrinthVersion>[];
          final icon = project['icon_url'];
          final description = project['description'];
          final categories = project['categories'];
          return ModrinthProject(
            id: id,
            title: title,
            description: description is String ? description : '',
            category: category,
            downloads: project['downloads'] is int
                ? project['downloads'] as int
                : 0,
            followers: project['followers'] is int
                ? project['followers'] as int
                : 0,
            tags: categories is List
                ? categories.whereType<String>().toList()
                : const [],
            iconUrl: icon is String && icon.isNotEmpty ? icon : null,
            versions: versions,
          );
        }),
      );
      return ModrinthSearchPage(projects: projects, totalHits: totalHits);
    } finally {
      client.close(force: true);
    }
  }

  /// 根据 Modrinth 项目 ID 获取单个项目详情和版本。
  static Future<ModrinthProject> fetchProjectById(
    String id, {
    required DownloadCategory category,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'BlockLauncher/26.1alpha1.1 (resource browser)';
    try {
      final projectUri = Uri.https('api.modrinth.com', '/v2/project/$id');
      final project = await _getJson(client, projectUri);
      if (project is! Map<String, dynamic>) {
        throw const FormatException('项目详情响应格式无效。');
      }
      final title = project['title'];
      if (title is! String || title.isEmpty) {
        throw const FormatException('项目详情缺少标题。');
      }
      final versions = await _fetchProjectVersions(client, id);
      final icon = project['icon_url'];
      final description = project['description'];
      final categories = project['categories'];
      return ModrinthProject(
        id: id,
        title: title,
        description: description is String ? description : '',
        category: category,
        downloads: project['downloads'] is int
            ? project['downloads'] as int
            : 0,
        followers: project['followers'] is int
            ? project['followers'] as int
            : 0,
        tags: categories is List
            ? categories.whereType<String>().toList()
            : const [],
        iconUrl: icon is String && icon.isNotEmpty ? icon : null,
        versions: versions,
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<ModrinthVersion>> fetchVersions(String id) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'BlockLauncher/26.1alpha1.1 (resource browser)';
    try {
      return await _fetchProjectVersions(client, id);
    } finally {
      client.close(force: true);
    }
  }

  /// Loads every version page instead of only the first 100 entries.
  ///
  /// Modrinth's project version endpoint is paginated. Popular projects can
  /// have thousands of files, so reading one page leaves most historical
  /// versions invisible in the version picker.
  static Future<List<ModrinthVersion>> _fetchProjectVersions(
    HttpClient client,
    String projectId,
  ) async {
    const pageSize = 100;
    // Modrinth's version endpoint has no total-count field. Keep requesting
    // pages until a short/empty page is returned; the high guard only prevents
    // an endless loop if an upstream proxy ignores the offset parameter.
    const maxPages = 1000;
    final versions = <ModrinthVersion>[];
    final seen = <String>{};

    for (var page = 0; page < maxPages; page++) {
      final offset = page * pageSize;
      dynamic versionJson;
      Object? pageError;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          versionJson = await _getJson(
            client,
            Uri.https('api.modrinth.com', '/v2/project/$projectId/version', {
              'limit': '$pageSize',
              'offset': '$offset',
            }),
          );
          pageError = null;
          break;
        } on Exception catch (error) {
          pageError = error;
          if (attempt < 2) {
            await Future<void>.delayed(
              Duration(milliseconds: 250 * (attempt + 1)),
            );
          }
        }
      }
      if (pageError != null) {
        // Keep earlier pages when the network drops mid-pagination. A first
        // page failure is still surfaced so callers can fall back.
        if (page == 0) throw pageError;
        break;
      }
      if (versionJson is! List) {
        throw const FormatException('项目版本响应不是列表。');
      }
      final rows = versionJson.whereType<Map<String, dynamic>>().toList();
      if (rows.isEmpty) break;

      var added = 0;
      for (final row in rows) {
        final versionId = row['id'];
        final fileNames = (row['files'] is List ? row['files'] as List : [])
            .whereType<Map<String, dynamic>>()
            .map((file) => file['filename'])
            .whereType<String>()
            .join(',');
        final key = versionId is String && versionId.isNotEmpty
            ? versionId
            : '${row['name']}|$fileNames';
        if (!seen.add(key)) continue;
        final version = _modrinthVersionFromRow(row);
        if (version == null) continue;
        versions.add(version);
        added++;
      }
      if (rows.length < pageSize || added == 0) break;
    }
    return versions;
  }

  static ModrinthVersion? _modrinthVersionFromRow(Map<String, dynamic> row) {
    final files = (row['files'] is List ? row['files'] as List : [])
        .whereType<Map<String, dynamic>>()
        .map((file) {
          final filename = file['filename'];
          final url = file['url'];
          if (filename is! String || url is! String) return null;
          return ModrinthFile(filename: filename, url: url);
        })
        .whereType<ModrinthFile>()
        .toList();
    final rawGameVersions = row['game_versions'] is List
        ? (row['game_versions'] as List).whereType<String>().toList()
        : <String>[];
    final hasSnapshot = rawGameVersions.any(apiIsSnapshotVersion);
    var gameVersions = apiNormalizeGameVersions(rawGameVersions);
    if (gameVersions.isEmpty && !hasSnapshot) {
      final hint =
          '${row['name'] ?? ''} '
          '${files.map((file) => file.filename).join(' ')}';
      gameVersions = apiNormalizeGameVersions(
        apiInferMinecraftVersions(hint),
      );
    }
    return ModrinthVersion(
      name: row['name'] is String ? row['name'] as String : '',
      versionType: row['version_type'] is String
          ? row['version_type'] as String
          : 'release',
      downloads: row['downloads'] is int ? row['downloads'] as int : 0,
      gameVersions: gameVersions,
      loaders: row['loaders'] is List
          ? (row['loaders'] as List).whereType<String>().toList()
          : const [],
      files: files,
      versionId: row['id'] is String && (row['id'] as String).isNotEmpty
          ? row['id'] as String
          : null,
    );
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
