import 'package:flutter/material.dart';

import '../../services/installer/game_installer.dart';
import '../../services/network/api_service.dart';
import '../bootstrap/launcher_bootstrap.dart';
import '../launcher_home_page.dart';

const String _appFontFamily = 'SourceHanSansSC';

class BlockLauncherApp extends StatelessWidget {
  const BlockLauncherApp({
    super.key,
    this.minecraftCatalogService,
    this.minecraftDownloadService,
  });

  final MinecraftCatalogService? minecraftCatalogService;
  final MinecraftDownloadService? minecraftDownloadService;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: launcherThemeMode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'Baogan Craft Launcher',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          fontFamily: _appFontFamily,
          scaffoldBackgroundColor: const Color(0xFFF1F4ED),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7BC043),
            brightness: Brightness.light,
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(side: BorderSide.none),
          ),
          chipTheme: const ChipThemeData(
            side: BorderSide.none,
            backgroundColor: Color(0xA6F8FAF6),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          fontFamily: _appFontFamily,
          scaffoldBackgroundColor: const Color(0xFF101510),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7BC043),
            brightness: Brightness.dark,
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(side: BorderSide.none),
          ),
          chipTheme: const ChipThemeData(
            side: BorderSide.none,
            backgroundColor: Color(0x55343C2C),
          ),
        ),
        home: LauncherBootstrap(
          catalogService: minecraftCatalogService,
          downloadService: minecraftDownloadService,
        ),
      ),
    );
  }
}
