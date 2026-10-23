import 'package:flutter/material.dart';

import 'version_icon.dart';

/// UI-only palette shared by the home page dialogs and tiles.
class LauncherUiColors {
  const LauncherUiColors({
    required this.accent,
    required this.panel,
    required this.panelAccent,
    required this.selectedSurface,
    required this.border,
    required this.muted,
  });

  factory LauncherUiColors.fromDark(bool dark) {
    return dark
        ? const LauncherUiColors(
            accent: Color(0xFF8BC34A),
            panel: Color(0xD91B211B),
            panelAccent: Color(0xFF303C2C),
            selectedSurface: Color(0xFF34452D),
            border: Color(0xFF2A3228),
            muted: Color(0xFF9AA397),
          )
        : const LauncherUiColors(
            accent: Color(0xFF8BC34A),
            panel: Color(0xD9F8FAF6),
            panelAccent: Color(0xFFE3EEDB),
            selectedSurface: Color(0xFFDDEBD1),
            border: Color(0xFFD8E0D2),
            muted: Color(0xFF52614F),
          );
  }

  final Color accent;
  final Color panel;
  final Color panelAccent;
  final Color selectedSurface;
  final Color border;
  final Color muted;
}

/// Data required to render one installed client without exposing page models.
class ClientTileData {
  const ClientTileData({
    required this.id,
    required this.directoryPath,
    required this.minecraftLabel,
    required this.loaderLabel,
    required this.isModded,
    this.loaderType,
  });

  final String id;
  final String directoryPath;
  final String minecraftLabel;
  final String loaderLabel;
  final bool isModded;

  /// Raw loader tag (`Fabric`, `Forge`, `NeoForge`) used by [VersionIcon].
  final String? loaderType;
}

class ClientTile extends StatelessWidget {
  const ClientTile({
    super.key,
    required this.data,
    required this.selected,
    required this.colors,
    this.onTap,
  });

  final ClientTileData data;
  final bool selected;
  final LauncherUiColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.selectedSurface : colors.panelAccent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: selected ? colors.accent : colors.border),
          ),
          child: Row(
            children: [
              VersionIcon.forLoader(
                loaderType: data.loaderType,
                customLogoPath: VersionIcon.customLogoPathFor(
                  data.directoryPath,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.directoryPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: colors.muted),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _ClientTag(label: data.minecraftLabel, colors: colors),
                        _ClientTag(label: data.loaderLabel, colors: colors),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                size: 20,
                color: selected ? colors.accent : colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientTag extends StatelessWidget {
  const _ClientTag({required this.label, required this.colors});

  final String label;
  final LauncherUiColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: colors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
