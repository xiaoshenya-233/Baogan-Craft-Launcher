import 'dart:io';

import 'package:flutter/material.dart';

import '../services/launcher/resource_icon_service.dart';

/// Async thumbnail for a mod, resource pack, shader pack or world.
///
/// The icon is extracted off the UI isolate and cached by
/// [ResourceIconService]; until it resolves (or when the resource has no
/// icon) the themed [fallbackIcon] is shown.
class ResourceIcon extends StatefulWidget {
  const ResourceIcon({
    super.key,
    required this.filePath,
    required this.type,
    required this.fallbackIcon,
    this.size = 24,
    this.radius,
    this.color,
  });

  final String filePath;
  final ResourceType type;
  final IconData fallbackIcon;
  final double size;

  /// Corner radius; defaults to 15% of [size].
  final double? radius;
  final Color? color;

  @override
  State<ResourceIcon> createState() => _ResourceIconState();
}

class _ResourceIconState extends State<ResourceIcon> {
  late Future<String?> _icon = _load();

  Future<String?> _load() {
    return ResourceIconService.extractResourceIcon(
      widget.filePath,
      widget.type,
    );
  }

  @override
  void didUpdateWidget(ResourceIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.type != widget.type) {
      _icon = _load();
    }
  }

  Widget _fallback() {
    return SizedBox.square(
      dimension: widget.size,
      child: Center(
        child: Icon(
          widget.fallbackIcon,
          size: widget.size * 0.55,
          color: widget.color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _icon,
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null) return _fallback();
        // A square box keeps the thumbnail identical in width and height no
        // matter how the surrounding row constrains it.
        return SizedBox.square(
          dimension: widget.size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius ?? 10),
            child: Image.file(
              File(path),
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              // Decode at ~2x the display size: crisp on high-DPI screens
              // without caching 500 full-resolution textures in memory.
              cacheWidth: (widget.size * 2).round(),
              cacheHeight: (widget.size * 2).round(),
              errorBuilder: (context, error, stackTrace) => _fallback(),
            ),
          ),
        );
      },
    );
  }
}
