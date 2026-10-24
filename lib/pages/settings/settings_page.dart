import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/launcher_log.dart';
import '../../core/platform_launcher.dart';
import '../../core/preferences_store.dart';
import '../../l10n/app_localizations.dart';
import '../../services/installer/game_installer.dart';
import '../../services/network/api_service.dart';
import '../../widgets/category_anchor_bar.dart';
import '../../widgets/launcher/launcher_common.dart';
import '../../widgets/wallpaper/wallpaper_background.dart';
import '../launcher/controllers/appearance_controller.dart';
import '../launcher/controllers/java_environment_controller.dart';
import '../launcher/launcher_palette.dart';
import 'java_management_page.dart';
import 'widgets/about_dialog.dart';
import 'widgets/game_defaults_card.dart';
import 'widgets/java_summary_card.dart';
import 'widgets/resource_channel_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.appearance,
    required this.java,
    required this.preferences,
    required this.isDark,
    required this.downloadSource,
    required this.aggregatePreference,
    required this.mcimEnabled,
    required this.onMcimEnabledChanged,
    required this.debugLoggingEnabled,
    required this.debugLogWindowOpen,
    required this.onDownloadSourceChanged,
    required this.onAggregatePreferenceChanged,
    required this.onDebugLoggingChanged,
    required this.onOpenDebugLogWindow,
    required this.onCloseDebugLogWindow,
    required this.onRecordState,
    required this.onChooseWallpaper,
    required this.onRecropWallpaper,
    required this.onResetWallpaper,
    required this.onDiscoverJava,
    required this.onPickJava,
    required this.onSelectJava,
    required this.onMessage,
  });

  final AppearanceController appearance;
  final JavaEnvironmentController java;
  final PreferencesStore preferences;
  final bool isDark;
  final MinecraftDownloadSource downloadSource;
  final AggregatePreference aggregatePreference;
  final bool mcimEnabled;
  final ValueChanged<bool> onMcimEnabledChanged;
  final bool debugLoggingEnabled;
  final bool debugLogWindowOpen;
  final ValueChanged<MinecraftDownloadSource> onDownloadSourceChanged;
  final ValueChanged<AggregatePreference> onAggregatePreferenceChanged;
  final ValueChanged<bool> onDebugLoggingChanged;
  final VoidCallback onOpenDebugLogWindow;
  final VoidCallback onCloseDebugLogWindow;
  final VoidCallback onRecordState;
  final ValueChanged<bool> onChooseWallpaper;
  final ValueChanged<bool> onRecropWallpaper;
  final ValueChanged<bool> onResetWallpaper;
  final VoidCallback onDiscoverJava;
  final VoidCallback onPickJava;
  final ValueChanged<String> onSelectJava;
  final ValueChanged<String> onMessage;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// Stable section ids; display labels come from the localization files.
  static const List<String> _sectionIds = <String>[
    'gameDefaults',
    'channels',
    'appearance',
    'java',
    'debug',
    'about',
  ];

  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{
    for (final id in _sectionIds) id: GlobalKey(debugLabel: id),
  };

  String _sectionLabel(String id, AppLocalizations l10n) => switch (id) {
    'gameDefaults' => l10n.settingsSectionGameDefaults,
    'channels' => l10n.settingsSectionChannels,
    'appearance' => l10n.settingsSectionAppearance,
    'java' => l10n.settingsSectionJava,
    'debug' => l10n.settingsSectionDebug,
    _ => l10n.settingsSectionAbout,
  };

  /// When true the tab shows the embedded Java management page instead of the
  /// settings cards, keeping the launcher sidebar and header in place.
  bool _showJavaManagement = false;

  LauncherPalette get _palette => LauncherPalette.fromDark(widget.isDark);
  bool get _usesDarkPalette => widget.isDark;
  Color get _muted => _palette.muted;
  Color get _panelBorderColor => _palette.panelBorderColor;
  Color get _selectedSurfaceColor => _palette.selectedSurfaceColor;
  Color get _selectedForegroundColor => _palette.selectedForegroundColor;

  void _showVersionMessage(String message) => widget.onMessage(message);

  String _appearanceModeLabel(
    LauncherAppearanceMode mode,
    AppLocalizations l10n,
  ) => switch (mode) {
    LauncherAppearanceMode.dark => l10n.settingsThemeDark,
    LauncherAppearanceMode.light => l10n.settingsThemeLight,
    LauncherAppearanceMode.automatic => l10n.settingsThemeAuto,
  };

  Widget _translucentButton(Widget button, {double radius = 10}) {
    return TranslucentButtonSurface(radius: radius, child: button);
  }

  Widget _buildBgucSection({
    required String title,
    required IconData icon,
    required Widget child,
    String? anchor,
  }) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _palette.panelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _palette.uiColors.accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
    final key = anchor == null ? null : _sectionKeys[anchor];
    return key == null ? content : KeyedSubtree(key: key, child: content);
  }

  void _openJavaManagementPage() {
    setState(() => _showJavaManagement = true);
  }

  void _closeJavaManagementPage() {
    setState(() => _showJavaManagement = false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: ValueKey<bool>(_showJavaManagement),
          child: _buildSettings(),
        ),
      ),
    );
  }

  Widget _buildSettings() {
    final l10n = AppLocalizations.of(context)!;
    if (_showJavaManagement) {
      return JavaManagementPage(
        palette: _palette,
        java: widget.java,
        onDiscover: widget.onDiscoverJava,
        onPick: widget.onPickJava,
        onRemove: (executable) {
          widget.java.removeRuntime(executable);
          widget.onMessage(l10n.settingsJavaRemoved(executable));
        },
        onMessage: widget.onMessage,
        onBack: _closeJavaManagementPage,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final content = SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 36,
            30,
            compact ? 20 : 36,
            96,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.navSettings,
                    style: TextStyle(
                      fontSize: compact ? 26 : 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.settingsSubtitle,
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  _buildBgucSection(
                    title: l10n.settingsSectionGameDefaults,
                    anchor: 'gameDefaults',
                    icon: Icons.tune_rounded,
                    child: GameDefaultsCard(
                      palette: _palette,
                      runtimes: widget.java.runtimes,
                      selectedExecutable: widget.java.selectedExecutable,
                      onJavaSelected: widget.onSelectJava,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBgucSection(
                    title: l10n.settingsSectionChannels,
                    anchor: 'channels',
                    icon: Icons.cloud_download_outlined,
                    child: ResourceChannelCard(
                      palette: _palette,
                      downloadSource: widget.downloadSource,
                      aggregatePreference: widget.aggregatePreference,
                      mcimEnabled: widget.mcimEnabled,
                      onMcimEnabledChanged: widget.onMcimEnabledChanged,
                      onDownloadSourceChanged: widget.onDownloadSourceChanged,
                      onAggregatePreferenceChanged:
                          widget.onAggregatePreferenceChanged,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBgucSection(
                    title: l10n.settingsSectionAppearance,
                    anchor: 'appearance',
                    icon: Icons.palette_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsThemeMode,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          l10n.settingsThemeModeHint,
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: LauncherAppearanceMode.values.map((mode) {
                            final selected =
                                widget.appearance.appearanceMode == mode;
                            return _translucentButton(
                              ChoiceChip(
                                avatar: Icon(
                                  mode.icon,
                                  size: 16,
                                  color: selected
                                      ? _selectedForegroundColor
                                      : _usesDarkPalette
                                      ? _muted
                                      : const Color(0xFF52614F),
                                ),
                                label: Text(_appearanceModeLabel(mode, l10n)),
                                selected: selected,
                                onSelected: (_) =>
                                    widget.appearance.setAppearanceMode(mode),
                                selectedColor: _selectedSurfaceColor,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: selected
                                      ? _selectedForegroundColor
                                      : _muted,
                                ),
                                showCheckmark: false,
                              ),
                              radius: 22,
                            );
                          }).toList(),
                        ),
                        if (widget.appearance.appearanceMode ==
                            LauncherAppearanceMode.automatic) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _usesDarkPalette
                                  ? const Color(0x22101510)
                                  : const Color(0xFFF1F4ED),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _panelBorderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.settingsTimeZone(
                                    widget.appearance.formatOffset(
                                      DateTime.now().timeZoneOffset,
                                    ),
                                    widget.appearance
                                        .estimatedLongitude()
                                        .toStringAsFixed(1),
                                  ),
                                  style: TextStyle(fontSize: 11, color: _muted),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.settingsSolarApprox,
                                  style: TextStyle(fontSize: 10, color: _muted),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  l10n.settingsSunriseSunset(
                                    widget.appearance.formatMinutes(
                                      widget.appearance.sunriseMinute,
                                    ),
                                    widget.appearance.formatMinutes(
                                      widget.appearance.sunsetMinute,
                                    ),
                                    widget.appearance.solarTimesOnline
                                        ? l10n.settingsSolarOnline
                                        : l10n.settingsSolarDefault,
                                  ),
                                  style: TextStyle(fontSize: 11),
                                ),
                                if (widget.appearance.solarTimesError !=
                                    null) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    l10n.settingsSolarError(
                                      widget.appearance.solarTimesError!,
                                    ),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                                if (widget.appearance.isLoadingSolarTimes) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    l10n.settingsCheckingSolar,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _translucentButton(
                                    TextButton.icon(
                                      onPressed:
                                          widget.appearance.isLoadingSolarTimes
                                          ? null
                                          : () {
                                              unawaited(
                                                widget.appearance
                                                    .loadSolarTimes(),
                                              );
                                            },
                                      icon: Icon(
                                        Icons.refresh_rounded,
                                        size: 16,
                                      ),
                                      label: Text(l10n.settingsRefreshSolar),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Divider(color: _panelBorderColor),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.settingsLanguage,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          AppLocalizations.of(context)!.settingsLanguageHint,
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                        const SizedBox(height: 10),
                        _buildLanguageSelector(),
                        const SizedBox(height: 24),
                        Divider(color: _panelBorderColor),
                        const SizedBox(height: 16),
                        Text(
                          l10n.settingsWallpaper,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          l10n.settingsWallpaperHint,
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                        const SizedBox(height: 14),
                        _buildWallpaperModeControls(dark: false),
                        const SizedBox(height: 12),
                        _buildWallpaperModeControls(dark: true),
                        const SizedBox(height: 12),
                        _buildWallpaperStartupOption(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBgucSection(
                    title: l10n.settingsSectionJava,
                    anchor: 'java',
                    icon: Icons.memory_rounded,
                    child: JavaSummaryCard(
                      palette: _palette,
                      runtimes: widget.java.runtimes,
                      isLoading: widget.java.isLoading,
                      error: widget.java.loadError,
                      selectedExecutable: widget.java.selectedExecutable,
                      onManage: _openJavaManagementPage,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDebugLogSettings(),
                  const SizedBox(height: 14),
                  _buildAboutSection(),
                ],
              ),
            ),
          ),
        );
        return Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: CategoryAnchorBar(
                  anchors: {
                    for (final entry in _sectionKeys.entries)
                      _sectionLabel(entry.key, l10n): entry.value,
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageSelector() {
    final l10n = AppLocalizations.of(context)!;
    final currentCode = widget.appearance.locale.languageCode;
    final selectedCode =
        PreferencesStore.supportedLanguages.contains(currentCode)
        ? currentCode
        : PreferencesStore.defaultLanguage;
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 220,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: _usesDarkPalette
                ? const Color(0x22101510)
                : const Color(0xFFF1F4ED),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _panelBorderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedCode,
              isDense: true,
              isExpanded: true,
              borderRadius: BorderRadius.circular(10),
              dropdownColor: _palette.panelColor,
              icon: Icon(Icons.expand_more_rounded, size: 18, color: _muted),
              style: TextStyle(
                fontSize: 12,
                color: _usesDarkPalette
                    ? Colors.white
                    : const Color(0xFF26351F),
              ),
              items: [
                DropdownMenuItem(
                  value: 'zh',
                  child: Text(l10n.settingsLanguageZh),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(l10n.settingsLanguageEn),
                ),
              ],
              onChanged: (code) {
                if (code == null) return;
                widget.appearance.setLocale(Locale(code));
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    final l10n = AppLocalizations.of(context)!;
    return _buildBgucSection(
      title: l10n.settingsSectionAbout,
      anchor: 'about',
      icon: Icons.info_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.aboutVersion(launcherVersion),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.aboutLicenseDescription,
            style: TextStyle(fontSize: 11, color: _muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => showAboutLauncherDialog(context),
                icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
                label: Text(l10n.aboutLicenseButton),
              ),
              _translucentButton(
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await PlatformLauncher.openUrl(launcherRepoUrl);
                    } on Object catch (error) {
                      _showVersionMessage(
                        l10n.settingsOpenBrowserFailed('$error'),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: Text(l10n.aboutRepoButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugLogSettings() {
    final l10n = AppLocalizations.of(context)!;
    final logPath = LauncherLog.filePath;
    return _buildBgucSection(
      title: l10n.settingsSectionDebug,
      anchor: 'debug',
      icon: Icons.bug_report_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsDebugMode,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.settingsDebugDescription,
                      style: TextStyle(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Switch(
                value: widget.debugLoggingEnabled,
                onChanged: widget.onDebugLoggingChanged,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            logPath ?? l10n.settingsLogNotReady,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: _muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _translucentButton(
                OutlinedButton.icon(
                  onPressed: widget.debugLoggingEnabled
                      ? () => widget.onOpenDebugLogWindow()
                      : null,
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: Text(l10n.settingsOpenLogWindow),
                ),
              ),
              _translucentButton(
                OutlinedButton.icon(
                  onPressed: logPath == null
                      ? null
                      : () async {
                          try {
                            await File(logPath).parent.create(recursive: true);
                            await openLocalDirectory(File(logPath).parent.path);
                          } catch (error) {
                            _showVersionMessage(
                              l10n.settingsOpenLogFailed('$error'),
                            );
                          }
                        },
                  icon: const Icon(Icons.folder_open_outlined, size: 17),
                  label: Text(l10n.settingsOpenLogFolder),
                ),
              ),
              _translucentButton(
                OutlinedButton.icon(
                  onPressed: widget.debugLoggingEnabled
                      ? widget.onRecordState
                      : null,
                  icon: const Icon(Icons.note_add_outlined, size: 17),
                  label: Text(l10n.settingsRecordState),
                ),
              ),
              if (widget.debugLogWindowOpen)
                _translucentButton(
                  OutlinedButton.icon(
                    onPressed: () => widget.onCloseDebugLogWindow(),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: Text(l10n.settingsCloseLogWindow),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperStartupOption() {
    final random = widget.appearance.randomWallpaperOnStartup;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _usesDarkPalette
            ? const Color(0x66101510)
            : const Color(0xFFF1F4ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _panelBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '壁纸启动方式',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('固定当前壁纸'),
                selected: !random,
                showCheckmark: false,
                onSelected: (_) => unawaited(
                  widget.appearance.setRandomWallpaperOnStartup(false),
                ),
              ),
              ChoiceChip(
                label: const Text('启动时随机抽取'),
                selected: random,
                showCheckmark: false,
                onSelected: (_) => unawaited(
                  widget.appearance.setRandomWallpaperOnStartup(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showWallpaperManager({required bool dark}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final paths = widget.appearance.wallpaperPaths(dark);
          final active = widget.appearance.wallpaperPath(dark);
          final scheme = Theme.of(context).colorScheme;
          return Container(
            height: MediaQuery.sizeOf(context).height * 0.68,
            decoration: BoxDecoration(
              color: _usesDarkPalette
                  ? const Color(0xFF151B14)
                  : const Color(0xFFF7FAF4),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: Border.all(color: _panelBorderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    color: scheme.primary,
                  ),
                  title: Text(
                    dark ? '深色壁纸管理' : '浅色壁纸管理',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                Divider(height: 1, color: _panelBorderColor),
                Expanded(
                  child: paths.isEmpty
                      ? Center(
                          child: Text(
                            '暂无壁纸，点击下方添加。',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: paths.length,
                          itemBuilder: (context, index) {
                            final path = paths[index];
                            final selected = path == active;
                            return RepaintBoundary(
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                color: selected
                                    ? scheme.primaryContainer.withValues(
                                        alpha: 0.45,
                                      )
                                    : _palette.panelColor,
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.file(
                                      File(path),
                                      width: 56,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => SizedBox(
                                        width: 56,
                                        height: 40,
                                        child: ColoredBox(
                                          color: _palette.panelAccentColor,
                                          child: const Icon(
                                            Icons.broken_image_outlined,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    path.split(RegExp(r'[\\/]')).last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  subtitle: selected
                                      ? Text(
                                          '当前壁纸',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: scheme.primary,
                                          ),
                                        )
                                      : null,
                                  trailing: IconButton(
                                    tooltip: '删除壁纸',
                                    onPressed: () async {
                                      await widget.appearance.removeWallpaper(
                                        dark: dark,
                                        path: path,
                                      );
                                      if (sheetContext.mounted) {
                                        setSheetState(() {});
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                    ),
                                  ),
                                  onTap: () async {
                                    await widget.appearance.selectWallpaper(
                                      dark: dark,
                                      path: path,
                                    );
                                    if (sheetContext.mounted) {
                                      setSheetState(() {});
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        widget.onChooseWallpaper(dark);
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('添加壁纸'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _wallpaperModeLabel(
    WallpaperDisplayMode mode,
    AppLocalizations l10n,
  ) => switch (mode) {
    WallpaperDisplayMode.cover => l10n.settingsWallpaperCover,
    WallpaperDisplayMode.stretch => l10n.settingsWallpaperStretch,
    WallpaperDisplayMode.zoom => l10n.settingsWallpaperZoom,
  };

  Widget _buildWallpaperModeControls({required bool dark}) {
    final l10n = AppLocalizations.of(context)!;
    final path = dark
        ? widget.appearance.darkWallpaperPath
        : widget.appearance.lightWallpaperPath;
    final displayMode = dark
        ? widget.appearance.darkWallpaperDisplayMode
        : widget.appearance.lightWallpaperDisplayMode;
    final modeLabel = dark
        ? l10n.settingsDarkWallpaper
        : l10n.settingsLightWallpaper;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _usesDarkPalette
            ? const Color(0x66101510)
            : const Color(0xFFF1F4ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _panelBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            modeLabel,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            path ?? l10n.settingsWallpaperNone,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: _muted),
          ),
          if (path != null) ...[
            const SizedBox(height: 12),
            Text(
              l10n.settingsWallpaperEffect,
              style: TextStyle(fontSize: 11, color: _muted),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WallpaperDisplayMode.values.map((mode) {
                final selected = displayMode == mode;
                return _translucentButton(
                  ChoiceChip(
                    label: Text(_wallpaperModeLabel(mode, l10n)),
                    selected: selected,
                    onSelected: (_) => widget.appearance
                        .setWallpaperDisplayMode(dark: dark, mode: mode),
                    selectedColor: _selectedSurfaceColor,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: selected ? _selectedForegroundColor : _muted,
                    ),
                    showCheckmark: false,
                  ),
                  radius: 22,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => widget.onChooseWallpaper(dark),
                icon: Icon(Icons.wallpaper_outlined),
                label: Text(
                  path == null
                      ? l10n.settingsChooseImage
                      : l10n.settingsChangeImage,
                ),
              ),
              _translucentButton(
                OutlinedButton.icon(
                  onPressed: () => _showWallpaperManager(dark: dark),
                  icon: const Icon(Icons.collections_outlined),
                  label: Text(
                    '管理壁纸 (${widget.appearance.wallpaperPaths(dark).length})',
                  ),
                ),
              ),
              if (path != null)
                _translucentButton(
                  OutlinedButton.icon(
                    onPressed: () => widget.onRecropWallpaper(dark),
                    icon: Icon(Icons.crop_outlined),
                    label: Text(l10n.settingsRecrop),
                  ),
                ),
              if (path != null)
                _translucentButton(
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.onResetWallpaper(dark);
                      _showVersionMessage(
                        l10n.settingsResetDone(
                          dark
                              ? l10n.settingsThemeDark
                              : l10n.settingsThemeLight,
                        ),
                      );
                    },
                    icon: Icon(Icons.restart_alt_rounded),
                    label: Text(l10n.settingsResetWallpaper),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
