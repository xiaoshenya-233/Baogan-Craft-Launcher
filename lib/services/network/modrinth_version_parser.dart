// Isolate-only parsing for Modrinth project versions.
//
// Large projects (JEI 1.21.1 has hundreds of files) must never be decoded and
// mapped on the UI isolate. This library is intentionally stateless so it can
// run through `Isolate.run` with only the raw response bytes.

import 'dart:convert';
import 'dart:typed_data';

import 'models.dart';

/// Decodes every raw page and returns the complete, de-duplicated list.
///
/// One call processes all pages, so fetching a large project does not spawn a
/// separate isolate for every network page.
List<ModrinthVersion> parseModrinthVersionPages(List<Uint8List> pages) {
  final versions = <ModrinthVersion>[];
  final seen = <String>{};
  for (final bytes in pages) {
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    if (decoded is! List) {
      throw const FormatException('项目版本响应不是列表。');
    }
    for (final row in decoded.whereType<Map<String, dynamic>>()) {
      final version = _versionFromRow(row);
      if (version == null) continue;
      final key =
          version.versionId ??
          '${version.name}|'
              '${version.files.map((file) => file.filename).join(',')}';
      if (seen.add(key)) versions.add(version);
    }
  }
  return versions;
}

/// Decodes one Modrinth version page and maps every row to [ModrinthVersion].
///
/// Called from a background isolate; the returned model list is sendable.
List<ModrinthVersion> parseModrinthVersionPage(Uint8List bytes) =>
    parseModrinthVersionPages(<Uint8List>[bytes]);

ModrinthVersion? _versionFromRow(Map<String, dynamic> row) {
  final files = (row['files'] is List ? row['files'] as List : [])
      .whereType<Map<String, dynamic>>()
      .map((file) {
        final filename = file['filename'];
        final url = file['url'];
        if (filename is! String || url is! String) return null;
        return ModrinthFile(filename: filename, url: mcimMirrorUrl(url));
      })
      .whereType<ModrinthFile>()
      .toList(growable: false);
  final rawGameVersions = row['game_versions'] is List
      ? (row['game_versions'] as List).whereType<String>().toList()
      : <String>[];
  final hasSnapshot = rawGameVersions.any(apiIsSnapshotVersion);
  var gameVersions = apiNormalizeGameVersions(rawGameVersions);
  if (gameVersions.isEmpty && !hasSnapshot) {
    final hint =
        '${row['name'] ?? ''} '
        '${files.map((file) => file.filename).join(' ')}';
    gameVersions = apiNormalizeGameVersions(apiInferMinecraftVersions(hint));
  }
  return ModrinthVersion(
    name: row['name'] is String ? row['name'] as String : '',
    versionType: row['version_type'] is String
        ? row['version_type'] as String
        : 'release',
    downloads: row['downloads'] is int ? row['downloads'] as int : 0,
    gameVersions: gameVersions,
    loaders: row['loaders'] is List
        ? (row['loaders'] as List).whereType<String>().toList(growable: false)
        : const [],
    files: files,
    versionId: row['id'] is String && (row['id'] as String).isNotEmpty
        ? row['id'] as String
        : null,
  );
}
