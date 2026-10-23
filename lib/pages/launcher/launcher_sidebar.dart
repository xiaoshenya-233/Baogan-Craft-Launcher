import 'package:flutter/material.dart';

import 'controllers/launcher_shell_controller.dart';
import 'launcher_palette.dart';

class LauncherSidebar extends StatelessWidget {
  const LauncherSidebar({
    super.key,
    required this.selectedTab,
    required this.onSelected,
    required this.isDark,
  });

  final LauncherTab selectedTab;
  final ValueChanged<LauncherTab> onSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.fromDark(isDark);
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: palette.dark ? const Color(0xCC151B15) : const Color(0xDDF8FAF6),
        border: Border(right: BorderSide(color: palette.panelBorderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _groupLabel(palette, '启动器'),
          _navItem(palette, Icons.home_rounded, '主页', LauncherTab.home),
          _navItem(
            palette,
            Icons.inventory_2_outlined,
            '版本管理',
            LauncherTab.versions,
          ),
          _navItem(
            palette,
            Icons.cloud_download_outlined,
            '资源下载',
            LauncherTab.downloads,
          ),
          _navItem(
            palette,
            Icons.settings_outlined,
            '设置',
            LauncherTab.settings,
          ),
          const SizedBox(height: 14),
          Divider(color: palette.panelBorderColor, height: 1),
          const SizedBox(height: 14),
          _groupLabel(palette, '实用工具'),
          _navItem(
            palette,
            Icons.downloading_rounded,
            '下载任务',
            LauncherTab.downloadTasks,
          ),
          _navItem(
            palette,
            Icons.handyman_outlined,
            '工作台',
            LauncherTab.workbench,
          ),
        ],
      ),
    );
  }

  Widget _groupLabel(LauncherPalette palette, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 2),
      child: Text(
        label,
        style: TextStyle(
          color: palette.muted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _navItem(
    LauncherPalette palette,
    IconData icon,
    String label,
    LauncherTab tab,
  ) {
    final selected = selectedTab == tab;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected
            ? palette.dark
                  ? const Color(0xFF293522)
                  : const Color(0xFFDDEBD1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => onSelected(tab),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  icon,
                  size: 19,
                  color: selected ? palette.uiColors.accent : palette.muted,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected
                        ? (palette.dark
                              ? Colors.white
                              : const Color(0xFF26351F))
                        : palette.muted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (selected) ...[
                  const Spacer(),
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: palette.uiColors.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 2),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
