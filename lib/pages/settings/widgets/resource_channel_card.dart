import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/installer/version_parser.dart';
import '../../../services/network/models.dart';
import '../../launcher/launcher_palette.dart';

/// Resource channel used for mod / resource downloads (placeholder).
enum ModResourceSource { standard, mcim }

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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<MinecraftDownloadSource>(
          initialValue: downloadSource,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.channelClientSource,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final source in MinecraftDownloadSource.values)
              DropdownMenuItem<MinecraftDownloadSource>(
                value: source,
                child: Text(
                  _sourceLabel(source, l10n),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onDownloadSourceChanged(value);
          },
        ),
        const SizedBox(height: 6),
        Text(
          l10n.channelClientSourceHint,
          style: TextStyle(fontSize: 10.5, color: muted),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<ModResourceSource>(
          key: ValueKey('mod-source-$mcimEnabled'),
          initialValue: mcimEnabled
              ? ModResourceSource.mcim
              : ModResourceSource.standard,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.channelModSource,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final source in ModResourceSource.values)
              DropdownMenuItem<ModResourceSource>(
                value: source,
                child: Text(
                  _modSourceLabel(source, l10n),
                  style: const TextStyle(fontSize: 12),
                ),
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
          l10n.channelMcimHint,
          style: TextStyle(fontSize: 10.5, color: muted),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<AggregatePreference>(
          initialValue: aggregatePreference,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.channelAggregate,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final preference in AggregatePreference.values)
              DropdownMenuItem<AggregatePreference>(
                value: preference,
                child: Text(
                  _aggregateLabel(preference, l10n),
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
          l10n.channelAggregateHint,
          style: TextStyle(fontSize: 10.5, color: muted),
        ),
      ],
    );
  }

  String _sourceLabel(MinecraftDownloadSource source, AppLocalizations l10n) =>
      switch (source) {
        MinecraftDownloadSource.mojang => l10n.sourceMojang,
        MinecraftDownloadSource.bmclapi => l10n.sourceBmclapi,
      };

  String _modSourceLabel(ModResourceSource source, AppLocalizations l10n) =>
      switch (source) {
        ModResourceSource.standard => l10n.actionDefault,
        ModResourceSource.mcim => l10n.sourceMcim,
      };

  String _aggregateLabel(
    AggregatePreference preference,
    AppLocalizations l10n,
  ) => switch (preference) {
    AggregatePreference.balanced => l10n.aggregateBalanced,
    AggregatePreference.modrinth => l10n.aggregateModrinth,
    AggregatePreference.curseForge => l10n.aggregateCurseForge,
  };
}
