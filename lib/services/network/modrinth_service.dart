// Modrinth and Mojang version-manifest requests.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'models.dart';
import 'modrinth_version_parser.dart';

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
      ..userAgent = 'BlockLauncher/26.1alpha2.1 (Minecraft version catalog)';
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
  static const String _apiHost = mcimApiHost;
  static const String _apiPrefix = '/modrinth';

  static Uri _apiUri(String path, [Map<String, String>? query]) =>
      Uri.https(_apiHost, '$_apiPrefix$path', query);

  static Future<ModrinthFile> fetchFabricApiFile(
    String minecraftVersion, {
    DownloadCancellationToken? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'BlockLauncher/26.1alpha2.1 (Fabric API installer)';
    void abort() => client.close(force: true);
    cancellation?.addListener(abort);
    try {
      final response = await _getJson(
        client,
        _apiUri('/v2/project/P7dR8mSH/version', {
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
                file: ModrinthFile(filename: filename, url: mcimMirrorUrl(url)),
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
      ..userAgent = 'BlockLauncher/26.1alpha2.1 (Fabric API installer)';
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
      ..userAgent = 'BlockLauncher/26.1alpha2.1 (resource browser)';
    try {
      final searchUri = _apiUri('/v2/search', {
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
              ? await _fetchVersionPageWithClient(
                  client,
                  id,
                  offset: 0,
                  limit: resourceVersionPageSize,
                )
              : const <ModrinthVersion>[];
          final icon = project['icon_url'];
          final description = project['description'];
          final categories = project['categories'];
          final supportedGameVersions = project['versions'] is List
              ? (project['versions'] as List).whereType<String>().toList()
              : const <String>[];
          final supportedLoaders = project['loaders'] is List
              ? (project['loaders'] as List).whereType<String>().toList()
              : const <String>[];
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
            iconUrl: icon is String && icon.isNotEmpty
                ? mcimMirrorUrl(icon)
                : null,
            versions: versions,
            supportedGameVersions: supportedGameVersions,
            supportedLoaders: supportedLoaders,
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
      ..userAgent = 'BlockLauncher/26.1alpha2.1 (resource browser)';
    try {
      final projectUri = _apiUri('/v2/project/$id');
      final project = await _getJson(client, projectUri);
      if (project is! Map<String, dynamic>) {
        throw const FormatException('项目详情响应格式无效。');
      }
      final title = project['title'];
      if (title is! String || title.isEmpty) {
        throw const FormatException('项目详情缺少标题。');
      }
      final versions = await _fetchVersionPageWithClient(
        client,
        id,
        offset: 0,
        limit: resourceVersionPageSize,
      );
      final icon = project['icon_url'];
      final description = project['description'];
      final categories = project['categories'];
      final supportedGameVersions = project['game_versions'] is List
          ? (project['game_versions'] as List).whereType<String>().toList(
              growable: false,
            )
          : const <String>[];
      final supportedLoaders = project['loaders'] is List
          ? (project['loaders'] as List).whereType<String>().toList(
              growable: false,
            )
          : const <String>[];
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
        iconUrl: icon is String && icon.isNotEmpty ? mcimMirrorUrl(icon) : null,
        versions: versions,
        supportedGameVersions: supportedGameVersions,
        supportedLoaders: supportedLoaders,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Fetches the complete version metadata index for counting cards.
  ///
  /// Modrinth defaults to 20 versions when no limit is supplied, so the index
  /// must page until the API returns a short page. This data is only used to
  /// calculate per-version file totals; expanded cards still render at most 20
  /// rows at a time.
  static Future<List<ModrinthVersion>> fetchVersionIndex(String id) async {
    const pageSize = 100;
    const maxPages = 1000;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'BlockLauncher/26.1alpha2.1 (resource browser)';
    try {
      final versions = <ModrinthVersion>[];
      final seen = <String>{};
      var offset = 0;
      for (var page = 0; page < maxPages; page++) {
        final rows = await _fetchVersionPageWithClient(
          client,
          id,
          offset: offset,
          limit: pageSize,
        );
        if (rows.isEmpty) break;
        for (final version in rows) {
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

  /// Fetches exactly one page of versions.
  ///
  /// This is the only version-list path used by the UI. The request timeout is
  /// limited to this one page, never to the complete project history.
  static Future<List<ModrinthVersion>> fetchVersionPage(
    String id, {
    int offset = 0,
    int limit = resourceVersionPageSize,
    List<String>? gameVersions,
    List<String>? loaders,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'BlockLauncher/26.1alpha2.1 (resource browser)';
    try {
      return await _fetchVersionPageWithClient(
        client,
        id,
        offset: offset,
        limit: limit,
        gameVersions: gameVersions,
        loaders: loaders,
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<ModrinthVersion>> _fetchVersionPageWithClient(
    HttpClient client,
    String id, {
    required int offset,
    required int limit,
    List<String>? gameVersions,
    List<String>? loaders,
  }) async {
    final query = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (gameVersions != null && gameVersions.isNotEmpty) {
      query['game_versions'] = jsonEncode(gameVersions);
    }
    if (loaders != null && loaders.isNotEmpty) {
      query['loaders'] = jsonEncode(loaders);
    }
    final bytes = await _getBytes(
      client,
      _apiUri('/v2/project/$id/version', query),
    ).timeout(const Duration(seconds: 10));
    final versions = await Isolate.run(() => parseModrinthVersionPage(bytes));
    if (versions.length <= limit) return versions;
    final start = offset < 0
        ? 0
        : (offset > versions.length ? versions.length : offset);
    if (start >= versions.length) return const <ModrinthVersion>[];
    final next = start + limit;
    final end = next > versions.length ? versions.length : next;
    return versions.sublist(start, end);
  }

  static Future<dynamic> _getJson(HttpClient client, Uri uri) async {
    final bytes = await _getBytes(client, uri);
    return jsonDecode(utf8.decode(bytes, allowMalformed: true));
  }

  /// Collects raw response bytes; UTF-8 decoding and JSON parsing happen in an
  /// isolate so a huge version page never blocks the UI thread.
  static Future<Uint8List> _getBytes(HttpClient client, Uri uri) async {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 15));
    final buffer = BytesBuilder(copy: true);
    await for (final chunk in response.timeout(const Duration(seconds: 20))) {
      buffer.add(chunk);
    }
    final bytes = buffer.takeBytes();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = utf8.decode(bytes, allowMalformed: true);
      throw HttpException('HTTP ${response.statusCode}: $body', uri: uri);
    }
    return bytes;
  }
}
