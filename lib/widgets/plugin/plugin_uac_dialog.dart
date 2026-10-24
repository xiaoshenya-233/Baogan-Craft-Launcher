import 'package:flutter/material.dart';

import '../../core/launcher_log.dart';
import '../../services/plugin/plugin_manifest.dart';
import '../../services/plugin/plugin_permission_service.dart';

/// Root navigator used for UAC dialogs so plugin UI can never cover them.
final GlobalKey<NavigatorState> pluginUacNavigatorKey =
    GlobalKey<NavigatorState>();

/// Material 3 UAC dialog shown when a plugin asks for a restricted host path.
class PluginUacDialog extends StatelessWidget {
  const PluginUacDialog({
    super.key,
    required this.manifest,
    required this.permission,
    required this.path,
  });

  final PluginManifest manifest;
  final String permission;
  final String path;

  static Future<PluginPermissionDecision> show({
    required PluginManifest manifest,
    required String permission,
    required String path,
  }) async {
    // Always use the root navigator: a plugin's Stack/fullscreen card lives
    // inside the page and must never be able to cover the real UAC dialog.
    final rootContext =
        pluginUacNavigatorKey.currentContext ??
        pluginUacNavigatorKey.currentState?.overlay?.context;
    if (rootContext == null) {
      LauncherLog.warning(
        'Plugins',
        '无法显示 UAC：根导航器尚未挂载，插件 ${manifest.id} 权限 $permission',
      );
      return PluginPermissionDecision.deny;
    }
    LauncherLog.info(
      'Plugins',
      '显示 UAC：插件 ${manifest.id}，权限=$permission，路径=$path',
    );
    final decision = await showDialog<PluginPermissionDecision>(
      context: rootContext,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => PluginUacDialog(
        manifest: manifest,
        permission: permission,
        path: path,
      ),
    );
    final resolved = decision ?? PluginPermissionDecision.deny;
    LauncherLog.info(
      'Plugins',
      'UAC 用户决定：插件 ${manifest.id}，权限=$permission，结果=${resolved.name}',
    );
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMinecraft = permission == PluginPermissions.minecraftRead;
    return AlertDialog(
      icon: Icon(Icons.gpp_maybe_outlined, color: scheme.error, size: 30),
      title: const Text('插件权限请求'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '「${manifest.name}」请求访问受限文件',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
              ),
              child: SelectableText(
                path,
                maxLines: 5,
                style: const TextStyle(fontSize: 11, height: 1.35),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isMinecraft
                  ? '此权限允许该插件读取 Minecraft 游戏目录中的存档、配置和日志等文件。'
                  : '此权限允许该插件读取宿主计算机上的任意文件，可能包含隐私数据。',
              style: TextStyle(fontSize: 12, color: scheme.error),
            ),
            const SizedBox(height: 6),
            Text(
              '仅在你信任该插件时允许。选择「始终允许」后不会再次询问。',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, PluginPermissionDecision.deny),
          child: const Text('拒绝'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, PluginPermissionDecision.once),
          child: const Text('仅此次允许'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, PluginPermissionDecision.always),
          child: const Text('始终允许'),
        ),
      ],
    );
  }
}
