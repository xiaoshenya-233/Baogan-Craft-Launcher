import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/plugin/plugin_action_dispatcher.dart';
import '../../services/plugin/plugin_manager.dart';
import '../../services/plugin/plugin_manifest.dart';
import '../../widgets/plugin/plugin_uac_dialog.dart';
import '../../widgets/plugin/plugin_ui_renderer.dart';

/// Renders one plugin's JSON UI inside the launcher shell.
///
/// Actions emitted by the document are routed through
/// [PluginActionDispatcher], so every host interaction is permission checked.
class PluginPage extends StatefulWidget {
  const PluginPage({
    super.key,
    required this.manifest,
    required this.onNavigate,
    required this.onLaunchGame,
    this.onBack,
  });

  final PluginManifest manifest;
  final PluginNavigateAction onNavigate;
  final PluginLaunchAction onLaunchGame;
  final VoidCallback? onBack;

  @override
  State<PluginPage> createState() => _PluginPageState();
}

class _PluginPageState extends State<PluginPage> {
  Map<String, dynamic>? _document;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final document = await PluginManager.instance.loadUiDocument(
      widget.manifest,
    );
    if (!mounted) return;
    setState(() {
      _document = document;
      _loading = false;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleAction(String action, Map<String, dynamic> params) async {
    final dispatcher = PluginActionDispatcher(
      onNavigate: widget.onNavigate,
      onLaunchGame: widget.onLaunchGame,
      onMessage: _showMessage,
      uacPrompt: (manifest, permission, path) => PluginUacDialog.show(
        manifest: manifest,
        permission: permission,
        path: path,
      ),
    );
    final result = await dispatcher.dispatch(widget.manifest, action, params);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (result.isSuccess) {
      final path = result.message ?? '';
      final feedback = switch (action.trim()) {
        'write_file' => l10n.pluginFileSaved(path),
        'read_file' => l10n.pluginFileRead(path),
        'download_file' => l10n.pluginFileDownloaded(path),
        _ => null,
      };
      if (feedback != null) _showMessage(feedback);
      return;
    }
    final message = switch (result.status) {
      PluginActionStatus.denied => l10n.pluginPermissionDenied(
        result.permission ?? '',
        action,
      ),
      PluginActionStatus.invalid => l10n.pluginActionInvalid(
        result.message ?? action,
      ),
      PluginActionStatus.failed => l10n.pluginActionFailed(
        result.message ?? '',
      ),
      PluginActionStatus.success => '',
    };
    _showMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, l10n),
        const Divider(height: 1),
        Expanded(child: _body(context, l10n)),
      ],
    );
  }

  Widget _header(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final manifest = widget.manifest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onBack != null) ...[
            IconButton(
              tooltip: l10n.pluginBack,
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
          ],
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.extension_rounded,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manifest.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.pluginsVersionAuthor(
                    manifest.version,
                    manifest.author.isEmpty ? '-' : manifest.author,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (manifest.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(manifest.description, style: theme.textTheme.bodySmall),
                ],
                if (manifest.permissions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.pluginsPermissions(manifest.permissions.join(', ')),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.pluginLoading),
          ],
        ),
      );
    }
    final document = _document;
    if (document == null) {
      final error = PluginManager.instance.lastError ?? l10n.pluginsNoUi;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.pluginsLoadFailed(error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: PluginUiRenderer(
        document: document,
        baseDirectory: widget.manifest.directoryPath,
        dataDirectory: PluginManager.instance.dataDirectoryFor(
          widget.manifest.id,
        ),
        grantedPermissions: widget.manifest.permissions.toSet(),
        onAction: _handleAction,
      ),
    );
  }
}
