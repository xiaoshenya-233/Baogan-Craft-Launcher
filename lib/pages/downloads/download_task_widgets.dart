import 'package:flutter/material.dart';

import '../../core/format_utils.dart';
import '../../services/download/download_service.dart';
import '../launcher/launcher_palette.dart';

const Color _green = Color(0xFF8BC34A);
const int _visibleJobsPerGroup = 12;

/// Aggregate card for the currently running download batch.
class DownloadTaskSummaryCard extends StatelessWidget {
  const DownloadTaskSummaryCard({
    super.key,
    required this.task,
    required this.manager,
    required this.palette,
  });

  final String task;
  final DownloadManager manager;
  final LauncherPalette palette;

  @override
  Widget build(BuildContext context) {
    final groups = manager.groups.where((group) => group.hasPending).toList();
    final totalBytes = groups.fold<int>(
      0,
      (sum, group) => sum + group.totalBytes,
    );
    final receivedBytes = groups.fold<int>(
      0,
      (sum, group) => sum + group.receivedBytes,
    );
    final progress = totalBytes > 0
        ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
        : null;
    final percent = progress == null
        ? '准备中'
        : '${(progress * 100).toStringAsFixed(0)}%';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
      decoration: BoxDecoration(
        color: palette.selectedSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_download_outlined, size: 21, color: _green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '总任务进度',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                percent,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: palette.selectedForegroundColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: palette.panelBorderColor,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                totalBytes > 0
                    ? '${formatByteSize(receivedBytes)} / '
                          '${formatByteSize(totalBytes)}'
                    : '已下载 ${formatByteSize(receivedBytes)}',
                style: TextStyle(fontSize: 10, color: palette.muted),
              ),
              const Spacer(),
              Icon(Icons.speed_rounded, size: 14, color: palette.muted),
              const SizedBox(width: 4),
              Text(
                '${formatByteSize(manager.totalSpeed)}/s',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: palette.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One download group: aggregate header plus at most 12 virtualized file rows.
class DownloadTaskGroupCard extends StatelessWidget {
  const DownloadTaskGroupCard({
    super.key,
    required this.group,
    required this.manager,
    required this.palette,
  });

  final DownloadGroupStats group;
  final DownloadManager manager;
  final LauncherPalette palette;

  @override
  Widget build(BuildContext context) {
    final jobs = manager.jobsForGroup(group.label, limit: _visibleJobsPerGroup);
    final remaining = group.pendingJobIds.length - jobs.length;
    final progress = group.progress;
    final percent = progress == null
        ? '统计中'
        : '${(progress * 100).toStringAsFixed(0)}%';
    final speed = manager.groupSpeed(group.label);
    final icon = switch (group.kind) {
      '游戏版本' => Icons.inventory_2_outlined,
      '模组加载器' => Icons.extension_outlined,
      _ => Icons.download_rounded,
    };
    final totalText = group.totalBytes > 0
        ? '${formatByteSize(group.receivedBytes)} / '
              '${formatByteSize(group.totalBytes)}'
        : '已下载 ${formatByteSize(group.receivedBytes)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: palette.panelColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.panelBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: palette.panelAccentColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: _green),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${group.completedJobs}/${group.totalJobs} 个文件完成'
                      '${group.pendingJobIds.isEmpty ? '' : ' · 剩余 ${group.pendingJobIds.length}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9.5, color: palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    percent,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: progress == null
                          ? palette.muted
                          : palette.selectedForegroundColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatByteSize(speed)}/s',
                    style: TextStyle(fontSize: 9, color: palette.muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: palette.panelBorderColor,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                totalText,
                style: TextStyle(fontSize: 9.5, color: palette.muted),
              ),
              const Spacer(),
              Text(
                speed > 0 ? '${formatByteSize(speed)}/s' : '等待数据…',
                style: TextStyle(fontSize: 9, color: palette.muted),
              ),
            ],
          ),
          if (jobs.isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: palette.panelAccentColor.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withValues(alpha: 0.22)),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < jobs.length; index++) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        indent: 10,
                        endIndent: 10,
                        color: palette.panelBorderColor.withValues(alpha: 0.55),
                      ),
                    DownloadTaskFileRow(job: jobs[index], palette: palette),
                  ],
                  if (remaining > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '另有 $remaining 个文件在队列中',
                          style: TextStyle(fontSize: 9.5, color: palette.muted),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One file row; rebuilds only when its own [DownloadJob.revision] changes.
class DownloadTaskFileRow extends StatelessWidget {
  const DownloadTaskFileRow({
    super.key,
    required this.job,
    required this.palette,
  });

  final DownloadJob job;
  final LauncherPalette palette;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: job.revision,
        builder: (context, _, _) {
          final total = job.totalBytes;
          final progress = job.progress;
          final queued = job.state == DownloadJobState.queued;
          final percent = queued
              ? '排队'
              : progress == null
              ? '准备中'
              : '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%';
          final sizeText = total != null && total > 0
              ? '${formatByteSize(job.receivedBytes)} / '
                    '${formatByteSize(total)}'
              : '已下载 ${formatByteSize(job.receivedBytes)}';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Icon(
                  queued
                      ? Icons.schedule_rounded
                      : Icons.insert_drive_file_outlined,
                  size: 14,
                  color: palette.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: palette.buttonForeground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: queued ? 0 : progress,
                          minHeight: 2.5,
                          backgroundColor: palette.panelBorderColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                SizedBox(
                  width: 68,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        percent,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: palette.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        queued ? '' : sizeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 8.5, color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Empty state shown when no task is active.
class DownloadTasksEmptyCard extends StatelessWidget {
  const DownloadTasksEmptyCard({super.key, required this.palette});

  final LauncherPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: palette.panelColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.panelBorderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.download_done_rounded, size: 32, color: palette.muted),
          const SizedBox(height: 10),
          Text(
            '当前没有下载任务',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Queue count and the "cancel current download" action.
class DownloadTasksFooter extends StatelessWidget {
  const DownloadTasksFooter({
    super.key,
    required this.manager,
    required this.palette,
    required this.canCancel,
    required this.onCancel,
  });

  final DownloadManager manager;
  final LauncherPalette palette;
  final bool canCancel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (manager.queuedCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            '队列中还有 ${manager.queuedCount} 个文件等待下载。',
            style: TextStyle(fontSize: 11, color: palette.muted),
          ),
        ],
        if (canCancel) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('取消当前下载'),
            ),
          ),
        ],
      ],
    );
  }
}
