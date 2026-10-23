import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:window_manager/window_manager.dart';

import '../core/launcher_log.dart';
import '../core/path_manager.dart';
import '../core/path_utils.dart';
import '../core/platform_launcher.dart';
import '../core/preferences_store.dart';
import '../l10n/app_localizations.dart';
import '../widgets/download/active_download_banner.dart';
import 'launcher/controllers/appearance_controller.dart';
import 'launcher/controllers/auth_controller.dart';
import 'launcher/controllers/download_activity_controller.dart';
import 'launcher/controllers/java_environment_controller.dart';
import 'launcher/controllers/launcher_environment_controller.dart';
import 'downloads/controllers/minecraft_download_controller.dart';
import 'downloads/controllers/minecraft_download_types.dart';
import 'downloads/controllers/resource_download_controller.dart';
import 'downloads/download_tasks_page.dart';
import 'downloads/controllers/resource_download_actions.dart';
import 'downloads/minecraft_download_page.dart';
import 'downloads/resource_downloads_page.dart';
import 'launcher/controllers/launcher_shell_controller.dart';
import 'launcher/launcher_palette.dart';
import 'versions/controllers/version_catalog_controller.dart';
import 'versions/version_details_page.dart';
import 'versions/version_management_page.dart';
import 'launcher/launcher_shell.dart';
import 'launcher/launcher_sidebar.dart';
import 'launcher/launcher_top_bar.dart';
import 'launcher/workbench_page.dart';
import 'settings/settings_page.dart';

import '../services/download/download_service.dart';
import '../services/installer/client_settings.dart';
import '../services/installer/game_installer.dart';
import '../services/installer/version_models.dart';
import '../services/java/java_service.dart';
import '../services/launcher/authlib_injector.dart';
import '../services/launcher/game_launcher.dart';
import '../services/launcher/resource_scan_service.dart';
import '../services/launcher/server_service.dart';
import '../services/network/account_models.dart';
import '../services/network/api_service.dart';
import '../services/network/auth_service.dart';
import '../services/network/microsoft_connect_service.dart';
import '../services/translation/database_service.dart';
import '../services/translation/mod_search_service.dart';
import '../widgets/client_tile.dart';
import '../widgets/dialogs/client_config_sheet.dart';
import '../widgets/dialogs/client_picker_sheet.dart';
import '../widgets/dialogs/launch_failure_dialogs.dart';
import '../widgets/dialogs/login_method_sheet.dart';
import '../widgets/version_icon.dart';
import '../widgets/wallpaper/wallpaper_background.dart';
import '../widgets/wallpaper/wallpaper_crop_dialog.dart';
import 'home/widgets/account_manager_sheet.dart';

part 'home/home_views.dart';
part 'home/home_actions.dart';
part 'home/home_version_actions.dart';
part 'home/home_maintenance_actions.dart';
part 'home/home_install_actions.dart';
part 'home/home_install_helpers.dart';
part 'home/home_modpack_actions.dart';

const int _defaultSunriseMinute = 6 * 60 + 30;
const int _defaultSunsetMinute = 18 * 60 + 30;

/// 启动时由 main() 检测一次并确定；CN 或检测失败时锁定 Minecraft 客户端下载。
bool isDownloadLocked = false;

Future<void> _showDownloadLockedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('无法下载 Minecraft'),
      content: const Text('非常抱歉，为遵守当地的法律法规，当前暂无法提供 Minecraft 客户端下载服务。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

ThemeMode _automaticThemeModeAt(DateTime time) {
  final minutes = time.hour * 60 + time.minute;
  return minutes < _defaultSunriseMinute || minutes >= _defaultSunsetMinute
      ? ThemeMode.dark
      : ThemeMode.light;
}

final ValueNotifier<ThemeMode> launcherThemeMode = ValueNotifier(
  _automaticThemeModeAt(DateTime.now()),
);

class LauncherHomePage extends StatefulWidget {
  const LauncherHomePage({
    super.key,
    this.catalogService,
    this.downloadService,
  });

  final MinecraftCatalogService? catalogService;
  final MinecraftDownloadService? downloadService;

  @override
  State<LauncherHomePage> createState() => _LauncherHomePageState();
}

class _LauncherHomePageState extends State<LauncherHomePage> {
  static const _green = Color(0xFF8BC34A);
  final LauncherShellController _shell = LauncherShellController();
  final LauncherEnvironmentController _environment =
      LauncherEnvironmentController();
  final PreferencesStore _preferences = PreferencesStore();
  late final VersionCatalogController _catalog;
  late final JavaEnvironmentController _java;
  late final AuthController _auth;
  late final DownloadActivityController _downloads;
  late final AppearanceController _appearance;
  late final ResourceDownloadController _resourceDownloads;
  late final MinecraftDownloadController _minecraftDownloads;

  /// Localized strings for every `part` file of this library.
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  String get _minecraftPath => _environment.minecraftPath;
  List<String> get _minecraftSources => _environment.minecraftSources;
  List<LauncherVersion> get _versions => _catalog.versions;
  List<MinecraftVersion> get _localVersions => _catalog.localVersions;
  String? get _selectedLaunchVersionId => _catalog.selectedLaunchVersionId;
  String? get _preferredDownloadVersionId =>
      _catalog.preferredDownloadVersionId;
  bool get _isLoadingVersions => _catalog.isLoadingVersions;
  List<JavaRuntime> get _javaRuntimes => _java.runtimes;
  String? get _selectedJavaExecutable => _java.selectedExecutable;
  String get _customJavaPath => _java.customJavaPath;
  bool get _hasSearchedJava => _java.hasSearched;
  AuthMode get _launchAuthMode => _auth.mode;
  String get _offlinePlayerName => _auth.offlinePlayerName;

  String get _thirdPartyAuthServer => _auth.thirdPartyAuthServer;
  String? get _lightWallpaperPath => _appearance.lightWallpaperPath;
  String? get _darkWallpaperPath => _appearance.darkWallpaperPath;
  Rect get _lightWallpaperCrop => _appearance.lightWallpaperCrop;
  Rect get _darkWallpaperCrop => _appearance.darkWallpaperCrop;
  WallpaperDisplayMode get _lightWallpaperDisplayMode =>
      _appearance.lightWallpaperDisplayMode;
  WallpaperDisplayMode get _darkWallpaperDisplayMode =>
      _appearance.darkWallpaperDisplayMode;
  String? get _activeDownloadTask => _downloads.activeTask;
  set _activeDownloadTask(String? value) => _downloads.updateTask(value);
  DownloadCancellationToken? get _activeDownloadToken =>
      _downloads.cancellationToken;
  set _activeDownloadToken(DownloadCancellationToken? value) =>
      _downloads.setCancellation(value);
  bool get _canCancelActiveDownload => _downloads.canCancel;
  DownloadManager get _downloadManager => _downloads.manager;

  int _versionFilter = 0;
  String _versionSearchQuery = '';
  bool _mcimEnabled = false;
  final TextEditingController _minecraftClientNameController =
      TextEditingController();
  LauncherVersion? _selectedVersion;
  ClientLaunchSettings _selectedVersionSettings = const ClientLaunchSettings();

  ResourceSource get _resourceSource => _resourceDownloads.source;
  AggregatePreference get _aggregatePreference =>
      _resourceDownloads.aggregatePreference;
  set _aggregatePreference(AggregatePreference value) =>
      _resourceDownloads.aggregatePreference = value;
  CandidateManager get _candidateManager => _resourceDownloads.candidateManager;
  Set<String> get _candidatesToRemove => _resourceDownloads.candidatesToRemove;
  ModrinthProject? get _resourceDetailProject =>
      _resourceDownloads.detailProject;
  bool get _isDownloadingResources => _resourceDownloads.isDownloading;
  MinecraftLoader? get _selectedMinecraftLoader =>
      _minecraftDownloads.selectedLoader;
  String? get _selectedMinecraftVersion => _minecraftDownloads.selectedVersion;
  set _selectedMinecraftVersion(String? value) =>
      _minecraftDownloads.selectedVersion = value;
  List<MinecraftCatalogVersion> get _minecraftCatalog =>
      _minecraftDownloads.catalog;
  set _minecraftCatalog(List<MinecraftCatalogVersion> value) =>
      _minecraftDownloads.catalog = value;
  bool get _isLoadingMinecraftCatalog => _minecraftDownloads.isLoadingCatalog;
  set _isLoadingMinecraftCatalog(bool value) =>
      _minecraftDownloads.isLoadingCatalog = value;
  set _minecraftCatalogError(String? value) =>
      _minecraftDownloads.catalogError = value;
  Map<MinecraftLoader, List<String>> get _loaderVersions =>
      _minecraftDownloads.loaderVersions;
  Set<MinecraftLoader> get _loadingLoaderVersions =>
      _minecraftDownloads.loadingLoaderVersions;
  Map<MinecraftLoader, String> get _loaderVersionErrors =>
      _minecraftDownloads.loaderVersionErrors;
  Map<MinecraftLoader, int> get _loaderRequestIds =>
      _minecraftDownloads.loaderRequestIds;
  int get _minecraftCatalogRequestId => _minecraftDownloads.catalogRequestId;
  set _minecraftCatalogRequestId(int value) =>
      _minecraftDownloads.catalogRequestId = value;
  MinecraftDownloadSource get _minecraftDownloadSource =>
      _minecraftDownloads.downloadSource;
  set _minecraftDownloadSource(MinecraftDownloadSource value) =>
      _minecraftDownloads.downloadSource = value;
  bool get _isInstallingMinecraft => _minecraftDownloads.isInstalling;
  set _isInstallingMinecraft(bool value) =>
      _minecraftDownloads.isInstalling = value;
  String? get _minecraftInstallStatus => _minecraftDownloads.installStatus;
  set _minecraftInstallStatus(String? value) =>
      _minecraftDownloads.installStatus = value;
  String? get _minecraftInstallError => _minecraftDownloads.installError;
  set _minecraftInstallError(String? value) =>
      _minecraftDownloads.installError = value;
  String? get _selectedLoaderVersion =>
      _minecraftDownloads.selectedLoaderVersion;
  set _selectedLoaderVersion(String? value) =>
      _minecraftDownloads.selectedLoaderVersion = value;
  final TextEditingController _javaPathController = TextEditingController();
  double _bgucMemoryGb = 6;
  double _maxMemoryGb = 16;
  String? _memoryDetectionError;
  bool _isLoadingManagedMods = false;
  bool _isDeletingVersion = false;
  bool _isVersionMaintenanceRunning = false;
  String? _versionMaintenanceStatus;
  DownloadCancellationToken? _versionMaintenanceCancellation;
  List<ManagedMod> _managedMods = [];
  bool _isChoosingDownloadClient = false;

  MinecraftAuthService get _minecraftAuthService =>
      MinecraftAuthService(minecraftPath: _minecraftPath);

  /// Cached Microsoft identity so repeated launches reuse the same session.
  AuthIdentity? _microsoftIdentity;
  final MinecraftLaunchRunner _launchRunner = const MinecraftLaunchRunner();
  final MinecraftLaunchDiagnostics _launchDiagnostics =
      const MinecraftLaunchDiagnostics();
  bool _isLaunching = false;
  bool _debugLoggingEnabled = true;
  Process? _debugLogProcess;
  bool _openingDebugLogWindow = false;

  bool get _isDarkTheme => launcherThemeMode.value == ThemeMode.dark;
  String? get _wallpaperPath =>
      (_isDarkTheme ? _darkWallpaperPath : _lightWallpaperPath) ??
      (_isDarkTheme ? _lightWallpaperPath : _darkWallpaperPath);
  Rect get _wallpaperCrop => _isDarkTheme
      ? (_darkWallpaperPath != null ? _darkWallpaperCrop : _lightWallpaperCrop)
      : (_lightWallpaperPath != null
            ? _lightWallpaperCrop
            : _darkWallpaperCrop);
  WallpaperDisplayMode get _wallpaperDisplayMode => _isDarkTheme
      ? (_darkWallpaperPath != null
            ? _darkWallpaperDisplayMode
            : _lightWallpaperDisplayMode)
      : (_lightWallpaperPath != null
            ? _lightWallpaperDisplayMode
            : _darkWallpaperDisplayMode);
  bool get _usesDarkPalette => _isDarkTheme;
  LauncherPalette get _palette => LauncherPalette.fromDark(_usesDarkPalette);
  LauncherUiColors get _uiColors => _palette.uiColors;
  Color get _muted => _palette.muted;
  Color get _buttonForeground => _palette.buttonForeground;
  Color get _panelColor => _palette.panelColor;
  Color get _panelBorderColor => _palette.panelBorderColor;
  Color get _panelAccentColor => _palette.panelAccentColor;
  Color get _selectedSurfaceColor => _palette.selectedSurfaceColor;
  Color get _selectedForegroundColor => _palette.selectedForegroundColor;
  @override
  void initState() {
    super.initState();
    _environment.addListener(_onEnvironmentChanged);
    _environment.initialize(gameRoot: PathManager.instance.gameRoot);
    _catalog = VersionCatalogController(
      preferences: _preferences,
      sourcesProvider: () => _environment.effectiveSources,
      minecraftPathProvider: () => _environment.minecraftPath,
      onError: _showVersionMessage,
    )..addListener(_onVersionCatalogChanged);
    _java = JavaEnvironmentController(
      preferences: _preferences,
      minecraftPathProvider: () => _environment.minecraftPath,
      cacheFileProvider: () => PathManager.instance.javaRuntimeCacheFile,
      onError: _showVersionMessage,
    )..addListener(_onJavaChanged);
    _auth = AuthController(
      preferences: _preferences,
      onError: _showVersionMessage,
    )..addListener(_onAuthChanged);
    _downloads = DownloadActivityController(manager: DownloadManager())
      ..addListener(_onDownloadActivityChanged);
    _resourceDownloads = ResourceDownloadController()
      ..addListener(_onResourceDownloadsChanged);
    _minecraftDownloads = MinecraftDownloadController()
      ..addListener(_onMinecraftDownloadsChanged);
    _appearance = AppearanceController(
      preferences: _preferences,
      onThemeModeChanged: (mode) {
        if (launcherThemeMode.value != mode) launcherThemeMode.value = mode;
      },
    )..addListener(_onAppearanceChanged);
    _appearance.startClock();
    _shell.addListener(_onShellChanged);
    launcherThemeMode.addListener(_onThemeChanged);
    unawaited(_catalog.loadVersions());
    unawaited(_loadLauncherPreferences());
    unawaited(_appearance.loadWallpaperPreferences());
    unawaited(_appearance.loadLanguagePreference());
    unawaited(_java.loadCache());
    unawaited(_detectMemoryLimit());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _appearance.applyAppearanceMode();
    });
    unawaited(ModSearchService.instance.initDatabase());
    unawaited(
      ModTagTranslationService.instance.init().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(McmodTitleService.instance.init());
  }

  MinecraftCatalogService get _catalogService =>
      widget.catalogService ?? const MinecraftCatalogService();
  MinecraftDownloadService get _downloadService =>
      widget.downloadService ?? const MinecraftDownloadService();

  void _onShellChanged() {
    if (mounted) setState(() {});
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onEnvironmentChanged() {
    if (mounted) setState(() {});
  }

  void _onVersionCatalogChanged() {
    if (mounted) setState(() {});
  }

  void _onJavaChanged() {
    if (!mounted) return;
    if (_javaPathController.text != _java.customJavaPath) {
      _javaPathController.text = _java.customJavaPath;
    }
    setState(() {});
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  void _onDownloadActivityChanged() {
    if (mounted) setState(() {});
  }

  void _onAppearanceChanged() {
    if (mounted) setState(() {});
  }

  void _onResourceDownloadsChanged() {
    if (mounted) setState(() {});
  }

  void _onMinecraftDownloadsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    launcherThemeMode.removeListener(_onThemeChanged);
    _catalog
      ..removeListener(_onVersionCatalogChanged)
      ..dispose();
    _environment
      ..removeListener(_onEnvironmentChanged)
      ..dispose();
    _java
      ..removeListener(_onJavaChanged)
      ..dispose();
    _auth
      ..removeListener(_onAuthChanged)
      ..dispose();
    _downloads.manager.dispose();
    _downloads
      ..removeListener(_onDownloadActivityChanged)
      ..dispose();
    _appearance
      ..removeListener(_onAppearanceChanged)
      ..dispose();
    _resourceDownloads
      ..removeListener(_onResourceDownloadsChanged)
      ..dispose();
    _minecraftDownloads
      ..removeListener(_onMinecraftDownloadsChanged)
      ..dispose();
    _shell
      ..removeListener(_onShellChanged)
      ..dispose();
    LauncherLog.info('App', '启动器界面关闭');
    unawaited(_closeDebugLogWindow());
    unawaited(LauncherLog.flush());
    _javaPathController.dispose();
    _minecraftClientNameController.dispose();
    _candidateManager.clear();
    _candidatesToRemove.clear();
    super.dispose();
  }

  void _openDownloadTasks() {
    _shell.selectTab(LauncherTab.downloadTasks);
  }

  void _openMinecraftDownload() {
    if (isDownloadLocked) {
      unawaited(_showDownloadLockedDialog(context));
      return;
    }
    _shell.openMinecraftDownload();
    unawaited(_loadMinecraftCatalog());
  }

  Widget _buildSettingsPage(bool isDark) {
    return SettingsPage(
      appearance: _appearance,
      java: _java,
      preferences: _preferences,
      isDark: isDark,
      downloadSource: _minecraftDownloadSource,
      aggregatePreference: _aggregatePreference,
      mcimEnabled: _mcimEnabled,
      onMcimEnabledChanged: _setMcimEnabled,
      debugLoggingEnabled: _debugLoggingEnabled,
      debugLogWindowOpen: _debugLogProcess != null,
      onDownloadSourceChanged: (source) {
        _setPageState(() => _minecraftDownloadSource = source);
      },
      onAggregatePreferenceChanged: _updateAggregatePreference,
      onDebugLoggingChanged: (value) {
        unawaited(_setDebugLoggingEnabled(value));
      },
      onOpenDebugLogWindow: () => unawaited(_openDebugLogWindow()),
      onCloseDebugLogWindow: () => unawaited(_closeDebugLogWindow()),
      onRecordState: _recordDebugState,
      onChooseWallpaper: (dark) {
        unawaited(_chooseWallpaper(dark: dark));
      },
      onRecropWallpaper: (dark) {
        unawaited(_recropWallpaper(dark: dark));
      },
      onResetWallpaper: (dark) {
        _appearance.resetWallpaper(dark: dark);
      },
      onDiscoverJava: () => unawaited(_java.discover()),
      onPickJava: () => unawaited(_pickJavaExecutable()),
      onSelectJava: (executable) {
        unawaited(_java.selectRuntime(executable));
      },
      onMessage: _showVersionMessage,
    );
  }

  void _updateAggregatePreference(AggregatePreference preference) {
    if (_aggregatePreference == preference) return;
    _setPageState(() => _aggregatePreference = preference);
    unawaited(_persistPreference('aggregatePreference', preference.name));
    if (_shell.selectedTab == LauncherTab.downloads &&
        _resourceSource == ResourceSource.aggregate) {
      unawaited(_loadResourceResults());
    }
  }

  void _setMcimEnabled(bool enabled) {
    if (_mcimEnabled == enabled) return;
    _setPageState(() => _mcimEnabled = enabled);
    CurseForgeService.endpoint = enabled
        ? CurseForgeEndpoint.mcim
        : CurseForgeEndpoint.proxy;
    unawaited(_preferences.setMcimEnabled(enabled));
    _showVersionMessage(enabled ? '已启用 MCIM 镜像源。' : '已恢复默认 CurseForge 通道。');
  }

  void _recordDebugState() {
    LauncherLog.info(
      'Debug',
      '手动记录：当前来源 $_minecraftPath，'
          '版本 ${_versions.length} 个，'
          'Java ${_selectedJavaExecutable ?? '未选择'}，'
          '内存 ${_bgucMemoryGb.round()} GB',
    );
    _showVersionMessage('已写入一条调试状态日志。');
  }

  void _handleTabSelected(LauncherTab tab) {
    final label = switch (tab) {
      LauncherTab.home => '主页',
      LauncherTab.versions => '版本管理',
      LauncherTab.downloads => '资源下载',
      LauncherTab.downloadTasks => '下载任务',
      LauncherTab.settings => '设置',
      LauncherTab.workbench => '工作台',
    };
    LauncherLog.info('UI', '切换到 $label 页面');
    _shell.selectTab(tab);
    if (tab == LauncherTab.downloads) {
      _loadResourceResults();
    }
  }

  Widget _buildActiveDownloadBanner() {
    final task = _activeDownloadTask;
    if (task == null) return const SizedBox.shrink();
    return ActiveDownloadBanner(
      manager: _downloadManager,
      task: task,
      canCancel: _canCancelActiveDownload,
      onTap: _openDownloadTasks,
      onCancel: _cancelActiveDownload,
      surfaceColor: _selectedSurfaceColor,
      panelBorderColor: _panelBorderColor,
      buttonForegroundColor: _buttonForeground,
      selectedForegroundColor: _selectedForegroundColor,
      mutedColor: _muted,
      accentColor: _uiColors.accent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usesDarkPalette = _usesDarkPalette;
    final contentTheme = usesDarkPalette
        ? Theme.of(context).copyWith(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7BC043),
              brightness: Brightness.dark,
            ),
            textTheme: Theme.of(context).textTheme
                .apply(bodyColor: Colors.white, displayColor: Colors.white),
            iconTheme: const IconThemeData(color: Colors.white),
            scaffoldBackgroundColor: const Color(0xFF101510),
          )
        : Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Theme(
        data: contentTheme,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: usesDarkPalette ? Colors.white : null),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 650),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _wallpaperPath == null
                    ? ColoredBox(
                        key: const ValueKey('default-launcher-background'),
                        color: usesDarkPalette
                            ? const Color(0xFF101510)
                            : const Color(0xFFF1F4ED),
                      )
                    : WallpaperBackground(
                        key: ValueKey(_wallpaperPath),
                        file: File(_wallpaperPath!),
                        crop: _wallpaperCrop,
                        mode: _wallpaperDisplayMode,
                      ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _wallpaperPath == null
                        ? List.filled(
                            4,
                            usesDarkPalette
                                ? const Color(0xFF101510)
                                : const Color(0xFFF1F4ED),
                          )
                        : _isDarkTheme
                        ? const [
                            Color(0x66080D08),
                            Color(0x22101510),
                            Color(0x33101510),
                            Color(0x77101510),
                          ]
                        : const [
                            Color(0x33FFFFFF),
                            Color(0x11FFFFFF),
                            Color(0x22FFFFFF),
                            Color(0x55FFFFFF),
                          ],
                    stops: [0, 0.28, 0.68, 1],
                  ),
                ),
              ),
              LauncherShell(
                topBar: LauncherTopBar(
                  activeDownloadBanner: _activeDownloadTask == null
                      ? null
                      : _buildActiveDownloadBanner(),
                  isDark: usesDarkPalette,
                  isMaximized: _shell.isWindowMaximized,
                  onStartDrag: () => _runWindowCommand('startDrag'),
                  onToggleMaximize: () => _runWindowCommand('toggleMaximize'),
                  onMinimize: () => _runWindowCommand('minimize'),
                  onClose: () => _runWindowCommand('close'),
                ),
                sidebar: LauncherSidebar(
                  selectedTab: _shell.selectedTab,
                  onSelected: _handleTabSelected,
                  isDark: usesDarkPalette,
                ),
                contentKey: ValueKey(
                  '${_shell.selectedTab.name}-${_shell.selectedTab == LauncherTab.versions && _shell.showVersionDetails}-${_shell.selectedTab == LauncherTab.downloads && _shell.showMinecraftDownload}-'
                  '${_shell.selectedTab == LauncherTab.downloads ? (_resourceDetailProject == null ? 'resource-list' : 'resource-detail-${_resourceDetailProject!.id}') : ''}',
                ),
                content: switch (_shell.selectedTab) {
                  LauncherTab.home => _buildHomeContent(),
                  LauncherTab.versions => _buildVersionsTab(),
                  LauncherTab.downloads => _buildDownloadsTab(),
                  LauncherTab.downloadTasks => DownloadTasksPage(
                    activity: _downloads,
                    manager: _downloadManager,
                    palette: _palette,
                    onCancelActiveDownload: _cancelActiveDownload,
                  ),
                  LauncherTab.settings => _buildSettingsPage(usesDarkPalette),
                  LauncherTab.workbench => WorkbenchPage(palette: _palette),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _effectiveMinecraftSources() => _environment.effectiveSources;

  bool _samePath(String left, String right) =>
      LauncherEnvironmentController.samePath(left, right);

  JavaRuntimeService get _javaRuntimeService => _java.service;

  void _scheduleResourceSearch() {
    _resourceDownloads.scheduleSearch();
  }

  Future<void> _loadResourceResults() => _resourceDownloads.loadResults();
  Future<void> _detectMemoryLimit() async {
    try {
      late final int totalMemoryGb;
      if (Platform.isWindows) {
        final result = await Process.run(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            '[math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)',
          ],
          runInShell: false,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        if (result.exitCode != 0) {
          throw ProcessException(
            'powershell.exe',
            const ['Get-CimInstance Win32_ComputerSystem'],
            result.stderr as String,
            result.exitCode,
          );
        }
        totalMemoryGb = int.parse((result.stdout as String).trim());
      } else if (Platform.isLinux) {
        final memoryInfo = await File('/proc/meminfo').readAsString();
        final match = RegExp(
          r'^MemTotal:\s+(\d+)\s+kB$',
          multiLine: true,
        ).firstMatch(memoryInfo);
        if (match == null) {
          throw const FormatException('无法从 /proc/meminfo 读取总内存。');
        }
        totalMemoryGb = (int.parse(match.group(1)!) / 1024 / 1024).floor();
      } else if (Platform.isMacOS) {
        final result = await Process.run(
          'sysctl',
          ['-n', 'hw.memsize'],
          runInShell: false,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        if (result.exitCode != 0) {
          throw ProcessException('sysctl', const ['-n', 'hw.memsize']);
        }
        totalMemoryGb =
            (int.parse((result.stdout as String).trim()) / 1024 / 1024 / 1024)
                .floor();
      } else {
        throw const FormatException('当前平台不支持自动检测物理内存。');
      }
      final safeLimit = math.max(2, totalMemoryGb - 2).clamp(2, 64).toDouble();
      if (!mounted) return;
      setState(() {
        _maxMemoryGb = safeLimit;
        _bgucMemoryGb = _bgucMemoryGb.clamp(2, safeLimit).toDouble();
        _memoryDetectionError = null;
      });
    } on ProcessException catch (error) {
      if (mounted) {
        setState(() {
          _memoryDetectionError = '自动检测物理内存失败：${error.message}';
        });
      }
    } on FileSystemException catch (error) {
      if (mounted) {
        setState(() {
          _memoryDetectionError = '读取物理内存信息失败：${error.message}';
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _memoryDetectionError = '自动检测物理内存失败：${error.message}';
        });
      }
    }
  }

  void _setPageState(VoidCallback callback) => setState(callback);

  void _showVersionMessage(String message) {
    LauncherLog.info('UI', message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}
