import 'package:flutter/material.dart';

import '../client_tile.dart';

class LaunchFailureDialogs {
  const LaunchFailureDialogs._();

  static Future<void> showMissingMods(
    BuildContext context, {
    required List<String> missingDependencies,
    required LauncherUiColors colors,
    required VoidCallback onOpenDebugLog,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('缺少模组依赖'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '客户端模组要求以下依赖，但 mods 文件夹中没有找到：',
                style: TextStyle(fontSize: 12, color: colors.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: missingDependencies.map((id) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.panelAccent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      id,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              const Text(
                '请安装对应模组的兼容版本（例如 Kotlin for Forge），然后重新启动客户端。',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: onOpenDebugLog,
            icon: const Icon(Icons.terminal_rounded, size: 16),
            label: const Text('打开调试日志'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  static Future<void> showIncompatibleMods(
    BuildContext context, {
    required String message,
    required VoidCallback onOpenDebugLog,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('模组版本不兼容'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: onOpenDebugLog,
            icon: const Icon(Icons.terminal_rounded, size: 16),
            label: const Text('打开调试日志'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  static Future<void> showUnknownFailure(
    BuildContext context, {
    required String versionId,
    required int exitCode,
    required String snippet,
    required LauncherUiColors colors,
    required VoidCallback onOpenDebugLog,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Minecraft 启动失败'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Minecraft $versionId 已退出，退出代码：$exitCode。'),
                const SizedBox(height: 8),
                Text(
                  '完整启动参数和游戏输出已写入调试日志，可打开独立日志窗口查看。',
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
                if (snippet.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '启动输出',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.panelAccent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: SelectableText(
                      snippet,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: onOpenDebugLog,
            icon: const Icon(Icons.terminal_rounded, size: 16),
            label: const Text('打开调试日志'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showJavaMismatch(
    BuildContext context, {
    required String versionId,
    required int exitCode,
    required String currentJava,
    required String snippet,
    required LauncherUiColors colors,
    required VoidCallback onOpenDebugLog,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Java 版本可能不兼容'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Minecraft $versionId 启动失败（退出代码 $exitCode），'
                  '可能与 Java 版本不匹配有关。',
                ),
                const SizedBox(height: 8),
                Text('当前使用：$currentJava'),
                const SizedBox(height: 8),
                const Text('请在“设置 → Java 管理”中更换 Java，或安装游戏所需的 Java 版本后重试。'),
                if (snippet.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '启动输出',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.panelAccent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: SelectableText(
                      snippet,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: onOpenDebugLog,
            icon: const Icon(Icons.terminal_rounded, size: 16),
            label: const Text('打开调试日志'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('前往 Java 设置'),
          ),
        ],
      ),
    );
  }
}
