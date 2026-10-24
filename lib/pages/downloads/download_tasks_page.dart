import 'package:flutter/material.dart';

import '../../services/download/download_service.dart';
import '../launcher/controllers/download_activity_controller.dart';
import '../launcher/launcher_palette.dart';
import 'download_task_widgets.dart';

/// Download manager page.
///
/// The page only builds a virtualized [ListView.builder]; aggregate cards and
/// per-file rows live in `download_task_widgets.dart`, where each row listens
/// to its own [DownloadJob.revision] instead of the whole manager.
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

  void _cancel() {
    if (onCancelActiveDownload != null) {
      onCancelActiveDownload!();
    } else {
      activity.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 36,
            26,
            compact ? 20 : 36,
            0,
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
                    style: TextStyle(color: palette.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: manager,
                      builder: (context, _) => _buildTaskList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskList() {
    final hasSummary = activity.activeTask != null;
    final groups = manager.groups
        .where((group) => group.hasPending)
        .toList(growable: false);
    final footer = DownloadTasksFooter(
      manager: manager,
      palette: palette,
      canCancel: activity.canCancel,
      onCancel: _cancel,
    );

    if (groups.isEmpty && !hasSummary) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          DownloadTasksEmptyCard(palette: palette),
          const SizedBox(height: 10),
          footer,
        ],
      );
    }

    final offset = hasSummary ? 1 : 0;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: groups.length + offset + 1,
      itemBuilder: (context, index) {
        if (hasSummary && index == 0) {
          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DownloadTaskSummaryCard(
                task: activity.activeTask!,
                manager: manager,
                palette: palette,
              ),
            ),
          );
        }
        final groupIndex = index - offset;
        if (groupIndex < groups.length) {
          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DownloadTaskGroupCard(
                group: groups[groupIndex],
                manager: manager,
                palette: palette,
              ),
            ),
          );
        }
        return footer;
      },
    );
  }
}
