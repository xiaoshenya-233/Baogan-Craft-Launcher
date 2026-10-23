import 'package:flutter/material.dart';

import '../../../core/preferences_store.dart';
import '../../../services/java/java_service.dart';
import '../../launcher/launcher_palette.dart';

/// "全局游戏默认设置" card: default Java runtime and default memory.
///
/// The Java dropdown is the single place that owns the global default; its
/// first entry is always `auto` ("根据游戏版本自动设定").
class GameDefaultsCard extends StatefulWidget {
  const GameDefaultsCard({
    super.key,
    required this.palette,
    required this.runtimes,
    required this.selectedExecutable,
    required this.onJavaSelected,
    this.initialMemoryGb = 4,
    this.maxMemoryGb = 16,
  });

  final LauncherPalette palette;
  final List<JavaRuntime> runtimes;
  final String? selectedExecutable;
  final ValueChanged<String> onJavaSelected;
  final double initialMemoryGb;
  final double maxMemoryGb;

  @override
  State<GameDefaultsCard> createState() => _GameDefaultsCardState();
}

class _GameDefaultsCardState extends State<GameDefaultsCard> {
  late double _memoryGb = widget.initialMemoryGb.clamp(
    1,
    widget.maxMemoryGb,
  );

  @override
  Widget build(BuildContext context) {
    final muted = widget.palette.muted;
    final stored = widget.selectedExecutable?.trim() ?? '';
    final current = stored.isEmpty ? PreferencesStore.autoJavaValue : stored;
    final isKnown = widget.runtimes.any(
      (runtime) => runtime.executable == current,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '这些默认值用于新建客户端；已单独配置的客户端仍使用各自的设置。',
          style: TextStyle(fontSize: 11, color: muted),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('default-java-$current'),
          initialValue: current,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '默认 Java',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: PreferencesStore.autoJavaValue,
              child: Text('根据游戏版本自动设定', style: TextStyle(fontSize: 12)),
            ),
            if (!isKnown && current != PreferencesStore.autoJavaValue)
              DropdownMenuItem<String>(
                value: current,
                child: Text(
                  current,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            for (final runtime in widget.runtimes)
              DropdownMenuItem<String>(
                value: runtime.executable,
                child: Text(
                  '${runtime.displayName} · Java ${runtime.majorVersion}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) widget.onJavaSelected(value);
          },
        ),
        const SizedBox(height: 6),
        Text(
          '选择「根据游戏版本自动设定」时，启动器会按客户端声明的 Java 版本自动匹配。',
          style: TextStyle(fontSize: 10.5, color: muted),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                '默认内存分配',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${_memoryGb.round()} GB',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
        Slider(
          value: _memoryGb,
          min: 1,
          max: widget.maxMemoryGb,
          divisions: (widget.maxMemoryGb - 1).round(),
          label: '${_memoryGb.round()} GB',
          onChanged: (value) => setState(() => _memoryGb = value),
        ),
        Text(
          '仅用于界面占位，尚未写入启动参数。',
          style: TextStyle(fontSize: 10, color: muted),
        ),
      ],
    );
  }
}
