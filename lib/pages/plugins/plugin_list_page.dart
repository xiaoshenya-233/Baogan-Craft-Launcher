import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/launcher_log.dart';
import '../../core/platform_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../services/plugin/plugin_action_dispatcher.dart';
import '../../services/plugin/plugin_icon_mapper.dart';
import '../../services/plugin/plugin_manager.dart';
import '../../services/plugin/plugin_manifest.dart';
import '../../services/plugin/plugin_permission_service.dart';
import 'plugin_page.dart';

/// Lists installed plugins and hosts their pages inside the launcher shell.
class PluginListPage extends StatefulWidget {
  const PluginListPage({
    super.key,
    required this.onNavigate,
    required this.onLaunchGame,
    this.showHeader = true,
  });

  final PluginNavigateAction onNavigate;
  final PluginLaunchAction onLaunchGame;

  /// `false` when embedded in the workbench, which supplies its own header.
  final bool showHeader;

  @override
  State<PluginListPage> createState() => _PluginListPageState();
}

class _PluginListPageState extends State<PluginListPage> {
  PluginManifest? _selected;
  bool _refreshing = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    if (!PluginManager.instance.isLoaded) {
      unawaited(PluginManager.instance.scan());
    }
  }

  Future<void> _reload() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await PluginManager.instance.reload();
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  Future<void> _installPlugin() async {
    if (_installing) return;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['zip'],
        dialogTitle: '选择插件 ZIP',
      );
      final path = files.firstOrNull?.path;
      if (path == null) return;
      setState(() => _installing = true);
      final manifest = await PluginManager.instance.installFromZip(path);
      if (!mounted) return;
      _showMessage('插件 ${manifest.name} 安装成功。');
    } on Object catch (error) {
      if (!mounted) return;
      LauncherLog.warning('Plugins', '安装插件失败：$error');
      _showMessage('安装失败：$error');
    } finally {
      if (mounted && _installing) {
        setState(() => _installing = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resetPermissions(PluginManifest manifest) async {
    try {
      await PluginPermissionService.instance.resetForPlugin(manifest.id);
      if (!mounted) return;
      _showMessage('已重置该插件的权限记录，下次执行敏感操作将重新询问。');
    } on Object catch (error) {
      if (!mounted) return;
      LauncherLog.warning('Plugins', '重置插件权限失败：$error');
      _showMessage('重置权限失败：$error');
    }
  }

  Future<void> _confirmUninstall(PluginManifest manifest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('卸载插件'),
        content: Text('确定卸载 ${manifest.name} 吗？插件目录和插件数据都会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('卸载'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await PluginManager.instance.uninstallPlugin(manifest.id);
      if (!mounted) return;
      if (_selected?.id == manifest.id) {
        setState(() => _selected = null);
      }
      _showMessage('插件 ${manifest.name} 已卸载，插件数据已清理。');
    } on Object catch (error) {
      if (!mounted) return;
      LauncherLog.warning('Plugins', '卸载插件失败：$error');
      _showMessage('卸载失败：$error');
    }
  }

  Future<void> _openPluginFolder(AppLocalizations l10n) async {
    final path = PluginManager.instance.pluginsDirectoryPath;
    if (path == null || path.trim().isEmpty) {
      _showMessage(l10n.pluginFolderUnavailable);
      return;
    }
    try {
      await PlatformLauncher.openPath(path);
    } on Object catch (error) {
      LauncherLog.warning('Plugins', '打开插件目录失败：$error');
      _showMessage(l10n.pluginFolderUnavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    if (selected != null) {
      return PluginPage(
        manifest: selected,
        onNavigate: widget.onNavigate,
        onLaunchGame: widget.onLaunchGame,
        onBack: () => setState(() => _selected = null),
      );
    }
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(l10n),
        const Divider(height: 1),
        Expanded(
          child: AnimatedBuilder(
            animation: PluginManager.instance,
            builder: (context, _) {
              final plugins = PluginManager.instance.plugins;
              if (plugins.isEmpty) return _empty(l10n);
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: plugins.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final manifest = plugins[index];
                  return _PluginTile(
                    manifest: manifest,
                    onTap: () => setState(() => _selected = manifest),
                    onResetPermissions: () => _resetPermissions(manifest),
                    onUninstall: () => _confirmUninstall(manifest),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _header(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Padding(
      padding: widget.showHeader
          ? const EdgeInsets.fromLTRB(24, 20, 16, 12)
          : const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.pluginsTitle, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    l10n.pluginsSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            const Spacer(),
          IconButton(
            tooltip: l10n.pluginOpenFolder,
            onPressed: () => _openPluginFolder(l10n),
            icon: const Icon(Icons.folder_open_rounded),
          ),
          IconButton(
            tooltip: '安装插件',
            onPressed: _installing || _refreshing ? null : _installPlugin,
            icon: _installing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: l10n.pluginsRefresh,
            onPressed: _refreshing || _installing ? null : _reload,
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _empty(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.extension_off_outlined,
              size: 44,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.pluginsEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _openPluginFolder(l10n),
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: Text(l10n.pluginOpenFolder),
            ),
          ],
        ),
      ),
    );
  }
}

class _PluginTile extends StatelessWidget {
  const _PluginTile({
    required this.manifest,
    required this.onTap,
    required this.onResetPermissions,
    required this.onUninstall,
  });

  final PluginManifest manifest;
  final VoidCallback onTap;
  final VoidCallback onResetPermissions;
  final VoidCallback onUninstall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final details = StringBuffer(
      l10n.pluginsVersionAuthor(
        manifest.version,
        manifest.author.isEmpty ? '-' : manifest.author,
      ),
    );
    if (manifest.permissions.isNotEmpty) {
      details
        ..write('  ·  ')
        ..write(l10n.pluginsPermissions(manifest.permissions.join(', ')));
    }
    final icon = manifest.icon == null
        ? Icons.extension_rounded
        : PluginIconMapper.getIcon(manifest.icon!);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(
          manifest.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (manifest.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(manifest.description, maxLines: 2),
            ],
            const SizedBox(height: 4),
            Text(details.toString()),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '重置权限',
              onPressed: onResetPermissions,
              icon: const Icon(Icons.security_update_good),
            ),
            IconButton(
              tooltip: '卸载',
              onPressed: onUninstall,
              icon: const Icon(Icons.delete),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
