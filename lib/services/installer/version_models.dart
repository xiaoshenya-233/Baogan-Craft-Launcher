// Version data models, enums and pure value helpers.

import 'dart:io';

import 'package:flutter/material.dart';

export 'version_scanner.dart';

enum VersionKind { modded, vanilla }

/// Minimal contract so UI widgets can pick a loader icon without depending on
/// the concrete version model.
abstract interface class LoaderTaggedVersion {
  String? get loaderType;

  /// Folder that contains this client (`<minecraft>/versions/<name>`).
  String get versionDirectoryPath;
}

String formatDownloadCount(int count) {
  if (count < 1000) return '$count';
  if (count < 10000) {
    final thousands = count ~/ 1000;
    final hundreds = (count % 1000) ~/ 100;
    return '$thousands${hundreds == 0 ? '' : '.$hundreds'}K';
  }
  final tenThousands = count ~/ 10000;
  final thousands = (count % 10000) ~/ 1000;
  final hundreds = (count % 1000) ~/ 100;
  final parts = <int>[
    tenThousands,
    if (thousands > 0 || hundreds > 0) thousands,
    if (hundreds > 0) hundreds,
  ];
  return '${parts.join('.')}K';
}

class LauncherVersion implements LoaderTaggedVersion {
  const LauncherVersion({
    required this.name,
    required this.path,
    required this.kind,
    required this.minecraftPath,
    this.gameDirectory,
    this.minecraftVersion,
    this.versionType,
    this.loaderType,
    this.loaderVersion,
  });

  final String name;
  final String path;
  final VersionKind kind;
  final String minecraftPath;
  final String? gameDirectory;
  final String? minecraftVersion;
  final String? versionType;
  @override
  final String? loaderType;
  final String? loaderVersion;

  @override
  String get versionDirectoryPath => path;
}

class MinecraftVersion implements LoaderTaggedVersion {
  const MinecraftVersion({
    required this.id,
    required this.type,
    required this.directoryPath,
    required this.minecraftPath,
    this.minecraftVersion,
    this.loaderType,
    this.loaderVersion,
  });

  final String id;
  final String? type;
  final String directoryPath;
  final String minecraftPath;
  final String? minecraftVersion;
  @override
  final String? loaderType;
  final String? loaderVersion;

  @override
  String get versionDirectoryPath => directoryPath;
}

/// Returns the last non-empty segment of [path], tolerating both `/` and `\`.
String lastPathSegment(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.split('/').where((part) => part.isNotEmpty).last;
}

/// Resolves a per-client sub-folder such as `mods`, `shaderpacks`,
/// `resourcepacks`, `config` or `saves`. Each client lives directly under
/// `.minecraft/versions/<客户端>` and keeps its own saves, config, mods,
/// shader packs and resource packs there, so launching one never mixes assets
/// with another.
String minecraftVersionSubfolder(String versionDirectoryPath, String folder) =>
    '$versionDirectoryPath${Platform.pathSeparator}$folder';

class VersionIdentity {
  const VersionIdentity({
    this.minecraftVersion,
    this.loaderType,
    this.loaderVersion,
  });

  final String? minecraftVersion;
  final String? loaderType;
  final String? loaderVersion;
}

/// Reads all library names from a merged version config.
const List<String> resourceLoaderKeys = ['fabric', 'forge', 'neoforge'];
const String unknownResourceLoaderKey = 'unknown';
const String allResourceLoaderKey = 'all';

String resourceLoaderKey(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.contains('neoforge')) return 'neoforge';
  if (normalized.contains('fabric')) return 'fabric';
  if (normalized.contains('forge')) return 'forge';
  return '';
}

String resourceLoaderLabel(String key) => switch (key) {
  'fabric' => 'Fabric',
  'forge' => 'Forge',
  'neoforge' => 'NeoForge',
  unknownResourceLoaderKey => '未标注',
  _ => key,
};

bool resourceIsLoaderTag(String tag) {
  final normalized = tag.trim().toLowerCase();
  return resourceLoaderKey(normalized).isNotEmpty ||
      normalized.contains('quilt') ||
      normalized.contains('liteloader') ||
      normalized.contains('optifine');
}

List<String> resourceTagsWithoutLoaders(Iterable<String> tags) {
  return tags
      .where((tag) => tag.trim().isNotEmpty && !resourceIsLoaderTag(tag))
      .toSet()
      .toList();
}

List<String> inferMinecraftVersions(String text) {
  final versions = <String>[];
  final pattern = RegExp(r'(?:^|[^\d.])(\d{1,3}(?:\.\d+){1,2})(?!\d|\.\d)');
  for (final match in pattern.allMatches(text)) {
    final value = match.group(1);
    if (value == null) continue;
    final parts = value.split('.');
    if (parts.length < 2 || parts.length > 3) continue;
    final major = int.tryParse(parts[0]);
    // Minecraft uses 1.x, and the newer calendar versions use 26.x/27.x.
    // Do not mistake Forge/NeoForge versions such as 47.2.0 or 21.1.80 for
    // Minecraft versions when the API omits the game version field.
    final isMinecraft =
        major == 1 || (major != null && major >= 26 && major <= 30);
    if (!isMinecraft || versions.contains(value)) continue;
    versions.add(value);
  }
  return versions;
}

bool resourceIsSnapshotVersion(String value) {
  final normalized = value.trim().toLowerCase();
  // Pure weekly snapshots (for example 24w14a) do not belong to a release
  // family and are filtered from the public version picker.
  return RegExp(r'^\d{2}w\d{2}[a-z]$').hasMatch(normalized);
}

bool _isPrereleaseGameVersion(String value) {
  return RegExp(
    r'(?:[-_.\s](?:pre|rc|snapshot)[-_.\s]?\d*)$',
    caseSensitive: false,
  ).hasMatch(value.trim());
}

/// Extracts the numeric base version from a Minecraft version string.
///
/// This intentionally keeps the patch component:
/// `1.21.1-pre2` -> `1.21.1`, `1.21-rc1` -> `1.21`,
/// `1.21_snapshot` -> `1.21`. Pure weekly snapshots and loader names return
/// `null`.
final RegExp _resourceGameVersionBasePattern = RegExp(r'^(\d+\.\d+(?:\.\d+)?)');

String? resourceBaseGameVersion(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || resourceIsSnapshotVersion(normalized)) {
    return null;
  }
  // Keep the numeric prefix even when CurseForge mixes a loader label into the
  // string (for example "1.21.1-forge"); pure loader names such as "Fabric"
  // have no numeric prefix and are discarded.
  final match = _resourceGameVersionBasePattern.firstMatch(normalized);
  return match?.group(1);
}

/// Normalizes and deduplicates API game-version lists.
///
/// CurseForge can mix loader names and prerelease labels into
/// `gameVersions`; Modrinth can expose release candidates in
/// `game_versions`. Both platforms are reduced to the same release family.
List<String> normalizeResourceGameVersions(Iterable<String> values) {
  final versions = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final base = resourceBaseGameVersion(value);
    if (base != null && seen.add(base)) {
      versions.add(base);
    }
  }
  return versions;
}

String baseGameVersion(String value) {
  return resourceBaseGameVersion(value) ?? value.trim();
}

String resourceVersionFamily(String version) {
  return resourceBaseGameVersion(version) ?? '';
}

int compareGameVersions(String left, String right) {
  final leftParts = left.split('.');
  final rightParts = right.split('.');
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var index = 0; index < length; index++) {
    final leftValue = index < leftParts.length
        ? int.tryParse(leftParts[index])
        : null;
    final rightValue = index < rightParts.length
        ? int.tryParse(rightParts[index])
        : null;
    if (leftValue != null && rightValue != null) {
      final comparison = leftValue.compareTo(rightValue);
      if (comparison != 0) return comparison;
    } else {
      final comparison = (index < leftParts.length ? leftParts[index] : '')
          .toLowerCase()
          .compareTo(
            (index < rightParts.length ? rightParts[index] : '').toLowerCase(),
          );
      if (comparison != 0) return comparison;
    }
  }
  return 0;
}

List<String> resourceVersionFamilies(Iterable<String> versions) {
  final families = versions
      .map(resourceVersionFamily)
      .where((family) => family.isNotEmpty)
      .toSet();
  return families.toList()
    ..sort((left, right) => compareGameVersions(right, left));
}

/// Major release family used by the two-level version picker.
///
/// `1.21`, `1.21.1` and `1.21.2` all map to `1.21`.
String resourceVersionMajorFamily(String version) {
  final base = resourceVersionFamily(version);
  if (base.isEmpty) return '';
  final parts = base.split('.');
  return parts.length >= 2 ? '${parts[0]}.${parts[1]}' : base;
}

/// Groups concrete versions by major release.
///
/// Example: `{'1.21': ['1.21', '1.21.1', '1.21.2']}`.
Map<String, List<String>> resourceVersionGroups(Iterable<String> versions) {
  final grouped = <String, Set<String>>{};
  for (final version in versions) {
    final concrete = resourceVersionFamily(version);
    final major = resourceVersionMajorFamily(version);
    if (concrete.isEmpty || major.isEmpty) continue;
    grouped.putIfAbsent(major, () => <String>{}).add(concrete);
  }

  final majors = grouped.keys.toList()
    ..sort((left, right) => compareGameVersions(right, left));
  return {
    for (final major in majors) major: _sortConcreteVersions(grouped[major]!),
  };
}

List<String> _sortConcreteVersions(Iterable<String> versions) {
  return versions.toSet().toList()..sort((left, right) {
    final baseComparison = compareGameVersions(
      baseGameVersion(right),
      baseGameVersion(left),
    );
    if (baseComparison != 0) return baseComparison;
    final leftPrerelease = _isPrereleaseGameVersion(left) ? 1 : 0;
    final rightPrerelease = _isPrereleaseGameVersion(right) ? 1 : 0;
    return leftPrerelease.compareTo(rightPrerelease);
  });
}

List<String> resourceVersionsInFamily(
  Iterable<String> versions,
  String family,
) {
  if (family.isEmpty) return const [];
  return versions
      .where((version) => resourceVersionFamily(version) == family)
      .toSet()
      .toList()
    ..sort((left, right) {
      final baseComparison = compareGameVersions(
        baseGameVersion(right),
        baseGameVersion(left),
      );
      if (baseComparison != 0) return baseComparison;
      final leftPrerelease = _isPrereleaseGameVersion(left) ? 1 : 0;
      final rightPrerelease = _isPrereleaseGameVersion(right) ? 1 : 0;
      return leftPrerelease.compareTo(rightPrerelease);
    });
}

({Color background, Color border, Color foreground}) resourceTagAppearance(
  String label, {
  required bool dark,
}) {
  final normalized = label.trim().toLowerCase();
  if (normalized.startsWith('neoforge')) {
    return (
      background: dark ? const Color(0xFF9A3A06) : const Color(0xFFB54708),
      border: const Color(0xFFE08A4A),
      foreground: Colors.white,
    );
  }
  if (normalized.startsWith('forge')) {
    return (
      background: dark ? const Color(0xFF3B3B3B) : const Color(0xFF5A5A5A),
      border: dark ? const Color(0xFF666666) : const Color(0xFF444444),
      foreground: Colors.white,
    );
  }
  if (normalized.startsWith('fabric') || normalized.startsWith('quilt')) {
    return dark
        ? (
            background: const Color(0xFF5A4720),
            border: const Color(0xFF8C6D32),
            foreground: Colors.white,
          )
        : (
            background: const Color(0xFFFFE3A8),
            border: const Color(0xFFDDA94D),
            foreground: Colors.black,
          );
  }
  return (
    background: dark ? const Color(0xFF34452D) : const Color(0xFFDDEBD1),
    border: dark ? const Color(0xFF2A3228) : const Color(0xFFD8E0D2),
    foreground: dark ? const Color(0xFFC4E8A0) : const Color(0xFF34452D),
  );
}

String _normalizeResourceSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r"['’]"), '')
      .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), ' ')
      .trim();
}

bool resourceSearchMatchesQuery(
  String query,
  String title,
  String description, {
  double minimumScore = 0.5,
}) {
  final normalized = _normalizeResourceSearchText(query);
  if (normalized.isEmpty) return true;
  final tokens = normalized
      .split(RegExp(r'\s+'))
      .map((token) => token.trim())
      .where((token) => token.length >= 2)
      .toList();
  if (tokens.isEmpty) return true;
  final titleText = _normalizeResourceSearchText(title);
  final descriptionText = _normalizeResourceSearchText(description);
  var score = 0.0;
  for (final token in tokens) {
    if (titleText.contains(token)) {
      score += 1;
    } else if (descriptionText.contains(token)) {
      score += 0.5;
    }
  }
  return score / tokens.length >= minimumScore;
}

bool isValidMinecraftClientName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty || trimmed.length > 64) return false;
  if (trimmed == '.' || trimmed == '..') return false;
  if (trimmed.endsWith('.') || trimmed.endsWith(' ')) return false;
  if (RegExp(r'[<>:"/\\|?*]').hasMatch(trimmed)) return false;
  final base = trimmed.split('.').first.toUpperCase();
  return !RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$').hasMatch(base);
}
