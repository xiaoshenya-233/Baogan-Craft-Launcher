import 'package:flutter/material.dart';

import '../../../core/platform_launcher.dart';
import '../../../widgets/launcher/launcher_common.dart';

/// Public metadata shown in the about dialog.
const String launcherRepoUrl =
    'https://github.com/xiaoshenya-233/Baogan-Craft-Launcher';
const String launcherVersion = '26.1Alpha1';

class _CreditEntry {
  const _CreditEntry(this.name, this.description, this.icon);

  final String name;
  final String description;
  final IconData icon;
}

const List<_CreditEntry> _credits = <_CreditEntry>[
  _CreditEntry(
    'PCL2',
    'Plain Craft Launcher 2 · 界面交互与整合包安装流程参考',
    Icons.auto_awesome_rounded,
  ),
  _CreditEntry(
    'HMCL',
    'Hello Minecraft! Launcher · 加载器识别与 Java 管理思路参考',
    Icons.memory_rounded,
  ),
  _CreditEntry(
    'XMCL',
    'X Minecraft Launcher · 资源管理与视觉设计参考',
    Icons.rocket_launch_rounded,
  ),
  _CreditEntry('BMCLAPI', '提供 Minecraft 资源下载加速服务', Icons.speed_rounded),
];

/// Shows the GPLv3 / credits dialog.
Future<void> showAboutLauncherDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const AboutLauncherDialog(),
  );
}

/// Material 3 about dialog: version, licence, repository and credits.
class AboutLauncherDialog extends StatelessWidget {
  const AboutLauncherDialog({super.key});

  Future<void> _openRepository(BuildContext context) async {
    try {
      await PlatformLauncher.openUrl(launcherRepoUrl);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('无法打开浏览器：$error')),
      );
    }
  }

  Widget _sectionTitle(ColorScheme scheme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 12, 0),
              child: Row(
                children: [
                  const BlockLogo(size: 52, radius: 13),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Baogan Craft Launcher',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '版本 $launcherVersion · GPLv3 开源',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 22),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(scheme, Icons.gavel_rounded, '开源协议'),
                    const SizedBox(height: 8),
                    _buildLicenceCard(scheme),
                    const SizedBox(height: 18),
                    _sectionTitle(scheme, Icons.code_rounded, 'GitHub 仓库'),
                    const SizedBox(height: 8),
                    _buildRepositoryLink(context, scheme),
                    const SizedBox(height: 18),
                    _sectionTitle(scheme, Icons.favorite_rounded, '核心鸣谢'),
                    const SizedBox(height: 8),
                    for (final credit in _credits) _buildCredit(credit, scheme),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '感谢所有开源项目与社区贡献者。',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenceCard(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GPLv3',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '本项目基于 GPLv3 协议开源：你可以自由使用、修改与分发，'
            '但衍生作品必须同样以 GPLv3 开放源代码，并保留原始版权声明。',
            style: TextStyle(fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRepositoryLink(BuildContext context, ColorScheme scheme) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openRepository(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.link_rounded, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                launcherRepoUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: scheme.primary),
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 15,
              color: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredit(_CreditEntry credit, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(credit.icon, size: 16, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  credit.name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  credit.description,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
