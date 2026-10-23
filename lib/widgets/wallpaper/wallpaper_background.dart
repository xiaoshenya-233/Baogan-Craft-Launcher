import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum WallpaperDisplayMode {
  cover('铺满'),
  stretch('拉伸'),
  zoom('放大');

  const WallpaperDisplayMode(this.label);

  final String label;
}

class WallpaperBackground extends StatefulWidget {
  const WallpaperBackground({
    super.key,
    required this.file,
    required this.crop,
    required this.mode,
  });

  final File file;
  final Rect crop;
  final WallpaperDisplayMode mode;

  @override
  State<WallpaperBackground> createState() => _WallpaperBackgroundState();
}

class _WallpaperBackgroundState extends State<WallpaperBackground> {
  ui.Image? _image;
  ImageInfo? _imageInfo;
  Object? _loadError;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant WallpaperBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) _resolveImage();
  }

  void _resolveImage() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _image = null;
    _loadError = null;
    final stream = FileImage(widget.file).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (imageInfo, _) {
        if (!mounted) return;
        final retainedImageInfo = imageInfo.clone();
        _imageInfo?.dispose();
        _imageInfo = retainedImageInfo;
        setState(() {
          _image = retainedImageInfo.image;
          _loadError = null;
        });
      },
      onError: (exception, stackTrace) {
        if (!mounted) return;
        setState(() => _loadError = exception);
      },
    );
    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageInfo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: ValueKey('wallpaper-${widget.file.path}'),
      painter: WallpaperPainter(_image, widget.crop, widget.mode),
      child: _loadError == null || _image != null
          ? const SizedBox.expand()
          : const Center(
              child: Text(
                '壁纸加载失败，请前往设置重新选择。',
                style: TextStyle(color: Colors.white70),
              ),
            ),
    );
  }
}

class WallpaperPainter extends CustomPainter {
  const WallpaperPainter(this.image, this.crop, this.mode);

  final ui.Image? image;
  final Rect crop;
  final WallpaperDisplayMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null || size.isEmpty) {
      canvas.drawColor(const Color(0xFF101510), BlendMode.src);
      return;
    }

    var source = Rect.fromLTRB(
      crop.left * image.width,
      crop.top * image.height,
      crop.right * image.width,
      crop.bottom * image.height,
    );
    if (source.isEmpty) {
      // A degenerate persisted crop must never blank the wallpaper.
      source = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
    }
    if (mode == WallpaperDisplayMode.zoom) {
      final zoomWidth = source.width / 1.3;
      final zoomHeight = source.height / 1.3;
      source = Rect.fromCenter(
        center: source.center,
        width: zoomWidth,
        height: zoomHeight,
      );
    } else if (mode == WallpaperDisplayMode.cover) {
      final sourceAspect = source.width / source.height;
      final targetAspect = size.width / size.height;
      if (sourceAspect > targetAspect) {
        final width = source.height * targetAspect;
        source = Rect.fromCenter(
          center: source.center,
          width: width,
          height: source.height,
        );
      } else if (sourceAspect < targetAspect) {
        final height = source.width / targetAspect;
        source = Rect.fromCenter(
          center: source.center,
          width: source.width,
          height: height,
        );
      }
    }

    canvas.drawImageRect(
      image,
      source,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant WallpaperPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.crop != crop ||
      oldDelegate.mode != mode;
}
