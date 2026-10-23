import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/launcher_log.dart';
import '../../core/platform_launcher.dart';
import '../../core/preferences_store.dart';
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
  static const List<String> _sectionTitles = <String>[
    '全局游戏默认设置',
    '游戏资源获取渠道',
    '个性化与主题',
    'Java 管理',
    '调试与日志',
    '关于与鸣谢',
  ];

  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{
    for (final title in _sectionTitles) title: GlobalKey(debugLabel: title),
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
    if (_showJavaManagement) {
      return JavaManagementPage(
        palette: _palette,
        java: widget.java,
        onDiscover: widget.onDiscoverJava,
        onPick: widget.onPickJava,
        onRemove: (executable) {
          widget.java.removeRuntime(executable);
          widget.onMessage('已从 Java 列表移除：$executable');
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
                    '设置',
                    style: TextStyle(
                      fontSize: compact ? 26 : 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '自定义启动器外观与使用体验。',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  _buildBgucSection(
                    title: '全局游戏默认设置',
                    anchor: '全局游戏默认设置',
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
                    title: '游戏资源获取渠道',
                    anchor: '游戏资源获取渠道',
                    icon: Icons.cloud_download_outlined,
                    child: ResourceChannelCard(
                      palette: _palette,
                      downloadSource: widget.downloadSource,
                      aggregatePreference: widget.aggregatePreference,
                      mcimEnabled: widget.mcimEnabled,
                      onMcimEnabledChanged: widget.onMcimEnabledChanged,
                      onDownloadSourceChanged:
                          widget.onDownloadSourceChanged,
                      onAggregatePreferenceChanged:
                          widget.onAggregatePreferenceChanged,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBgucSection(
                    title: '个性化与主题',
                    anchor: '个性化与主题',
                    icon: Icons.palette_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '主题模式',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '自动模式根据本地时间和日出日落切换主题。',
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
                                label: Text(mode.label),
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
                                  '本地时区 UTC${widget.appearance.formatOffset(DateTime.now().timeZoneOffset)}'
                                  ' · 推算经度 ${widget.appearance.estimatedLongitude().toStringAsFixed(1)}°',
                                  style: TextStyle(fontSize: 11, color: _muted),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '位置仅按时区估算（纬度按赤道近似），仅供参考；联网失败时使用 06:30 / 18:30。',
                                  style: TextStyle(fontSize: 10, color: _muted),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '日出 ${widget.appearance.formatMinutes(widget.appearance.sunriseMinute)}'
                                  '  ·  日落 ${widget.appearance.formatMinutes(widget.appearance.sunsetMinute)}'
                                  '  ·  ${widget.appearance.solarTimesOnline ? '联网获取' : '默认时间'}',
                                  style: TextStyle(fontSize: 11),
                                ),
                                if (widget.appearance.solarTimesError !=
                                    null) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    '${widget.appearance.solarTimesError!}，当前使用 06:30 / 18:30。',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                                if (widget.appearance.isLoadingSolarTimes) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    '正在检测日出日落时间…',
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
                                      label: Text('刷新日出日落'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Divider(color: _panelBorderColor),
                        const SizedBox(height: 16),
                        Text(
                          '壁纸',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '分别为亮色和深色主题设置壁纸，切换主题时自动切换对应图片。',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                        const SizedBox(height: 14),
                        _buildWallpaperModeControls(dark: false),
                        const SizedBox(height: 12),
                        _buildWallpaperModeControls(dark: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBgucSection(
                    title: 'Java 管理',
                    anchor: 'Java 管理',
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
              child: Center(child: CategoryAnchorBar(anchors: _sectionKeys)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAboutSection() {
    return _buildBgucSection(
      title: '关于与鸣谢',
      anchor: '关于与鸣谢',
      icon: Icons.info_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Baogan Craft Launcher · 版本 $launcherVersion',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '本项目基于 GPLv3 协议开源，感谢 PCL2、HMCL、XMCL 与 BMCLAPI 等开源项目。',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => showAboutLauncherDialog(context),
                icon: const Icon(
                  Icons.volunteer_activism_outlined,
                  size: 18,
                ),
                label: const Text('开源协议与鸣谢'),
              ),
              _translucentButton(
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await PlatformLauncher.openUrl(launcherRepoUrl);
                    } on Object catch (error) {
                      _showVersionMessage('无法打开浏览器：$error');
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text('GitHub 仓库'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugLogSettings() {
    final logPath = LauncherLog.filePath;
    return _buildBgucSection(
      title: '调试与日志',
      anchor: '调试与日志',
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
                      '调试模式',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '默认开启。记录启动器操作、下载、版本扫描、启动参数和游戏进程输出；'
                      '日志窗口独立于启动器运行，便于观察完整过程。',
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
            logPath ?? '日志文件尚未初始化。',
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
                  label: const Text('打开日志窗口'),
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
                            _showVersionMessage('无法打开日志文件夹：$error');
                          }
                        },
                  icon: const Icon(Icons.folder_open_outlined, size: 17),
                  label: const Text('打开日志文件夹'),
                ),
              ),
              _translucentButton(
                OutlinedButton.icon(
                  onPressed: widget.debugLoggingEnabled
                      ? widget.onRecordState
                      : null,
                  icon: const Icon(Icons.note_add_outlined, size: 17),
                  label: const Text('记录当前状态'),
                ),
              ),
              if (widget.debugLogWindowOpen)
                _translucentButton(
                  OutlinedButton.icon(
                    onPressed: () => widget.onCloseDebugLogWindow(),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('关闭日志窗口'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperModeControls({required bool dark}) {
    final path = dark
        ? widget.appearance.darkWallpaperPath
        : widget.appearance.lightWallpaperPath;
    final displayMode = dark
        ? widget.appearance.darkWallpaperDisplayMode
        : widget.appearance.lightWallpaperDisplayMode;
    final modeLabel = dark ? '深色模式壁纸' : '亮色模式壁纸';

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
            path ?? '尚未选择；未设置时会暂用另一主题的壁纸。',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: _muted),
          ),
          if (path != null) ...[
            const SizedBox(height: 12),
            Text('壁纸效果', style: TextStyle(fontSize: 11, color: _muted)),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WallpaperDisplayMode.values.map((mode) {
                final selected = displayMode == mode;
                return _translucentButton(
                  ChoiceChip(
                    label: Text(mode.label),
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
                label: Text(path == null ? '选择图片' : '更换图片'),
              ),
              if (path != null)
                _translucentButton(
                  OutlinedButton.icon(
                    onPressed: () => widget.onRecropWallpaper(dark),
                    icon: Icon(Icons.crop_outlined),
                    label: Text('重新裁切'),
                  ),
                ),
              if (path != null)
                _translucentButton(
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.onResetWallpaper(dark);
                      _showVersionMessage('已恢复${dark ? '深色' : '亮色'}模式默认背景。');
                    },
                    icon: Icon(Icons.restart_alt_rounded),
                    label: Text('恢复默认'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
