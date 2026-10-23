import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../../../services/installer/version_models.dart';
import '../../../services/network/models.dart';
import '../../../widgets/version_icon.dart';

/// Outcome of [TargetClientPicker].
///
/// Either a concrete client was picked, or the user chose a directory by hand.
class TargetClientSelection {
  const TargetClientSelection.client(LauncherVersion this.client)
    : customPath = null;

  const TargetClientSelection.customPath(String this.customPath)
    : client = null;

  final LauncherVersion? client;
  final String? customPath;

  bool get isCustomPath => customPath != null;
}

/// `target` is null when the user picked a directory manually.
typedef TargetClientCallback =
    void Function(LauncherVersion? target, String? customPath);

/// Material 3 dialog that asks where a mod/resource should be installed.
///
/// Clients whose Minecraft version and loader are covered by the resource are
/// highlighted; the first compatible client is preselected so the common case
/// is a single click. Closing the dialog returns `null` (cancel the download).
class TargetClientPicker extends StatefulWidget {
  const TargetClientPicker({
    super.key,
    required this.clients,
    required this.gameVersions,
    required this.loaders,
    this.modTitle,
    this.onTargetSelected,
  });

  /// Convenience constructor for a concrete repository version.
  factory TargetClientPicker.fromVersion({
    Key? key,
    required ModrinthVersion version,
    required List<LauncherVersion> clients,
    String? modTitle,
    TargetClientCallback? onTargetSelected,
  }) => TargetClientPicker(
    key: key,
    clients: clients,
    gameVersions: version.gameVersions,
    loaders: version.loaders,
    modTitle: modTitle,
    onTargetSelected: onTargetSelected,
  );

  final List<LauncherVersion> clients;

  /// Minecraft versions the resource supports (`1.20.1`, `1.21`, ...).
  final List<String> gameVersions;

  /// Supported loader tags (`fabric`, `forge`, `neoforge`, `quilt`, ...).
  final List<String> loaders;

  final String? modTitle;
  final TargetClientCallback? onTargetSelected;

  /// Opens the dialog and resolves to the chosen target, or `null` on cancel.
  static Future<TargetClientSelection?> show(
    BuildContext context, {
    required List<LauncherVersion> clients,
    required List<String> gameVersions,
    required List<String> loaders,
    String? modTitle,
    TargetClientCallback? onTargetSelected,
  }) {
    return showDialog<TargetClientSelection>(
      context: context,
      builder: (_) => TargetClientPicker(
        clients: clients,
        gameVersions: gameVersions,
        loaders: loaders,
        modTitle: modTitle,
        onTargetSelected: onTargetSelected,
      ),
    );
  }

  @override
  State<TargetClientPicker> createState() => _TargetClientPickerState();
}

class _TargetClientPickerState extends State<TargetClientPicker> {
  LauncherVersion? _selectedClient;
  bool _isPickingFolder = false;
  String? _pickerError;

  @override
  void initState() {
    super.initState();
    // Smart default: first client whose version and loader both match.
    for (final client in widget.clients) {
      if (_isCompatible(client)) {
        _selectedClient = client;
        break;
      }
    }
  }

  Set<String> get _normalizedLoaders => widget.loaders
      .map(_normalizeLoader)
      .where((loader) => loader.isNotEmpty)
      .toSet();

  bool get _hasVersionFilter => widget.gameVersions.isNotEmpty;

  bool get _hasLoaderFilter => _normalizedLoaders.isNotEmpty;

  bool _matchesVersion(LauncherVersion client) {
    if (!_hasVersionFilter) return true;
    final minecraftVersion = client.minecraftVersion?.trim();
    if (minecraftVersion == null || minecraftVersion.isEmpty) return false;
    return widget.gameVersions.any(
      (version) =>
          version.trim().toLowerCase() == minecraftVersion.toLowerCase(),
    );
  }

  bool _matchesLoader(LauncherVersion client) {
    if (!_hasLoaderFilter) return true;
    return _normalizedLoaders.contains(_normalizeLoader(client.loaderType));
  }

  bool _isCompatible(LauncherVersion client) =>
      _matchesVersion(client) && _matchesLoader(client);

  static String _normalizeLoader(String? loaderType) {
    final value = (loaderType ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(' ', '');
    if (value.isEmpty || value == 'vanilla' || value == '原版') return 'vanilla';
    if (value.contains('neoforge')) return 'neoforge';
    if (value.contains('forge')) return 'forge';
    if (value.contains('fabric')) return 'fabric';
    if (value.contains('quilt')) return 'quilt';
    return value;
  }

  void _confirmClient() {
    final client = _selectedClient;
    if (client == null) return;
    widget.onTargetSelected?.call(client, null);
    Navigator.of(context).pop(TargetClientSelection.client(client));
  }

  Future<void> _pickFolder() async {
    if (_isPickingFolder) return;
    setState(() {
      _isPickingFolder = true;
      _pickerError = null;
    });
    String? path;
    try {
      path = await FilePicker.getDirectoryPath(
        dialogTitle: '选择客户端目录（version 文件夹）',
      );
    } on FormatException catch (error) {
      path = null;
      _pickerError = error.message;
    } on PlatformException catch (error) {
      path = null;
      _pickerError = error.message ?? error.code;
    }
    if (!mounted) return;
    setState(() => _isPickingFolder = false);
    if (path == null || path.trim().isEmpty) return;
    _finishWithCustomPath(path.trim());
  }

  void _finishWithCustomPath(String path) {
    widget.onTargetSelected?.call(null, path);
    Navigator.of(context).pop(TargetClientSelection.customPath(path));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = math.max(260.0, math.min(520.0, screenWidth - 96));
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Row(
        children: [
          Icon(Icons.folder_special_outlined, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '选择目标客户端',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.modTitle == null || widget.modTitle!.trim().isEmpty
                  ? '选择要把资源安装到哪个客户端。'
                  : '为「${widget.modTitle!.trim()}」选择安装位置。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _supportSummary(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.clients.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '还没有可用客户端，请先在版本管理中安装客户端。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: widget.clients.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildClientCard(widget.clients[index]),
                  ),
                ),
              ),
            if (_pickerError != null) ...[
              const SizedBox(height: 8),
              Text(
                '无法选择文件夹：$_pickerError',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        Wrap(
          spacing: 4,
          children: [
            TextButton.icon(
              onPressed: _isPickingFolder ? null : _pickFolder,
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: const Text('让我自己决定放在哪'),
            ),
            FilledButton(
              onPressed: _selectedClient == null ? null : _confirmClient,
              child: const Text('确认安装'),
            ),
          ],
        ),
      ],
    );
  }

  String _supportSummary() {
    final parts = <String>[];
    if (_hasVersionFilter) {
      final versions = widget.gameVersions.take(5).join(' / ');
      final suffix = widget.gameVersions.length > 5 ? ' 等' : '';
      parts.add('支持版本：$versions$suffix');
    }
    if (_hasLoaderFilter) {
      parts.add('支持加载器：${widget.loaders.join(' / ')}');
    }
    if (parts.isEmpty) return '该资源未声明版本或加载器限制，所有客户端均可安装。';
    return parts.join(' · ');
  }


  Widget _buildClientCard(LauncherVersion client) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _selectedClient?.path == client.path;
    final compatible = _isCompatible(client);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedClient = client),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.55)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              VersionIcon(version: client, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _clientSubtitle(client),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (compatible)
                _buildBadge('兼容', scheme.primary)
              else
                _buildBadge('版本不符', scheme.outline),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _clientSubtitle(LauncherVersion client) {
    final minecraft = client.minecraftVersion?.trim();
    final loader = client.loaderType?.trim();
    final parts = <String>[
      if (minecraft != null && minecraft.isNotEmpty) 'Minecraft $minecraft',
      if (loader != null && loader.isNotEmpty) loader,
    ];
    if (parts.isEmpty) parts.add('未知版本');
    return parts.join(' · ');
  }

}
