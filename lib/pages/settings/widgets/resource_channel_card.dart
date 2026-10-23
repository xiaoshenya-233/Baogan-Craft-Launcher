import 'package:flutter/material.dart';

import '../../../services/installer/version_parser.dart';
import '../../../services/network/models.dart';
import '../../launcher/launcher_palette.dart';

/// Resource channel used for mod / resource downloads (placeholder).
enum ModResourceSource {
  standard('默认'),
  mcim('MCIM 镜像站');

  const ModResourceSource(this.label);

  final String label;
}

/// "游戏资源获取渠道" card: client download mirror, mod mirror, aggregate
/// preference. The mod mirror switch is persisted through [PreferencesStore].
class ResourceChannelCard extends StatelessWidget {
  const ResourceChannelCard({
    super.key,
    required this.palette,
    required this.downloadSource,
    required this.aggregatePreference,
    required this.mcimEnabled,
    required this.onMcimEnabledChanged,
    required this.onDownloadSourceChanged,
    required this.onAggregatePreferenceChanged,
  });

  final LauncherPalette palette;
  final MinecraftDownloadSource downloadSource;
  final AggregatePreference aggregatePreference;
  final bool mcimEnabled;
  final ValueChanged<bool> onMcimEnabledChanged;
  final ValueChanged<MinecraftDownloadSource> onDownloadSourceChanged;
  final ValueChanged<AggregatePreference> onAggregatePreferenceChanged;

  @override
  Widget build(BuildContext context) {
    final muted = palette.muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<MinecraftDownloadSource>(
          initialValue: downloadSource,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '客户端下载源',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final source in MinecraftDownloadSource.values)
              DropdownMenuItem<MinecraftDownloadSource>(
                value: source,
                child: Text(source.label, style: const TextStyle(fontSize: 12)),
              ),
          ],
          onChanged: (value) {
            if (value != null) onDownloadSourceChanged(value);
          },
        ),
        const SizedBox(height: 6),
        Text(
          '游戏文件下载来源；版本与加载器信息始终由 BMCLAPI 提供。',
          style: TextStyle(fontSize: 10.5, color: muted),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<ModResourceSource>(
          key: ValueKey('mod-source-$mcimEnabled'),
          initialValue: mcimEnabled
              ? ModResourceSource.mcim
              : ModResourceSource.standard,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '模组资源源',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final source in ModResourceSource.values)
              DropdownMenuItem<ModResourceSource>(
                value: source,
                child: Text(source.label, style: const TextStyle(fontSize: 12)),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              onMcimEnabledChanged(value == ModResourceSource.mcim);
            }
          },
        ),
        const SizedBox(height: 6),
        Text(
          '启用 MCIM 后 CurseForge 请求会走 mod.mcimirror.top 镜像。',
          style: TextStyle(fontSize: 10.5, color: muted),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<AggregatePreference>(
          initialValue: aggregatePreference,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '聚合搜索偏好',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final preference in AggregatePreference.values)
              DropdownMenuItem<AggregatePreference>(
                value: preference,
                child: Text(
                  preference.label,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onAggregatePreferenceChanged(value);
          },
        ),
        const SizedBox(height: 6),
        Text(
          '同一模组同时出现在 Modrinth 与 CurseForge 时，只保留偏向平台的一条。',
          style: TextStyle(fontSize: 10.5, color: muted),
        ),
      ],
    );
  }
}
