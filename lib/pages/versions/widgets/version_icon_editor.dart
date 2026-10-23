import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/launcher_log.dart';
import '../../../services/installer/version_models.dart';
import '../../../widgets/version_icon.dart';
import '../../../widgets/wallpaper/wallpaper_crop_dialog.dart';

/// Client icon with an edit button.
///
/// Picks a PNG/JPG, forces a 1:1 crop with [WallpaperCropDialog], then stores
/// the result as `<version>/BGCL/logo.png`, which [VersionIcon] prefers.
class VersionIconEditor extends StatefulWidget {
  const VersionIconEditor({
    super.key,
    required this.version,
    required this.onMessage,
  });

  final LauncherVersion version;
  final ValueChanged<String> onMessage;

  @override
  State<VersionIconEditor> createState() => _VersionIconEditorState();
}

class _VersionIconEditorState extends State<VersionIconEditor> {
  int _revision = 0;
  bool _isSaving = false;

  Future<void> _pickAndCrop() async {
    if (_isSaving) return;
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['png', 'jpg', 'jpeg'],
      dialogTitle: '选择客户端图标（PNG / JPG）',
    );
    final path = files.isEmpty ? null : files.first.path;
    if (path == null || !mounted) return;
    final source = File(path);
    if (!await source.exists() || !mounted) {
      widget.onMessage('所选图片无法读取：$path');
      return;
    }
    final crop = await showDialog<Rect>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          WallpaperCropDialog(file: source, aspectRatio: 1),
    );
    if (crop == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final bytes = await cropFileToPng(source, crop);
      if (bytes == null || bytes.isEmpty) {
        widget.onMessage('裁剪失败，请换一张图片重试。');
        return;
      }
      final target = File(
        VersionIcon.customLogoPathFor(widget.version.versionDirectoryPath),
      );
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes, flush: true);
      LauncherLog.info('Versions', '已保存客户端图标：${target.path}');
      if (!mounted) return;
      setState(() => _revision++);
      widget.onMessage('已更新 ${widget.version.name} 的客户端图标。');
    } on FileSystemException catch (error) {
      widget.onMessage('保存图标失败：${error.message}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static const double _iconSize = 84;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _iconSize,
      height: _iconSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          VersionIcon(
            key: ValueKey(_revision),
            version: widget.version,
            size: _iconSize,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Tooltip(
              message: '更换客户端图标',
              child: Material(
                color: scheme.primary,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _isSaving ? null : _pickAndCrop,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: _isSaving
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : Icon(Icons.edit, size: 15, color: scheme.onPrimary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
