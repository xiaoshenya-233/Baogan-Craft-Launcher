import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../launcher/launcher_common.dart';

/// Corners that can be dragged to resize the crop rectangle.
enum _CropCorner { topLeft, topRight, bottomLeft, bottomRight }

class WallpaperCropDialog extends StatefulWidget {
  const WallpaperCropDialog({
    super.key,
    required this.file,
    required this.aspectRatio,
    this.initialCrop,
  });

  final File file;
  final double aspectRatio;
  final Rect? initialCrop;

  @override
  State<WallpaperCropDialog> createState() => _WallpaperCropDialogState();
}

class _WallpaperCropDialogState extends State<WallpaperCropDialog> {
  ui.Image? _image;
  String? _error;
  Rect? _crop;
  Size _previewSize = Size.zero;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        if (!mounted) {
          frame.image.dispose();
          return;
        }
        setState(() {
          _image = frame.image;
        });
      } finally {
        codec.dispose();
      }
    } on FileSystemException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Size _fitImage(Size available, double imageAspect) {
    var width = available.width;
    var height = width / imageAspect;
    if (height > available.height) {
      height = available.height;
      width = height * imageAspect;
    }
    return Size(width, height);
  }

  Rect _initialSelection(Size size) {
    final cropAspect = widget.aspectRatio;
    var width = size.width * 0.9;
    var height = width / cropAspect;
    if (height > size.height * 0.9) {
      height = size.height * 0.9;
      width = height * cropAspect;
    }
    final initial = widget.initialCrop;
    if (initial != null) {
      final restored = Rect.fromLTRB(
        initial.left * size.width,
        initial.top * size.height,
        initial.right * size.width,
        initial.bottom * size.height,
      );
      if (restored.width > 0 &&
          restored.height > 0 &&
          restored.width <= size.width &&
          restored.height <= size.height) {
        return restored;
      }
    }
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: width,
      height: height,
    );
  }

  void _moveCrop(Offset delta) {
    final crop = _crop;
    if (crop == null) return;
    final dx = delta.dx.clamp(-crop.left, _previewSize.width - crop.right);
    final dy = delta.dy.clamp(-crop.top, _previewSize.height - crop.bottom);
    setState(() => _crop = crop.shift(Offset(dx, dy)));
  }

  /// Resizes the crop from [corner] while keeping the requested aspect ratio.
  ///
  /// The opposite corner stays anchored, and the new size is clamped to the
  /// preview bounds so the rectangle can never leave the image.
  void _resizeCrop(Offset delta, _CropCorner corner) {
    final crop = _crop;
    if (crop == null || _previewSize.isEmpty) return;
    final aspect = widget.aspectRatio <= 0 ? 1.0 : widget.aspectRatio;
    final isRight =
        corner == _CropCorner.topRight || corner == _CropCorner.bottomRight;
    final isBottom =
        corner == _CropCorner.bottomLeft || corner == _CropCorner.bottomRight;

    // Use whichever drag axis the player moved further.
    final horizontal = delta.dx * (isRight ? 1 : -1);
    final vertical = delta.dy * (isBottom ? 1 : -1) * aspect;
    final deltaWidth = horizontal.abs() >= vertical.abs()
        ? horizontal
        : vertical;

    final anchor = Offset(
      isRight ? crop.left : crop.right,
      isBottom ? crop.top : crop.bottom,
    );
    final maxWidth = math.min(
      isRight ? _previewSize.width - anchor.dx : anchor.dx,
      (isBottom ? _previewSize.height - anchor.dy : anchor.dy) * aspect,
    );
    if (maxWidth <= 0) return;
    final minWidth = math.min(64.0, maxWidth);
    final newWidth = (crop.width + deltaWidth)
        .clamp(minWidth, maxWidth)
        .toDouble();
    final newHeight = newWidth / aspect;
    setState(() {
      _crop = Rect.fromLTWH(
        isRight ? anchor.dx : anchor.dx - newWidth,
        isBottom ? anchor.dy : anchor.dy - newHeight,
        newWidth,
        newHeight,
      );
    });
  }

  void _applyCrop() {
    final crop = _crop;
    if (crop == null || _previewSize.isEmpty) return;
    final normalized = Rect.fromLTRB(
      (crop.left / _previewSize.width).clamp(0.0, 1.0),
      (crop.top / _previewSize.height).clamp(0.0, 1.0),
      (crop.right / _previewSize.width).clamp(0.0, 1.0),
      (crop.bottom / _previewSize.height).clamp(0.0, 1.0),
    );
    if (normalized.width <= 0 || normalized.height <= 0) return;
    Navigator.of(context).pop(normalized);
  }

  Widget _buildHandle(_CropCorner corner, Rect crop) {
    const size = 30.0;
    final isLeft =
        corner == _CropCorner.topLeft || corner == _CropCorner.bottomLeft;
    final isTop =
        corner == _CropCorner.topLeft || corner == _CropCorner.topRight;
    // Keep the handle fully inside the preview so it stays clickable even when
    // the selection touches the image border (for example a full-image crop).
    final left = ((isLeft ? crop.left : crop.right) - size / 2)
        .clamp(0.0, math.max(0.0, _previewSize.width - size))
        .toDouble();
    final top = ((isTop ? crop.top : crop.bottom) - size / 2)
        .clamp(0.0, math.max(0.0, _previewSize.height - size))
        .toDouble();
    // Invisible drag target: the corner brackets are painted by
    // [CropOverlayPainter], so no extra dot is drawn on top of the image.
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => _resizeCrop(details.delta, corner),
        child: const SizedBox.expand(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '裁切壁纸',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '拖动框内平移选区，拖动四角圆点调整大小。',
                style: TextStyle(fontSize: 12, color: Color(0xFF9AA397)),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: math.min(
                  380,
                  MediaQuery.sizeOf(context).height * 0.55,
                ),
                width: double.infinity,
                child: _image == null
                    ? Center(
                        child: _error == null
                            ? const CircularProgressIndicator()
                            : Text(
                                '无法读取壁纸：$_error',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final imageAspect = _image!.width / _image!.height;
                          final previewSize = _fitImage(
                            Size(constraints.maxWidth, constraints.maxHeight),
                            imageAspect,
                          );
                          if (_previewSize != previewSize) {
                            final previous = _previewSize;
                            final current = _crop;
                            _previewSize = previewSize;
                            if (current == null || previous.isEmpty) {
                              _crop = _initialSelection(previewSize);
                            } else {
                              // Keep the selection when the dialog is resized.
                              _crop = Rect.fromLTRB(
                                current.left *
                                    previewSize.width /
                                    previous.width,
                                current.top *
                                    previewSize.height /
                                    previous.height,
                                current.right *
                                    previewSize.width /
                                    previous.width,
                                current.bottom *
                                    previewSize.height /
                                    previous.height,
                              );
                            }
                          }
                          final crop = _crop!;
                          return Center(
                            child: SizedBox.fromSize(
                              size: previewSize,
                              child: Stack(
                                clipBehavior: Clip.none,
                                fit: StackFit.expand,
                                children: [
                                  Image.file(widget.file, fit: BoxFit.fill),
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: CropOverlayPainter(crop),
                                    ),
                                  ),
                                  Positioned.fromRect(
                                    rect: crop,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onPanUpdate: (details) =>
                                          _moveCrop(details.delta),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                  for (final corner in _CropCorner.values)
                                    _buildHandle(corner, crop),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TranslucentButtonSurface(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _crop == null ? null : _applyCrop,
                    child: Text('应用裁切'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CropOverlayPainter extends CustomPainter {
  const CropOverlayPainter(this.crop);

  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final cropRect = Rect.fromLTRB(
      crop.left.clamp(0.0, size.width),
      crop.top.clamp(0.0, size.height),
      crop.right.clamp(0.0, size.width),
      crop.bottom.clamp(0.0, size.height),
    );
    if (cropRect.width <= 0 || cropRect.height <= 0) return;

    final dim = Paint()..color = Colors.black.withValues(alpha: 0.6);
    final full = Path()..addRect(Offset.zero & size);
    final selected = Path()..addRect(cropRect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, selected),
      dim,
    );

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    canvas.drawRect(cropRect, border);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = cropRect.left + cropRect.width * i / 3;
      final y = cropRect.top + cropRect.height * i / 3;
      canvas.drawLine(
        Offset(x, cropRect.top),
        Offset(x, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, y),
        Offset(cropRect.right, y),
        gridPaint,
      );
    }

    // Google-Photos style corner brackets.
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square
      ..color = Colors.white;
    final arm = math.min(22.0, math.min(cropRect.width, cropRect.height) / 4);
    for (final corner in const <(bool, bool)>[
      (true, true),
      (false, true),
      (true, false),
      (false, false),
    ]) {
      final left = corner.$1 ? cropRect.left : cropRect.right;
      final top = corner.$2 ? cropRect.top : cropRect.bottom;
      final dx = corner.$1 ? arm : -arm;
      final dy = corner.$2 ? arm : -arm;
      canvas.drawLine(Offset(left, top), Offset(left + dx, top), bracket);
      canvas.drawLine(Offset(left, top), Offset(left, top + dy), bracket);
    }
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) =>
      oldDelegate.crop != crop;
}

/// Crops the normalized [crop] rectangle out of [file] and encodes a square
/// PNG of at most [maxSize] pixels. Returns `null` when decoding fails.
Future<Uint8List?> cropFileToPng(
  File file,
  Rect crop, {
  int maxSize = 512,
}) async {
  try {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final left = (crop.left.clamp(0.0, 1.0) * image.width).round();
      final top = (crop.top.clamp(0.0, 1.0) * image.height).round();
      final right = (crop.right.clamp(0.0, 1.0) * image.width).round();
      final bottom = (crop.bottom.clamp(0.0, 1.0) * image.height).round();
      final width = math.max(1, right - left);
      final height = math.max(1, bottom - top);
      final side = math.min(width, height);
      final source = Rect.fromLTWH(
        (left + (width - side) / 2).toDouble(),
        (top + (height - side) / 2).toDouble(),
        side.toDouble(),
        side.toDouble(),
      );
      final output = math.min(side, maxSize).toDouble();
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        image,
        source,
        Rect.fromLTWH(0, 0, output, output),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      try {
        final cropped = await picture.toImage(output.round(), output.round());
        try {
          final data = await cropped.toByteData(
            format: ui.ImageByteFormat.png,
          );
          return data?.buffer.asUint8List();
        } finally {
          cropped.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      image.dispose();
      codec.dispose();
    }
  } on Object {
    return null;
  }
}
