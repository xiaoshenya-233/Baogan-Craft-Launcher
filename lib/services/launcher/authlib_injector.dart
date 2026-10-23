import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/launcher_log.dart';
import '../../core/path_manager.dart';
import '../../core/path_utils.dart';

/// Bundled authlib-injector helper.
///
/// The jar ships inside `assets/lib/` and is released to
/// `BGCL/runtime/authlib-injector.jar` on first use, so players never have to
/// pick a jar file by hand.
class AuthlibInjector {
  const AuthlibInjector._();

  static const String assetKey = 'assets/lib/authlib-injector.jar';
  static const String fileName = 'authlib-injector.jar';

  /// Absolute path of the released jar, or null when no root is configured.
  static String? get targetPath {
    final runtime = PathManager.instance.runtimeDir;
    if (runtime == null) return null;
    return joinPath(runtime, fileName);
  }

  /// Copies the bundled jar to the runtime folder when it is missing.
  ///
  /// Returns the absolute path, or `null` when the launcher root is not
  /// configured or the asset could not be written.
  static Future<String?> ensureExtracted({bool force = false}) async {
    final target = targetPath;
    if (target == null) return null;
    final file = File(target);
    try {
      if (!force && await file.exists() && await file.length() > 0) {
        return file.path;
      }
      final data = await rootBundle.load(assetKey);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      LauncherLog.info('Authlib', '已释放 authlib-injector：${file.path}');
      return file.path;
    } on Object catch (error) {
      LauncherLog.warning('Authlib', '释放 authlib-injector 失败：$error');
      return null;
    }
  }

  /// `-javaagent:` value used by the launcher (`<jar>=<server>`).
  static String agentArgument(String jarPath, String server) =>
      '${jarPath.trim()}=${server.trim()}';

  /// Extracts the Yggdrasil server from a stored `<jar>=<server>` value.
  static String? serverFromAgent(String? javaAgent) {
    final value = javaAgent?.trim() ?? '';
    final separator = value.indexOf('=');
    if (separator <= 0 || separator == value.length - 1) return null;
    final server = value.substring(separator + 1).trim();
    return server.isEmpty ? null : server;
  }
}
