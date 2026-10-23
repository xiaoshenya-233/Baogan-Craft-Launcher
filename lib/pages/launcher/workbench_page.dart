import 'package:flutter/material.dart';

import 'launcher_palette.dart';

/// Placeholder for the upcoming workbench tab.
///
/// The tab is wired into the shell navigation now so tooling can be added
/// without touching the sidebar or routing again.
class WorkbenchPage extends StatelessWidget {
  const WorkbenchPage({super.key, required this.palette});

  final LauncherPalette palette;

  @override
  Widget build(BuildContext context) {
    final accent = palette.uiColors.accent;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: palette.panelAccentColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.panelBorderColor),
              ),
              child: Icon(Icons.handyman_rounded, size: 44, color: accent),
            ),
            const SizedBox(height: 20),
            const Text(
              '工作台开发中',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              '这里将汇集存档整理、模组批量操作与日志分析等实用工具。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
