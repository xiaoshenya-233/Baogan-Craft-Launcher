import 'package:flutter/material.dart';

import '../../core/format_utils.dart';
import '../../services/download/download_service.dart';
import '../launcher/controllers/download_activity_controller.dart';
import '../launcher/launcher_palette.dart';

class DownloadTasksPage extends StatelessWidget {
  const DownloadTasksPage({
    super.key,
    required this.activity,
    required this.manager,
    required this.palette,
    this.onCancelActiveDownload,
  });

  final DownloadActivityController activity;
  final DownloadManager manager;
  final LauncherPalette palette;
  final VoidCallback? onCancelActiveDownload;

  static const _green = Color(0xFF8BC34A);
  DownloadManager get _downloadManager => manager;
  String? get _activeDownloadTask => activity.activeTask;
  bool get _canCancelActiveDownload => activity.canCancel;
  Color get _muted => palette.muted;
  Color get _panelColor => palette.panelColor;
  Color get _panelBorderColor => palette.panelBorderColor;
  Color get _panelAccentColor => palette.panelAccentColor;
  Color get _selectedSurfaceColor => palette.selectedSurfaceColor;
  Color get _selectedForegroundColor => palette.selectedForegroundColor;
  Color get _buttonForeground => palette.buttonForeground;

  void _cancelActiveDownload() {
    if (onCancelActiveDownload != null) {
      onCancelActiveDownload!();
    } else {
      activity.cancel();
    }
  }

  @override
  Widget build(BuildContext context) => _buildDownloadTasks();
  Widget _buildDownloadTasks() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return AnimatedBuilder(
          animation: _downloadManager,
          builder: (context, _) {
            final groups = _downloadManager.groups
                .where((group) => group.hasPending)
                .toList();
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                compact ? 20 : 36,
                30,
                compact ? 20 : 36,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '下载任务',
                        style: TextStyle(
                          fontSize: compact ? 26 : 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '客户端与资源文件按任务分组显示；每组包含总进度与速度，文件进度在组内展开。',
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                      const SizedBox(height: 22),
                      if (_activeDownloadTask != null) ...[
                        _buildDownloadTaskSummary(),
                        const SizedBox(height: 14),
                      ],
                      if (groups.isEmpty && _activeDownloadTask == null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 36,
                          ),
                          decoration: BoxDecoration(
                            color: _panelColor,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: _panelBorderColor),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.download_done_rounded,
                                size: 32,
                                color: _muted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '当前没有下载任务',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final group in groups) ...[
                          _buildDownloadGroupCard(group),
                          const SizedBox(height: 10),
                        ],
                      if (_downloadManager.queuedCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '队列中还有 ${_downloadManager.queuedCount} 个文件等待下载。',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                      if (_canCancelActiveDownload) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _cancelActiveDownload,
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('取消当前下载'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDownloadTaskSummary() {
    final task = _activeDownloadTask;
    if (task == null) return const SizedBox.shrink();
    final groups = _downloadManager.groups
        .where((group) => group.hasPending)
        .toList();
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
    final speed = _downloadManager.totalSpeed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
      decoration: BoxDecoration(
        color: _selectedSurfaceColor,
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
                        color: _muted,
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
                  color: _selectedForegroundColor,
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
              backgroundColor: _panelBorderColor,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                totalBytes > 0
                    ? '${formatByteSize(receivedBytes)} / ${formatByteSize(totalBytes)}'
                    : '已下载 ${formatByteSize(receivedBytes)}',
                style: TextStyle(fontSize: 10, color: _muted),
              ),
              const Spacer(),
              Icon(Icons.speed_rounded, size: 14, color: _muted),
              const SizedBox(width: 4),
              Text(
                '${formatByteSize(speed)}/s',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadGroupCard(DownloadGroupStats group) {
    final jobs = _downloadManager.jobsForGroup(group.label);
    final visibleJobs = jobs.take(12).toList();
    final progress = group.progress;
    final percent = progress == null
        ? '统计中'
        : '${(progress * 100).toStringAsFixed(0)}%';
    final speed = _downloadManager.groupSpeed(group.label);
    final activeCount = jobs
        .where((job) => job.state == DownloadJobState.downloading)
        .length;
    final queuedCount = jobs
        .where((job) => job.state == DownloadJobState.queued)
        .length;
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
        color: _panelColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _panelBorderColor),
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
                  color: _panelAccentColor,
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
                      '${activeCount > 0 ? ' · $activeCount 个下载中' : ''}'
                      '${queuedCount > 0 ? ' · $queuedCount 个排队' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9.5, color: _muted),
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
                          ? _muted
                          : _selectedForegroundColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatByteSize(speed)}/s',
                    style: TextStyle(fontSize: 9, color: _muted),
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
              backgroundColor: _panelBorderColor,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(totalText, style: TextStyle(fontSize: 9.5, color: _muted)),
              const Spacer(),
              Text(
                speed > 0 ? '${formatByteSize(speed)}/s' : '等待数据…',
                style: TextStyle(fontSize: 9, color: _muted),
              ),
            ],
          ),
          if (visibleJobs.isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: _panelAccentColor.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withValues(alpha: 0.22)),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < visibleJobs.length; index++) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        indent: 10,
                        endIndent: 10,
                        color: _panelBorderColor.withValues(alpha: 0.55),
                      ),
                    _buildDownloadFileRow(visibleJobs[index]),
                  ],
                  if (jobs.length > visibleJobs.length)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '另有 ${jobs.length - visibleJobs.length} 个文件在队列中',
                          style: TextStyle(fontSize: 9.5, color: _muted),
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

  Widget _buildDownloadFileRow(DownloadJob job) {
    final total = job.totalBytes;
    final progress = job.progress;
    final queued = job.state == DownloadJobState.queued;
    final percent = queued
        ? '排队'
        : progress == null
        ? '准备中'
        : '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%';
    final sizeText = total != null && total > 0
        ? '${formatByteSize(job.receivedBytes)} / ${formatByteSize(total)}'
        : '已下载 ${formatByteSize(job.receivedBytes)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Icon(
            queued ? Icons.schedule_rounded : Icons.insert_drive_file_outlined,
            size: 14,
            color: _muted,
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
                  style: TextStyle(fontSize: 10.5, color: _buttonForeground),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: queued ? 0 : progress,
                    minHeight: 2.5,
                    backgroundColor: _panelBorderColor,
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
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  queued ? '' : sizeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 8.5, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
