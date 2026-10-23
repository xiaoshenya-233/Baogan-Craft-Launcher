import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/launcher_log.dart';
import '../../core/path_manager.dart';
import '../../services/installer/game_installer.dart';
import '../../services/network/api_service.dart';
import '../../services/translation/database_service.dart';
import '../launcher_home_page.dart';
import '../setup/setup_page.dart';
import '../setup/startup_splash.dart';

/// Blocks the launcher UI until a valid root directory has been configured.
///
/// Logging, SQLite caches and other local writers are started only after the
/// root exists, so a first launch cannot leave files on the system drive.
class LauncherBootstrap extends StatefulWidget {
  const LauncherBootstrap({
    super.key,
    this.catalogService,
    this.downloadService,
  });

  final MinecraftCatalogService? catalogService;
  final MinecraftDownloadService? downloadService;

  @override
  State<LauncherBootstrap> createState() => _LauncherBootstrapState();
}

class _LauncherBootstrapState extends State<LauncherBootstrap> {
  bool _configured = false;
  bool _ready = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    final testing = Platform.environment['FLUTTER_TEST'] == 'true';
    _configured = PathManager.instance.isConfigured || testing;
    _ready = testing;
    if (_configured && !_ready) {
      unawaited(_initializeConfiguredModules());
    }
  }

  Future<void> _initializeConfiguredModules() async {
    if (_initializing || !PathManager.instance.isConfigured) return;
    _initializing = true;
    try {
      await LauncherLog.initialize();
      LauncherLog.info(
        'App',
        'Baogan Craft Launcher 启动 · ${Platform.operatingSystem} · '
            '${Platform.version}',
      );
      LauncherLog.info('Paths', '启动器根目录：${PathManager.instance.selectedRoot}');
      LauncherLog.info(
        'Network',
        'Minecraft 客户端下载${isDownloadLocked ? '已锁定' : '可用'}（启动检测结果）',
      );
      // The display cache must be loaded before the first search result is
      // built, otherwise a title already in SQLite would flash its English name.
      await McmodTitleService.instance.init();
    } finally {
      _initializing = false;
      if (mounted) setState(() => _ready = true);
    }
  }

  Future<void> _handleConfigured() async {
    if (!mounted) return;
    setState(() {
      _configured = true;
      _ready = false;
    });
    await _initializeConfiguredModules();
  }

  @override
  Widget build(BuildContext context) {
    if (!_configured) {
      return LauncherSetupPage(onConfigured: _handleConfigured);
    }
    if (!_ready) {
      return const LauncherStartupSplash();
    }
    return LauncherHomePage(
      catalogService: widget.catalogService,
      downloadService: widget.downloadService,
    );
  }
}
