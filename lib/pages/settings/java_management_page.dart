import 'dart:io';

import 'package:flutter/material.dart';

import '../../../services/java/java_service.dart';
import '../launcher/controllers/java_environment_controller.dart';
import '../launcher/launcher_palette.dart';

/// Standalone Java management page.
///
/// It only lists detected runtimes, starts a scan, adds a custom executable and
/// removes list entries. Choosing the default Java belongs to the global
/// settings page, so nothing here touches the selection.
class JavaManagementPage extends StatefulWidget {
  const JavaManagementPage({
    super.key,
    required this.palette,
    required this.java,
    required this.onDiscover,
    required this.onPick,
    required this.onRemove,
    required this.onMessage,
    required this.onBack,
  });

  final LauncherPalette palette;
  final JavaEnvironmentController java;
  final VoidCallback onDiscover;
  final VoidCallback onPick;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onMessage;

  /// Restores the settings content; this page is embedded in the settings tab
  /// so the launcher sidebar and header stay visible.
  final VoidCallback onBack;

  @override
  State<JavaManagementPage> createState() => _JavaManagementPageState();
}

class _JavaManagementPageState extends State<JavaManagementPage> {
  final TextEditingController _pathController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _applyTypedPath() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      widget.onMessage('请先填写 Java 可执行文件的完整路径。');
      return;
    }
    if (!await File(path).exists()) {
      widget.onMessage('Java 可执行文件不存在：$path');
      return;
    }
    setState(() => _isAdding = true);
    final runtime = await widget.java.registerExecutable(path);
    if (!mounted) return;
    setState(() => _isAdding = false);
    if (runtime == null) {
      widget.onMessage('无法识别该 Java，请确认路径指向 java.exe。');
      return;
    }
    _pathController.clear();
    widget.onMessage('已添加到 Java 列表：${runtime.executable}');
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回设置',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Java 管理',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: widget.java,
              builder: (context, _) {
                final java = widget.java;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
              Text(
                '扫描本机 Java 或手动添加可执行文件。此页面只维护列表，'
                '默认使用哪个 Java 请在设置页的 Java 下拉框中选择。',
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: java.isLoading ? null : widget.onDiscover,
                    icon: const Icon(Icons.manage_search_rounded, size: 16),
                    label: const Text('自动扫描'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onPick,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('手动添加路径'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (java.isLoading) const LinearProgressIndicator(minHeight: 2),
              if (java.loadError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    java.loadError!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE05B5B),
                    ),
                  ),
                ),
              if (!java.isLoading && java.runtimes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    java.hasSearched
                        ? '未检测到可用 Java，请手动添加路径。'
                        : '尚未扫描 Java，点击“自动扫描”开始。',
                    style: TextStyle(fontSize: 11.5, color: palette.muted),
                  ),
                )
              else
                for (final runtime in java.runtimes)
                  _buildRuntimeTile(runtime, palette),
              const SizedBox(height: 18),
              _buildCustomPathCard(palette),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuntimeTile(JavaRuntime runtime, LauncherPalette palette) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: palette.panelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.panelBorderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: palette.uiColors.accent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              runtime.majorVersion == 0
                  ? 'Java ?'
                  : 'Java ${runtime.majorVersion}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              runtime.executable,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: palette.muted),
            ),
          ),
          IconButton(
            tooltip: '从列表移除（不会删除本地文件）',
            onPressed: () => widget.onRemove(runtime.executable),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: palette.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomPathCard(LauncherPalette palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.panelBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '手动添加 Java 路径',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '填写 java.exe 的完整路径；仅加入列表，不会自动设为默认。',
            style: TextStyle(fontSize: 10.5, color: palette.muted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pathController,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: r'例如 C:\Program Files\Java\jdk-17\bin\java.exe',
              hintStyle: TextStyle(fontSize: 11.5, color: palette.muted),
              border: const OutlineInputBorder(),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton(
                  onPressed: _isAdding ? null : _applyTypedPath,
                  child: Text(_isAdding ? '检测中…' : '添加'),
                ),
              ),
            ),
            onSubmitted: (_) => _applyTypedPath(),
          ),
        ],
      ),
    );
  }
}
