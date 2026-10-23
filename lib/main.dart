import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'core/launcher_log.dart';
import 'core/network_detector.dart';
import 'core/path_manager.dart';
import 'l10n/app_localizations.dart';
import 'pages/launcher/controllers/appearance_controller.dart';
import 'pages/launcher/launcher_app.dart';
import 'pages/launcher_home_page.dart';
import 'services/launcher/authlib_injector.dart';

export 'pages/launcher/launcher_app.dart';
export 'pages/launcher_home_page.dart';
export 'services/download/download_service.dart';
export 'services/installer/game_installer.dart';
export 'services/installer/version_models.dart';
export 'services/java/java_service.dart';
export 'services/launcher/game_launcher.dart';
export 'services/network/api_service.dart';
export 'services/network/auth_service.dart';
export 'services/translation/database_service.dart';
export 'services/translation/mod_search_service.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Decide the UI language before any widget runs: the setup wizard, the
  // startup splash and the network-check window already need it.
  launcherLocale.value = detectLauncherLocale(
    WidgetsBinding.instance.platformDispatcher.locale,
  );

  final status = await const NetworkDetector().checkRegion();
  if (status == RegionStatus.unknown) {
    runApp(NetworkCheckApp(args: args));
    return;
  }
  isDownloadLocked = status == RegionStatus.domestic;
  await _startLauncher(args);
}

Future<bool> _retryNetworkAndStart(List<String> args) async {
  final status = await const NetworkDetector().checkRegion();
  if (status == RegionStatus.unknown) return false;
  isDownloadLocked = status == RegionStatus.domestic;
  await _startLauncher(args);
  return true;
}

Future<void> _startLauncher(List<String> args) async {
  final debugLogPath = debugLogWindowPathFromArgs(args);
  if (debugLogPath != null) {
    runApp(DebugLogWindowApp(logPath: debugLogPath));
    return;
  }

  await PathManager.instance.load();
  if (PathManager.instance.isConfigured) {
    // Release the bundled authlib-injector in the background; failures are
    // reported later when a third-party account is actually launched.
    unawaited(AuthlibInjector.ensureExtracted());
  }
  // 在用户选定根目录之前，不初始化日志、数据库或任何会写本地缓存的模块。
  FlutterError.onError = (details) {
    LauncherLog.error(
      'Flutter',
      '${details.exceptionAsString()}\n${details.stack ?? ''}',
    );
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
    LauncherLog.error('Unhandled', '$error', stackTrace);
    return true;
  };
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(titleBarStyle: TitleBarStyle.hidden),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  runApp(const BlockLauncherApp());
}

class NetworkCheckApp extends StatefulWidget {
  const NetworkCheckApp({super.key, required this.args});

  final List<String> args;

  @override
  State<NetworkCheckApp> createState() => _NetworkCheckAppState();
}

class _NetworkCheckAppState extends State<NetworkCheckApp> {
  bool _checking = false;
  String? _error;

  Future<void> _retry() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final started = await _retryNetworkAndStart(widget.args);
      if (!mounted) return;
      if (!started) {
        setState(() {
          _checking = false;
          _error = AppLocalizations.of(context)!.networkCheckRetryFailed;
        });
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = AppLocalizations.of(context)!.networkStartFailed('$error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: launcherLocale,
      builder: (context, locale, _) => MaterialApp(
        onGenerateTitle: (context) =>
            AppLocalizations.of(context)?.appTitle ?? 'Baogan Craft Launcher',
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => _buildNetworkError(context),
        ),
      ),
    );
  }

  Widget _buildNetworkError(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 52,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.networkCheckTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.networkCheckMessage,
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _checking ? null : _retry,
                    icon: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      _checking ? l10n.networkChecking : l10n.actionRetry,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
