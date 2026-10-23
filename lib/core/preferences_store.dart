import 'dart:convert';
import 'dart:io';

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

  Future<void> write(String key, Object? value) {
    final task = _writeQueue.then((_) => _writeNow(key, value));
    // Keep the queue usable after a failed write so later saves still run.
    _writeQueue = task.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return task;
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

  File? get _file =>
      fileProvider?.call() ?? PathManager.instance.preferencesFile;
}
