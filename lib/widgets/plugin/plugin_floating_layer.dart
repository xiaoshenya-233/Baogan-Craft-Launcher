import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/plugin/plugin_action_dispatcher.dart';
import '../../services/plugin/plugin_manager.dart';
import '../../services/plugin/plugin_manifest.dart';
import 'plugin_uac_dialog.dart';
import 'plugin_ui_renderer.dart';

/// Anchors plugin floating UIs to the corners of the launcher window.
///
/// The layer only builds a [Stack] with corner [Positioned] cards; empty areas
/// do not absorb pointer events, so the launcher below stays interactive.
class PluginFloatingLayer extends StatefulWidget {
  const PluginFloatingLayer({
    super.key,
    required this.items,
    required this.onNavigate,
    required this.onLaunchGame,
  });

  final List<PluginFloatingUi> items;
  final PluginNavigateAction onNavigate;
  final PluginLaunchAction onLaunchGame;

  @override
  State<PluginFloatingLayer> createState() => _PluginFloatingLayerState();
}

class _PluginFloatingLayerState extends State<PluginFloatingLayer> {
  static const double _margin = 24;

  Future<void> _dispatch(
    PluginFloatingUi ui,
    String action,
    Map<String, dynamic> params,
  ) async {
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
    final result = await dispatcher.dispatch(ui.manifest, action, params);
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: [for (final ui in widget.items) _positioned(context, ui)],
    );
  }

  Widget _positioned(BuildContext context, PluginFloatingUi ui) {
    final position = ui.config.position;
    final atTop =
        position == PluginFloatingPosition.topLeft ||
        position == PluginFloatingPosition.topRight;
    final atLeft =
        position == PluginFloatingPosition.topLeft ||
        position == PluginFloatingPosition.bottomLeft;
    return Positioned(
      top: atTop ? _margin : null,
      bottom: atTop ? null : _margin,
      left: atLeft ? _margin : null,
      right: atLeft ? null : _margin,
      child: _FloatingCard(
        ui: ui,
        onAction: (action, params) => _dispatch(ui, action, params),
      ),
    );
  }
}

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({required this.ui, required this.onAction});

  static const double _width = 300;

  final PluginFloatingUi ui;
  final PluginActionCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 10,
      color: theme.colorScheme.surface.withValues(alpha: 0.97),
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: _width,
        constraints: const BoxConstraints(maxHeight: 360),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: SingleChildScrollView(
          child: PluginUiRenderer(
            document: ui.document,
            baseDirectory: ui.manifest.directoryPath,
            dataDirectory: PluginManager.instance.dataDirectoryFor(
              ui.manifest.id,
            ),
            grantedPermissions: ui.manifest.permissions.toSet(),
            onAction: onAction,
          ),
        ),
      ),
    );
  }
}
