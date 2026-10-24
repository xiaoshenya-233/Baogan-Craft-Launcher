import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'launcher_log.dart';
import 'path_manager.dart';

/// Unified JSON preferences access for launcher controllers.
///
/// Every write is a read-modify-write of the whole file, so writes are
/// serialized through one process-wide queue. Without it, two controllers
/// saving at the same time would each read the old file and the second write
/// would drop the first controller's key.
class PreferencesStore {
  /// [fileProvider] lets tests point the store at a temporary config file.
  PreferencesStore({this.fileProvider});

  /// Key of the CurseForge mirror switch.
  static const String mcimEnabledKey = 'mcimEnabled';

  /// Key of the global default Java selection.
  static const String javaSelectionKey = 'selectedJavaExecutable';

  /// Value that asks the launcher to match Java per Minecraft version.
  static const String autoJavaValue = 'auto';

  /// Key of the launcher UI language.
  static const String languageKey = 'app_language';

  /// Prefix for per-plugin permission decisions (`always` / `ask` / `deny`).
  static const String pluginPermissionPrefix = 'pluginPermission_';

  /// Default decision until the user explicitly answers a UAC prompt.
  static const String pluginPermissionAsk = 'ask';

  /// Language used when nothing (or an unknown value) is persisted.
  static const String defaultLanguage = 'zh';

  /// Tail of the shared write queue.
  static Future<void> _writeQueue = Future<void>.value();

  final File? Function()? fileProvider;

  Future<bool> exists() async {
    final file = _file;
    return file != null && await file.exists();
  }

  Future<Map<String, dynamic>> readAll() async {
    final file = _file;
    if (file == null || !await file.exists()) return {};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('启动器设置必须是 JSON 对象。');
    }
    return decoded;
  }

  /// Reads the persisted MCIM mirror switch.
  Future<bool> readMcimEnabled() async {
    try {
      final all = await readAll();
      return all[mcimEnabledKey] == true;
    } on Object {
      return false;
    }
  }

  /// Persists the MCIM mirror switch.
  Future<void> setMcimEnabled(bool enabled) => write(mcimEnabledKey, enabled);

  /// Reads the global default Java; missing or blank values mean `auto`.
  Future<String> readJavaSelection() async {
    try {
      final all = await readAll();
      final value = all[javaSelectionKey];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      return autoJavaValue;
    } on Object {
      return autoJavaValue;
    }
  }

  /// Persists the global default Java; blank input is stored as `auto`.
  Future<void> setJavaSelection(String value) {
    final normalized = value.trim();
    return write(
      javaSelectionKey,
      normalized.isEmpty ? autoJavaValue : normalized,
    );
  }

  /// Reads the persisted UI language, or `null` when nothing usable is saved.
  ///
  /// `null` lets the launcher fall back to the detected system language instead
  /// of forcing Chinese on first launch.
  Future<String?> readLanguageOrNull() async {
    try {
      final all = await readAll();
      final value = all[languageKey];
      if (value is String && supportedLanguages.contains(value.trim())) {
        return value.trim();
      }
      return null;
    } on Object {
      return null;
    }
  }

  /// Reads the persisted UI language; unknown values fall back to `zh`.
  Future<String> readLanguage() async =>
      await readLanguageOrNull() ?? defaultLanguage;

  /// Persists the UI language; unsupported codes are stored as the default.
  Future<void> setLanguage(String languageCode) {
    final normalized = languageCode.trim();
    return write(
      languageKey,
      supportedLanguages.contains(normalized) ? normalized : defaultLanguage,
    );
  }

  /// Languages the launcher UI currently ships translations for.
  static const List<String> supportedLanguages = <String>['zh', 'en'];

  static String pluginPermissionKey(String pluginId, String permission) =>
      '$pluginPermissionPrefix${pluginId}_$permission';

  /// Reads one plugin permission decision; missing values default to `ask`.
  Future<String> readPluginPermissionState(
    String pluginId,
    String permission,
  ) async {
    try {
      final all = await readAll();
      final value = all[pluginPermissionKey(pluginId, permission)];
      return value is String && value.trim().isNotEmpty
          ? value.trim()
          : pluginPermissionAsk;
    } on Object {
      return pluginPermissionAsk;
    }
  }

  Future<void> setPluginPermissionState(
    String pluginId,
    String permission,
    String state,
  ) => write(pluginPermissionKey(pluginId, permission), state);

  Future<void> write(String key, Object? value) {
    final task = _writeQueue.then((_) => _writeNow(key, value));
    // Keep the queue usable after a failed write, and make every awaited write
    // wait until the shared queue tail has settled. Returning only `task` left
    // a pending `.then` tail behind, which could block the next write forever
    // when a widget test zone was torn down between the two.
    final settled = task.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    _writeQueue = settled;
    return task.whenComplete(() => settled);
  }

  Future<void> _writeNow(String key, Object? value) async {
    final file = _file;
    if (file == null) return;
    final preferences = <String, dynamic>{};
    if (await file.exists()) {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('启动器设置必须是 JSON 对象。');
      }
      preferences.addAll(decoded);
    }
    preferences[key] = value;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(preferences), flush: true);
    LauncherLog.info(
      'Settings',
      '保存设置 $key = ${redactLogSecrets(value.toString())}',
    );
  }

  /// Clears the shared queue between widget tests.
  ///
  /// Production code never calls this; it exists so a test that tears down its
  /// widget zone cannot leave a pending file write blocking the next test.
  @visibleForTesting
  static void resetWriteQueueForTest() {
    _writeQueue = Future<void>.value();
  }

  File? get _file =>
      fileProvider?.call() ?? PathManager.instance.preferencesFile;
}
