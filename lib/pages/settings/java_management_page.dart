import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/java/java_service.dart';
import '../launcher/controllers/java_environment_controller.dart';
import '../launcher/launcher_palette.dart';

/// Standalone Java management page.
///
/// It only lists detected runtimes, starts a scan, adds a custom executable and
/// removes list entries. Choosing the default Java belongs to the global
/// settings page, so nothing here touches the selection.
class JavaManagementPage extends StatefulWidget {
  const JavaManagementPage({
    super.key,
    required this.palette,
    required this.java,
    required this.onDiscover,
    required this.onPick,
    required this.onRemove,
    required this.onMessage,
    required this.onBack,
  });

  final LauncherPalette palette;
  final JavaEnvironmentController java;
  final VoidCallback onDiscover;
  final VoidCallback onPick;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onMessage;

  /// Restores the settings content; this page is embedded in the settings tab
  /// so the launcher sidebar and header stay visible.
  final VoidCallback onBack;

  @override
  State<JavaManagementPage> createState() => _JavaManagementPageState();
}

class _JavaManagementPageState extends State<JavaManagementPage> {
  final TextEditingController _pathController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _applyTypedPath() async {
    final l10n = AppLocalizations.of(context)!;
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      widget.onMessage(l10n.javaEnterPath);
      return;
    }
    if (!await File(path).exists()) {
      widget.onMessage(l10n.javaPathMissing(path));
      return;
    }
    setState(() => _isAdding = true);
    final runtime = await widget.java.registerExecutable(path);
    if (!mounted) return;
    setState(() => _isAdding = false);
    if (runtime == null) {
      widget.onMessage(l10n.javaUnrecognized);
      return;
    }
    _pathController.clear();
    widget.onMessage(l10n.javaAdded(runtime.executable));
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.javaBackToSettings,
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.javaPageTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: widget.java,
              builder: (context, _) {
                final java = widget.java;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
              Text(
                l10n.javaPageSubtitle,
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: java.isLoading ? null : widget.onDiscover,
                    icon: const Icon(Icons.manage_search_rounded, size: 16),
                    label: Text(l10n.javaAutoScan),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onPick,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(l10n.javaAddPath),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (java.isLoading) const LinearProgressIndicator(minHeight: 2),
              if (java.loadError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    java.loadError!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE05B5B),
                    ),
                  ),
                ),
              if (!java.isLoading && java.runtimes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    java.hasSearched
                        ? l10n.javaNoRuntime
                        : l10n.javaNotScanned,
                    style: TextStyle(fontSize: 11.5, color: palette.muted),
                  ),
                )
              else
                for (final runtime in java.runtimes)
                  _buildRuntimeTile(runtime, palette),
              const SizedBox(height: 18),
              _buildCustomPathCard(palette),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuntimeTile(JavaRuntime runtime, LauncherPalette palette) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: palette.panelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.panelBorderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: palette.uiColors.accent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              runtime.majorVersion == 0
                  ? 'Java ?'
                  : 'Java ${runtime.majorVersion}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              runtime.executable,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: palette.muted),
            ),
          ),
          IconButton(
            tooltip: l10n.javaRemoveTooltip,
            onPressed: () => widget.onRemove(runtime.executable),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: palette.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomPathCard(LauncherPalette palette) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.panelBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.javaDialogTitle,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.javaDialogHint,
            style: TextStyle(fontSize: 10.5, color: palette.muted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pathController,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.javaPathExample,
              hintStyle: TextStyle(fontSize: 11.5, color: palette.muted),
              border: const OutlineInputBorder(),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton(
                  onPressed: _isAdding ? null : _applyTypedPath,
                  child: Text(_isAdding ? l10n.javaDetecting : l10n.actionAdd),
                ),
              ),
            ),
            onSubmitted: (_) => _applyTypedPath(),
          ),
        ],
      ),
    );
  }
}
