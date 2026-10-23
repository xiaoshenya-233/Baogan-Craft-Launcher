import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baogan_craft_launcher/core/preferences_store.dart';
import 'package:baogan_craft_launcher/pages/launcher/controllers/appearance_controller.dart';
import 'package:baogan_craft_launcher/pages/launcher/controllers/auth_controller.dart';
import 'package:baogan_craft_launcher/pages/launcher/controllers/download_activity_controller.dart';
import 'package:baogan_craft_launcher/pages/launcher/controllers/java_environment_controller.dart';
import 'package:baogan_craft_launcher/pages/launcher/controllers/launcher_environment_controller.dart';
import 'package:baogan_craft_launcher/pages/versions/controllers/version_catalog_controller.dart';
import 'package:baogan_craft_launcher/services/download/download_service.dart';
import 'package:baogan_craft_launcher/services/network/api_service.dart';
import 'package:baogan_craft_launcher/services/network/auth_service.dart';

void main() {
  test(
    'source switching refreshes the version catalog and selection',
    () async {
      final temp = await Directory.systemTemp.createTemp('launcher_phase3_');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      Future<String> createRoot(String folder, String versionId) async {
        final root = Directory('${temp.path}${Platform.pathSeparator}$folder');
        final versionDirectory = Directory(
          '${root.path}${Platform.pathSeparator}versions'
          '${Platform.pathSeparator}$versionId',
        );
        await versionDirectory.create(recursive: true);
        await File(
          '${versionDirectory.path}${Platform.pathSeparator}$versionId.json',
        ).writeAsString(jsonEncode({'id': versionId, 'type': 'release'}));
        return root.path;
      }

      final first = await createRoot('first', 'FirstClient');
      final second = await createRoot('second', 'SecondClient');
      final third = await createRoot('third', 'ThirdClient');

      final environment = LauncherEnvironmentController()
        ..initialize(gameRoot: first);
      final catalog = VersionCatalogController(
        preferences: PreferencesStore(),
        sourcesProvider: () => environment.effectiveSources,
        minecraftPathProvider: () => environment.minecraftPath,
      );
      addTearDown(() {
        catalog.dispose();
        environment.dispose();
      });

      await catalog.loadVersions();
      expect(catalog.localVersions.map((version) => version.id), [
        'FirstClient',
      ]);
      expect(catalog.versions.map((version) => version.name), ['FirstClient']);
      expect(catalog.selectedLaunchVersionId, endsWith('FirstClient'));

      environment.selectSource(second);
      catalog.clearVersions();
      expect(catalog.localVersions, isEmpty);
      expect(catalog.selectedLaunchVersionId, isNull);

      await catalog.loadVersions();
      expect(environment.minecraftPath, second);
      expect(environment.effectiveSources, containsAll([first, second]));
      expect(catalog.localVersions.map((version) => version.id), [
        'SecondClient',
      ]);
      expect(catalog.selectedLaunchVersionId, endsWith('SecondClient'));

      environment.replaceSource(second, third);
      catalog.clearVersions();
      await catalog.loadVersions();
      expect(environment.minecraftPath, third);
      expect(catalog.selectedLaunchVersionId, endsWith('ThirdClient'));

      environment.removeSource(third);
      expect(environment.minecraftPath, first);
      expect(environment.removeSource(first), isFalse);
    },
  );

  test('java and auth controllers normalize persisted settings', () async {
    final java = JavaEnvironmentController(
      preferences: PreferencesStore(),
      minecraftPathProvider: () => '',
      cacheFileProvider: () => null,
    );
    java.applyPreferences(
      customPath: r' C:\Java\bin\java.exe ',
      selectedExecutable: r'C:\Other\bin\java.exe',
    );
    expect(java.customJavaPath, r'C:\Java\bin\java.exe');
    expect(java.selectedExecutable, r'C:\Other\bin\java.exe');
    java.dispose();

    final auth = AuthController(preferences: PreferencesStore());
    auth.applyPreferences(
      modeName: 'thirdParty',
      offlinePlayerName: 'Steve_1',
      thirdPartyAuthServer: ' https://example.com/api/yggdrasil ',
    );
    expect(auth.mode, AuthMode.thirdParty);
    expect(auth.offlinePlayerName, 'Steve_1');
    expect(auth.thirdPartyAuthServer, 'https://example.com/api/yggdrasil');
    await auth.updateMode(AuthMode.microsoft);
    expect(auth.mode, AuthMode.microsoft);
    auth.dispose();
  });

  test('download activity starts, updates and cancels the shared task', () {
    final manager = DownloadManager();
    final activity = DownloadActivityController(manager: manager);
    final token = DownloadCancellationToken();
    addTearDown(() {
      activity.dispose();
      manager.dispose();
    });

    activity.start(task: '下载客户端', cancellation: token);
    expect(activity.activeTask, '下载客户端');
    expect(activity.canCancel, isTrue);

    activity.updateTask('下载客户端 42%');
    expect(activity.activeTask, '下载客户端 42%');

    expect(activity.cancel(), isTrue);
    expect(token.isCancelled, isTrue);
    expect(activity.activeTask, contains('正在取消'));

    activity.finish();
    expect(activity.activeTask, isNull);
    expect(activity.cancellationToken, isNull);
  });

  test('appearance controller persists and restores the UI language', () async {
    final directory = await Directory.systemTemp.createTemp('launcher_lang_');
    addTearDown(() => directory.delete(recursive: true));
    final preferencesFile = File(
      '${directory.path}${Platform.pathSeparator}preferences.json',
    );
    final preferences = PreferencesStore(fileProvider: () => preferencesFile);
    final appearance = AppearanceController(
      onThemeModeChanged: (_) {},
      preferences: preferences,
    );
    addTearDown(() {
      appearance.dispose();
      launcherLocale.value = launcherDefaultLocale;
    });

    expect(appearance.locale, launcherDefaultLocale);
    expect(launcherLocale.value, launcherDefaultLocale);

    appearance.setLocale(const Locale('en'));
    expect(appearance.locale.languageCode, 'en');
    expect(launcherLocale.value.languageCode, 'en');
    var stored = '';
    for (var attempt = 0; attempt < 100 && stored != 'en'; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      stored = await preferences.readLanguage();
    }
    expect(stored, 'en');

    appearance.setLocale(const Locale('fr'));
    expect(appearance.locale, launcherDefaultLocale);

    await preferences.setLanguage('en');
    launcherLocale.value = const Locale('zh');
    await appearance.loadLanguagePreference();
    expect(appearance.locale.languageCode, 'en');
    expect(launcherLocale.value.languageCode, 'en');
  });

  test('first launch follows the system language until one is saved', () async {
    final directory = await Directory.systemTemp.createTemp('launcher_lang_');
    addTearDown(() => directory.delete(recursive: true));
    final preferencesFile = File(
      '${directory.path}${Platform.pathSeparator}preferences.json',
    );
    final preferences = PreferencesStore(fileProvider: () => preferencesFile);
    final appearance = AppearanceController(
      onThemeModeChanged: (_) {},
      preferences: preferences,
    );
    addTearDown(() {
      appearance.dispose();
      launcherLocale.value = launcherDefaultLocale;
    });

    expect(detectLauncherLocale(const Locale('zh', 'CN')), const Locale('zh'));
    expect(detectLauncherLocale(const Locale('en', 'US')), const Locale('en'));
    expect(detectLauncherLocale(const Locale('fr')), const Locale('en'));

    // Nothing saved yet: an English system starts in English.
    await appearance.loadLanguagePreference(systemLocale: const Locale('en'));
    expect(appearance.locale.languageCode, 'en');
    expect(await preferences.readLanguageOrNull(), isNull);

    // A saved choice always wins over the system language.
    await preferences.setLanguage('zh');
    await appearance.loadLanguagePreference(systemLocale: const Locale('en'));
    expect(appearance.locale.languageCode, 'zh');
  });
}
