import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/format_utils.dart';
import '../../services/download/download_service.dart';

class ActiveDownloadBanner extends StatelessWidget {
  const ActiveDownloadBanner({
    super.key,
    required this.manager,
    required this.task,
    required this.canCancel,
    required this.onTap,
    required this.onCancel,
    required this.surfaceColor,
    required this.panelBorderColor,
    required this.buttonForegroundColor,
    required this.selectedForegroundColor,
    required this.mutedColor,
    required this.accentColor,
  });

  final DownloadManager manager;
  final String task;
  final bool canCancel;
  final VoidCallback onTap;
  final VoidCallback onCancel;
  final Color surfaceColor;
  final Color panelBorderColor;
  final Color buttonForegroundColor;
  final Color selectedForegroundColor;
  final Color mutedColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: manager,
      builder: (context, _) {
        final groups = manager.groups
            .where((group) => group.hasPending)
            .toList();
        final total = groups.fold<int>(
          0,
          (sum, group) => sum + group.totalBytes,
        );
        final received = groups.fold<int>(
          0,
          (sum, group) => sum + group.receivedBytes,
        );
        final speed = manager.totalSpeed;
        final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : null;
        final percent = progress == null
            ? null
            : '${(progress * 100).toStringAsFixed(0)}%';
        return Padding(
          padding: EdgeInsets.only(right: Platform.isWindows ? 132 : 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Material(
              color: surfaceColor,
              shape: StadiumBorder(
                side: BorderSide(color: accentColor.withValues(alpha: 0.55)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                customBorder: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.downloading_rounded,
                            size: 17,
                            color: accentColor,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              task,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: buttonForegroundColor,
                              ),
                            ),
                          ),
                          if (percent != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              percent,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: selectedForegroundColor,
                              ),
                            ),
                          ],
                          if (speed > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${formatByteSize(speed)}/s',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: mutedColor,
                              ),
                            ),
                          ],
                          if (progress == null) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                          if (canCancel) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: '取消下载',
                              onPressed: onCancel,
                              icon: const Icon(Icons.close_rounded, size: 14),
                              color: mutedColor,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 22,
                                height: 22,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor: panelBorderColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
