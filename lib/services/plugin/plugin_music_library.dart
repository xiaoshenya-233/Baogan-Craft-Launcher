import 'dart:io';

import 'package:path/path.dart' as p;

import 'plugin_file_sandbox.dart';

/// One local audio track discovered inside a plugin folder.
class PluginMusicTrack {
  const PluginMusicTrack({
    required this.fileName,
    required this.relativePath,
    required this.absolutePath,
    required this.title,
    required this.artist,
  });

  final String fileName;
  final String relativePath;
  final String absolutePath;
  final String title;
  final String artist;

  String get displayTitle => artist.isEmpty ? title : '正在播放: $title - $artist';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'file': relativePath,
    'title': title,
    'artist': artist,
  };
}

/// Scans plugin folders for audio files and parses `Artist - Title` names.
///
/// Only the plugin directory is readable; traversal is rejected by
/// [PluginFileSandbox].
class PluginMusicLibrary {
  const PluginMusicLibrary._();

  static const Set<String> audioExtensions = <String>{
    '.mp3',
    '.flac',
    '.wav',
    '.m4a',
    '.aac',
    '.ogg',
    '.opus',
    '.wma',
  };

  /// Matches ASCII and CJK dashes with optional surrounding spaces.
  static final RegExp _separator = RegExp(r'\s*[-–—－−]\s*');

  /// `"周杰伦 - 稻香.mp3"` → `(title: "稻香", artist: "周杰伦")`.
  static ({String title, String artist}) parseFileName(String fileName) {
    final base = p.basenameWithoutExtension(fileName).trim();
    final match = _separator.firstMatch(base);
    if (match != null && match.start > 0 && match.end < base.length) {
      final artist = base.substring(0, match.start).trim();
      final title = base.substring(match.end).trim();
      if (artist.isNotEmpty && title.isNotEmpty) {
        return (title: title, artist: artist);
      }
    }
    return (title: base, artist: '');
  }

  static Future<List<PluginMusicTrack>> scanDirectory(
    String pluginDirectory,
    String folder,
  ) async {
    final directory = PluginFileSandbox.resolveDirectoryInRoot(
      pluginDirectory,
      folder,
    );
    if (directory == null) {
      throw PluginSandboxException('目录不在插件目录内或不安全：$folder');
    }
    if (!await directory.exists()) return const <PluginMusicTrack>[];

    final prefix = folder.trim().replaceAll('\\', '/');
    final tracks = <PluginMusicTrack>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!audioExtensions.contains(p.extension(name).toLowerCase())) {
        continue;
      }
      final parsed = parseFileName(name);
      if (parsed.title.isEmpty) continue;
      tracks.add(
        PluginMusicTrack(
          fileName: name,
          relativePath: prefix.isEmpty ? name : '$prefix/$name',
          absolutePath: entity.path,
          title: parsed.title,
          artist: parsed.artist,
        ),
      );
    }
    tracks.sort(
      (left, right) =>
          left.fileName.toLowerCase().compareTo(right.fileName.toLowerCase()),
    );
    return tracks;
  }
}
