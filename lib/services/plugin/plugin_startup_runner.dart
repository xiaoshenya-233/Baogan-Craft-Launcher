import '../../core/launcher_log.dart';
import 'plugin_action_dispatcher.dart';
import 'plugin_file_sandbox.dart';
import 'plugin_manifest.dart';

/// Dispatches one startup action; injectable for tests.
typedef PluginStartupDispatcher = Future<PluginActionResult> Function(
  PluginManifest manifest,
  String action,
  Map<String, dynamic> params,
);

/// Executes `plugin.json` `startupActions` after plugin scanning finishes.
///
/// Only a small safe whitelist is allowed, and every action still goes through
/// [PluginActionDispatcher], so missing permissions are rejected and logged.
/// The runner never shows dialogs: feedback is written to the launcher log.
class PluginStartupRunner {
  PluginStartupRunner._();

  static final PluginStartupRunner instance = PluginStartupRunner._();

  /// Actions that are safe to run unattended at startup.
  static const Set<String> allowedActions = <String>{
    'audio_play',
    'play_music_folder',
    'download_file',
    'read_file',
    'show_snackbar',
  };

  Future<void> run(
    List<PluginManifest> plugins, {
    PluginStartupDispatcher? dispatch,
  }) async {
    if (plugins.isEmpty) return;
    final runner = dispatch ?? _defaultDispatch;
    for (final plugin in plugins) {
      if (!plugin.enableStartup) continue;
      var config = const <String, dynamic>{};
      try {
        config = await PluginFileSandbox.readConfig(plugin.id);
      } on Object catch (error) {
        LauncherLog.warning(
          'Plugins',
          '插件 ${plugin.id} 的 config.json 读取失败，使用默认配置：$error',
        );
      }
      for (final action in plugin.startupActions) {
        if (action.action == 'play_music_folder' &&
            config['auto_play'] == false) {
          LauncherLog.info('Plugins', '插件 ${plugin.id} 已关闭 auto_play，跳过启动播放。');
          continue;
        }
        if (!allowedActions.contains(action.action)) {
          LauncherLog.info(
            'Plugins',
            '插件 ${plugin.id} 的启动动作 ${action.action} 已忽略（不在安全白名单内）。',
          );
          continue;
        }
        try {
          final result = await runner(plugin, action.action, action.params);
          if (!result.isSuccess) {
            LauncherLog.warning(
              'Plugins',
              '插件 ${plugin.id} 的启动动作 ${action.action} 未执行：'
                  '${result.status.name}'
                  '${result.message == null ? '' : '（${result.message}）'}',
            );
          } else {
            LauncherLog.info(
              'Plugins',
              '插件 ${plugin.id} 的启动动作已执行：${action.action}',
            );
          }
        } on Object catch (error) {
          LauncherLog.warning(
            'Plugins',
            '插件 ${plugin.id} 的启动动作 ${action.action} 失败：$error',
          );
        }
      }
    }
  }

  Future<PluginActionResult> _defaultDispatch(
    PluginManifest manifest,
    String action,
    Map<String, dynamic> params,
  ) {
    final dispatcher = PluginActionDispatcher(
      onNavigate: (_) {},
      onLaunchGame: () async {},
      onMessage: (message) => LauncherLog.info('Plugins', '启动提示：$message'),
    );
    return dispatcher.dispatch(manifest, action, params);
  }
}
