import 'package:flutter/material.dart';

import '../../services/network/auth_service.dart';
import '../client_tile.dart';

class LoginMethodSheet extends StatelessWidget {
  const LoginMethodSheet({
    super.key,
    required this.currentMode,
    required this.colors,
  });

  final AuthMode currentMode;
  final LauncherUiColors colors;

  static Future<AuthMode?> show(
    BuildContext context, {
    required AuthMode currentMode,
    required LauncherUiColors colors,
  }) {
    return showModalBottomSheet<AuthMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) =>
          LoginMethodSheet(currentMode: currentMode, colors: colors),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
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
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: colors.accent,
                ),
                const SizedBox(width: 9),
                const Text(
                  '登录方式',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '当前：${currentMode.label}',
                  style: TextStyle(fontSize: 11, color: colors.muted),
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
                  for (
                    var index = 0;
                    index < AuthMode.values.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(height: 8),
                    _LoginModeRow(
                      mode: AuthMode.values[index],
                      selected: AuthMode.values[index] == currentMode,
                      colors: colors,
                      onTap: () =>
                          Navigator.pop(context, AuthMode.values[index]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '选择后会立即保存。账号资料将在启动游戏时填写；'
                    '离线玩家名称和认证服务器等信息会保存在本机。',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.muted,
                      height: 1.5,
                    ),
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

class _LoginModeRow extends StatelessWidget {
  const _LoginModeRow({
    required this.mode,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final AuthMode mode;
  final bool selected;
  final LauncherUiColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (mode) {
      AuthMode.offline => Icons.person_outline_rounded,
      AuthMode.microsoft => Icons.account_circle_outlined,
      AuthMode.thirdParty => Icons.dns_outlined,
    };
    final description = switch (mode) {
      AuthMode.offline => '使用玩家名称进入单人世界及允许离线登录的服务器。',
      AuthMode.microsoft => '启动时通过 Microsoft 设备码登录正版账号。',
      AuthMode.thirdParty =>
        '使用 LittleSkin 等 Yggdrasil 服务；启动器内置 authlib-injector。',
    };
    return Material(
      color: selected ? colors.selectedSurface : colors.panelAccent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? colors.accent : colors.border),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? colors.accent : colors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: colors.accent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
