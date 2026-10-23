import 'package:flutter/material.dart';

import '../client_tile.dart';

class ClientConfigSheet extends StatelessWidget {
  const ClientConfigSheet({
    super.key,
    required this.versionId,
    required this.loaderLabel,
    required this.directoryPath,
    required this.minecraftPath,
    required this.javaLabel,
    required this.memoryGb,
    required this.accountLabel,
    required this.colors,
    required this.onOpenDirectory,
    required this.onOpenVersionDetails,
    required this.onOpenSettings,
  });

  final String versionId;
  final String loaderLabel;
  final String directoryPath;
  final String minecraftPath;
  final String javaLabel;
  final int memoryGb;
  final String accountLabel;
  final LauncherUiColors colors;
  final VoidCallback onOpenDirectory;
  final VoidCallback onOpenVersionDetails;
  final VoidCallback onOpenSettings;

  static Future<void> show(
    BuildContext context, {
    required String versionId,
    required String loaderLabel,
    required String directoryPath,
    required String minecraftPath,
    required String javaLabel,
    required int memoryGb,
    required String accountLabel,
    required LauncherUiColors colors,
    required VoidCallback onOpenDirectory,
    required VoidCallback onOpenVersionDetails,
    required VoidCallback onOpenSettings,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) => ClientConfigSheet(
        versionId: versionId,
        loaderLabel: loaderLabel,
        directoryPath: directoryPath,
        minecraftPath: minecraftPath,
        javaLabel: javaLabel,
        memoryGb: memoryGb,
        accountLabel: accountLabel,
        colors: colors,
        onOpenDirectory: onOpenDirectory,
        onOpenVersionDetails: onOpenVersionDetails,
        onOpenSettings: onOpenSettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
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
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 18, color: colors.accent),
                const SizedBox(width: 9),
                const Text(
                  '游戏配置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    versionId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.muted),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClientConfigRow(
                    icon: Icons.layers_outlined,
                    label: '加载器',
                    value: loaderLabel,
                    colors: colors,
                  ),
                  ClientConfigRow(
                    icon: Icons.folder_outlined,
                    label: '客户端目录',
                    value: directoryPath,
                    maxLines: 2,
                    colors: colors,
                  ),
                  ClientConfigRow(
                    icon: Icons.inventory_2_outlined,
                    label: '来源文件夹',
                    value: minecraftPath,
                    maxLines: 2,
                    colors: colors,
                  ),
                  ClientConfigRow(
                    icon: Icons.coffee_outlined,
                    label: 'Java',
                    value: javaLabel,
                    colors: colors,
                  ),
                  ClientConfigRow(
                    icon: Icons.memory_rounded,
                    label: '内存',
                    value: '$memoryGb GB',
                    colors: colors,
                  ),
                  ClientConfigRow(
                    icon: Icons.person_outline_rounded,
                    label: '账号',
                    value: accountLabel,
                    colors: colors,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onOpenDirectory();
                        },
                        icon: const Icon(Icons.folder_open_outlined, size: 16),
                        label: const Text('打开目录'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onOpenVersionDetails();
                        },
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: const Text('版本详情'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onOpenSettings();
                        },
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text('调整配置'),
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

class ClientConfigRow extends StatelessWidget {
  const ClientConfigRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    this.maxLines = 1,
  });

  final IconData icon;
  final String label;
  final String value;
  final LauncherUiColors colors;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colors.accent),
          const SizedBox(width: 10),
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: colors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
