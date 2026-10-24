import '../../core/launcher_log.dart';
import '../../core/preferences_store.dart';
import 'plugin_manifest.dart';

/// Persisted UAC decision for one plugin permission.
enum PluginPermissionState {
  always,
  ask,
  deny;

  static PluginPermissionState parse(String? value) {
    for (final state in values) {
      if (state.name == value) return state;
    }
    return ask;
  }
}

/// Answer of one UAC prompt.
enum PluginPermissionDecision { always, once, deny }

/// UI callback that suspends the action while the player answers the UAC dialog.
typedef PluginPermissionPrompt = Future<PluginPermissionDecision> Function(
  PluginManifest manifest,
  String permission,
  String path,
);

/// Resolves and persists host-filesystem permissions for plugins.
class PluginPermissionService {
  PluginPermissionService({PreferencesStore? preferences})
    : _preferences = preferences ?? PreferencesStore();

  static final PluginPermissionService instance = PluginPermissionService();

  final PreferencesStore _preferences;

  Future<PluginPermissionState> stateFor(
    String pluginId,
    String permission,
  ) async => PluginPermissionState.parse(
    await _preferences.readPluginPermissionState(pluginId, permission),
  );

  Future<void> setState(
    String pluginId,
    String permission,
    PluginPermissionState state,
  ) => _preferences.setPluginPermissionState(pluginId, permission, state.name);

  /// Resets every known UAC decision for [pluginId] back to `ask`.
  Future<void> resetForPlugin(String pluginId) async {
    for (final permission in PluginPermissions.all) {
      await setState(pluginId, permission, PluginPermissionState.ask);
    }
    LauncherLog.info('Plugins', '已重置插件权限记录：$pluginId');
  }

  /// Returns whether the plugin may access [path] for [permission].
  ///
  /// Sandbox paths bypass this method in the dispatcher. For host paths the
  /// plugin must declare the permission and the stored state must allow it;
  /// `ask` awaits [prompt] (the Material 3 UAC dialog).
  Future<bool> authorize({
    required PluginManifest manifest,
    required String permission,
    required String path,
    PluginPermissionPrompt? prompt,
  }) async {
    if (!manifest.hasPermission(permission)) return false;
    final state = await stateFor(manifest.id, permission);
    LauncherLog.info(
      'Plugins',
      'UAC 授权检查：插件 ${manifest.id}，权限=$permission，'
          '状态=${state.name}，prompt=${prompt != null}',
    );
    switch (state) {
      case PluginPermissionState.always:
        return true;
      case PluginPermissionState.deny:
        return false;
      case PluginPermissionState.ask:
        if (prompt == null) {
          LauncherLog.warning(
            'Plugins',
            '插件 ${manifest.id} 请求 $permission，但当前没有可用的 UAC 界面。',
          );
          return false;
        }
        final decision = await prompt(manifest, permission, path);
        switch (decision) {
          case PluginPermissionDecision.always:
            await setState(
              manifest.id,
              permission,
              PluginPermissionState.always,
            );
            return true;
          case PluginPermissionDecision.once:
            return true;
          case PluginPermissionDecision.deny:
            await setState(manifest.id, permission, PluginPermissionState.deny);
            return false;
        }
    }
  }
}
