import 'package:flutter/material.dart';

import '../services/java/java_service.dart';

/// Java runtime management section used by the settings and home pages.
class JavaManagementCard extends StatelessWidget {
  const JavaManagementCard({
    super.key,
    required this.runtimes,
    required this.selectedExecutable,
    required this.isLoading,
    required this.error,
    required this.accentColor,
    required this.panelColor,
    required this.panelAccentColor,
    required this.borderColor,
    required this.foregroundColor,
    required this.mutedColor,
    required this.onDiscover,
    required this.onAdd,
    required this.onSelect,
  });

  final List<JavaRuntime> runtimes;
  final String? selectedExecutable;
  final bool isLoading;
  final String? error;
  final Color accentColor;
  final Color panelColor;
  final Color panelAccentColor;
  final Color borderColor;
  final Color foregroundColor;
  final Color mutedColor;
  final VoidCallback onDiscover;
  final VoidCallback onAdd;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.coffee_rounded, size: 18, color: accentColor),
              const SizedBox(width: 9),
              const Text(
                'Java 管理',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '多源扫描环境变量、PATH、注册表、常见安装目录与启动器运行时；优先解析 JDK release 文件，'
            '失败后回退到 java -version，并将验证结果缓存到本地以加速后续启动。',
            style: TextStyle(fontSize: 11, color: mutedColor),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: isLoading ? null : onDiscover,
                icon: const Icon(Icons.manage_search_rounded, size: 16),
                label: const Text('自动搜索 Java'),
              ),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('添加 Java'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else if (runtimes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error ?? '尚未搜索 Java，点击“自动搜索 Java”开始。',
                style: TextStyle(fontSize: 11, color: mutedColor),
              ),
            )
          else
            ...runtimes.map(
              (runtime) => _buildTile(
                runtime,
                selected: runtime.executable == selectedExecutable,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTile(JavaRuntime runtime, {required bool selected}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panelAccentColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? accentColor : borderColor,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              runtime.majorVersion == 0
                  ? 'Java ?'
                  : 'Java ${runtime.majorVersion}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  runtime.detailsLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: foregroundColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  runtime.source.isEmpty
                      ? runtime.executable
                      : '${runtime.source} · ${runtime.executable}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(fontSize: 10, color: mutedColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: selected ? null : () => onSelect(runtime.executable),
            child: Text(selected ? '已设为默认' : '设为默认'),
          ),
        ],
      ),
    );
  }
}
