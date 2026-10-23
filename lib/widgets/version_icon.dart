import 'dart:io';

import 'package:flutter/material.dart';

import '../core/path_utils.dart';
import '../services/installer/version_models.dart';

/// Loader-specific version icon shipped with the launcher.
///
/// A user-provided `<version>/BGCL/logo.png` always wins; otherwise the
/// bundled PNG of the loader is used. The widget keeps a fixed 40x40 size with
/// an 8px rounded clip so all clients line up in lists.
class VersionIcon extends StatelessWidget {
  VersionIcon({
    super.key,
    required LoaderTaggedVersion version,
    this.size = defaultSize,
    double? radius,
  }) : loaderType = version.loaderType,
       customLogoPath = customLogoPathFor(version.versionDirectoryPath),
       radius = radius ?? size * 0.2;

  const VersionIcon.forLoader({
    super.key,
    required this.loaderType,
    this.customLogoPath,
    this.size = defaultSize,
    this.radius = 8,
  });

  /// Default artwork size and corner radius of the list tiles.
  static const double defaultSize = 40;
  static const double defaultRadius = 8;

  /// `<version>/BGCL/logo.png` — the custom client icon.
  static String customLogoPathFor(String versionDirectory) {
    return joinPath(joinPath(versionDirectory, 'BGCL'), 'logo.png');
  }

  final String? loaderType;

  /// Absolute path of the custom icon, checked before the bundled artwork.
  final String? customLogoPath;

  /// Rendered size; the detail header uses a larger square than the lists.
  final double size;
  final double radius;

  /// Maps a loader tag (`Fabric`, `Forge`, `NeoForge`, ...) to its asset.
  static String assetFor(String? loaderType) {
    return switch (resourceLoaderKey(loaderType ?? '')) {
      'fabric' => 'assets/icons/fabric.png',
      'forge' => 'assets/icons/forge.png',
      'neoforge' => 'assets/icons/neoforge.png',
      _ => 'assets/icons/vanilla.png',
    };
  }

  /// Vanilla and unknown loaders use the grass block; modded loaders use the
  /// extension symbol so a missing asset is still recognisable.
  IconData get _fallbackIcon =>
      resourceLoaderKey(loaderType ?? '').isEmpty
      ? Icons.grass
      : Icons.extension;

  Widget _bundledIcon() {
    return Image.asset(
      assetFor(loaderType),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Icon(_fallbackIcon, size: 24),
    );
  }

  /// Returns the custom logo file only when it really exists on disk.
  File? _customLogo() {
    final path = customLogoPath;
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      return file.existsSync() ? file : null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom = _customLogo();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: custom == null
            ? _bundledIcon()
            : Image.file(
                custom,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _bundledIcon(),
              ),
      ),
    );
  }
}

