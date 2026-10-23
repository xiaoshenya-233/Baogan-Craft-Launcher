import 'package:flutter/material.dart';

import '../../widgets/client_tile.dart';

/// UI-only colors shared by the launcher pages and chrome.
class LauncherPalette {
  const LauncherPalette({
    required this.dark,
    required this.uiColors,
    required this.muted,
    required this.buttonForeground,
    required this.panelColor,
    required this.panelBorderColor,
    required this.panelAccentColor,
    required this.selectedSurfaceColor,
    required this.selectedForegroundColor,
    required this.moddedSurfaceColor,
    required this.moddedForegroundColor,
  });

  factory LauncherPalette.fromDark(bool dark) {
    return LauncherPalette(
      dark: dark,
      uiColors: LauncherUiColors.fromDark(dark),
      muted: dark ? const Color(0xFF9AA397) : const Color(0xFF52614F),
      buttonForeground: dark
          ? const Color(0xFFDDE5D8)
          : const Color(0xFF26351F),
      panelColor: dark ? const Color(0xD91B211B) : const Color(0xD9F8FAF6),
      panelBorderColor: dark
          ? const Color(0xFF2A3228)
          : const Color(0xFFD8E0D2),
      panelAccentColor: dark
          ? const Color(0xFF303C2C)
          : const Color(0xFFE3EEDB),
      selectedSurfaceColor: dark
          ? const Color(0xFF34452D)
          : const Color(0xFFDDEBD1),
      selectedForegroundColor: dark
          ? const Color(0xFFC4E8A0)
          : const Color(0xFF34452D),
      moddedSurfaceColor: dark
          ? const Color(0xFF40352A)
          : const Color(0xFFF2E7D5),
      moddedForegroundColor: dark
          ? const Color(0xFFE0B779)
          : const Color(0xFF795522),
    );
  }

  final bool dark;
  final LauncherUiColors uiColors;
  final Color muted;
  final Color buttonForeground;
  final Color panelColor;
  final Color panelBorderColor;
  final Color panelAccentColor;
  final Color selectedSurfaceColor;
  final Color selectedForegroundColor;
  final Color moddedSurfaceColor;
  final Color moddedForegroundColor;
}
