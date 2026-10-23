import 'package:flutter/material.dart';

import '../../../services/java/java_service.dart';
import '../../launcher/launcher_palette.dart';

/// Read-only "Java 管理" summary shown in the settings page.
///
/// It only lists the known runtimes; the global default is chosen by the
/// dropdown in the "全局游戏默认设置" card, and scanning/removing happens on the
/// embedded Java management page.
class JavaSummaryCard extends StatelessWidget {
  const JavaSummaryCard({
    super.key,
    required this.palette,
    required this.runtimes,
    required this.isLoading,
    required this.error,
    required this.selectedExecutable,
    required this.onManage,
  });

  final LauncherPalette palette;
  final List<JavaRuntime> runtimes;
  final bool isLoading;
  final String? error;
  final String? selectedExecutable;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final muted = palette.muted;
    final accent = palette.uiColors.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLoading) const LinearProgressIndicator(minHeight: 2),
        if (error != null)
          Text(
            error!,
            style: const TextStyle(fontSize: 11, color: Color(0xFFE05B5B)),
          ),
        if (!isLoading && runtimes.isEmpty && error == null)
          Text(
            '尚未检测到 Java。点击「管理 Java」扫描本机或手动添加。',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        for (final runtime in runtimes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.memory_rounded, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${runtime.displayName} · Java ${runtime.majorVersion}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        runtime.executable,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                ),
                if (runtime.executable == selectedExecutable)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '当前使用',
                      style: TextStyle(fontSize: 9.5, color: accent),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: onManage,
          icon: const Icon(Icons.settings_suggest_outlined, size: 18),
          label: const Text('管理 Java'),
        ),
      ],
    );
  }
}
