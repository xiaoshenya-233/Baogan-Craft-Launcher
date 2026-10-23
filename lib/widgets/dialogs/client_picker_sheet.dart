import 'dart:async';

import 'package:flutter/material.dart';

import '../client_tile.dart';

class ClientPickerSheet extends StatelessWidget {
  const ClientPickerSheet({
    super.key,
    required this.clients,
    required this.selectedDirectoryPath,
    required this.isLoading,
    required this.isReloading,
    required this.colors,
    required this.onReload,
    required this.onSelect,
    required this.onAddFolder,
    required this.onDownload,
  });

  final List<ClientTileData> clients;
  final String? selectedDirectoryPath;
  final bool isLoading;
  final bool isReloading;
  final LauncherUiColors colors;
  final Future<void> Function() onReload;
  final Future<void> Function(String directoryPath) onSelect;
  final VoidCallback onAddFolder;
  final VoidCallback onDownload;

  static Future<void> show(
    BuildContext context, {
    required List<ClientTileData> clients,
    required String? selectedDirectoryPath,
    required bool isLoading,
    required LauncherUiColors colors,
    required Future<List<ClientTileData>> Function() onReload,
    required Future<void> Function(String directoryPath) onSelect,
    required VoidCallback onAddFolder,
    required VoidCallback onDownload,
  }) {
    final state = _ClientPickerState(clients);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => ClientPickerSheet(
          clients: state.clients,
          selectedDirectoryPath: selectedDirectoryPath,
          isLoading: isLoading,
          isReloading: state.isReloading,
          colors: colors,
          onReload: () async {
            if (state.isReloading) return;
            setSheetState(() => state.isReloading = true);
            try {
              final updated = await onReload();
              if (sheetContext.mounted) {
                setSheetState(() => state.clients = updated);
              }
            } finally {
              if (sheetContext.mounted) {
                setSheetState(() => state.isReloading = false);
              }
            }
          },
          onSelect: onSelect,
          onAddFolder: onAddFolder,
          onDownload: onDownload,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReloading = this.isReloading;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.74,
      ),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 4),
            child: Row(
              children: [
                const Text(
                  '切换客户端',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  '${clients.length} 个已安装',
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '重新扫描',
                  onPressed: isReloading ? null : () => unawaited(onReload()),
                  icon: isReloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (clients.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      child: ClientPickerEmptyState(
                        isLoading: isReloading || isLoading,
                        colors: colors,
                      ),
                    )
                  else ...[
                    for (var index = 0; index < clients.length; index++) ...[
                      if (index > 0) const SizedBox(height: 8),
                      ClientTile(
                        data: clients[index],
                        selected:
                            clients[index].directoryPath ==
                            selectedDirectoryPath,
                        colors: colors,
                        onTap: () async {
                          await onSelect(clients[index].directoryPath);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: isReloading
                            ? null
                            : () => unawaited(onReload()),
                        icon: const Icon(Icons.manage_search_rounded, size: 16),
                        label: const Text('重新扫描'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onAddFolder();
                        },
                        icon: const Icon(Icons.folder_open_outlined, size: 16),
                        label: const Text('选择文件夹'),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDownload();
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('下载 Minecraft'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientPickerState {
  _ClientPickerState(this.clients);

  List<ClientTileData> clients;
  bool isReloading = false;
}

class ClientPickerEmptyState extends StatelessWidget {
  const ClientPickerEmptyState({
    super.key,
    required this.isLoading,
    required this.colors,
  });

  final bool isLoading;
  final LauncherUiColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: colors.panelAccent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.folder_open_outlined,
            size: 25,
            color: colors.accent,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isLoading ? '正在扫描已安装客户端…' : '尚未检测到客户端',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '选择 .minecraft 文件夹，或下载 Minecraft 后，\n这里会列出所有可启动的客户端。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: colors.muted, height: 1.5),
        ),
      ],
    );
  }
}
