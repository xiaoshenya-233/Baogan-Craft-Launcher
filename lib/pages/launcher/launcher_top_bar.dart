import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../widgets/launcher/launcher_common.dart';

class LauncherTopBar extends StatelessWidget {
  const LauncherTopBar({
    super.key,
    required this.activeDownloadBanner,
    required this.isDark,
    required this.isMaximized,
    required this.onStartDrag,
    required this.onToggleMaximize,
    required this.onMinimize,
    required this.onClose,
  });

  final Widget? activeDownloadBanner;
  final bool isDark;
  final bool isMaximized;
  final Future<void> Function() onStartDrag;
  final Future<void> Function() onToggleMaximize;
  final Future<void> Function() onMinimize;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    final dark = isDark;
    final windowButtonColor = dark ? Colors.white : const Color(0xFF26351F);
    return SizedBox(
      height: 72,
      child: Stack(
        children: [
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: dark ? const Color(0xCC171D17) : const Color(0xDDF8FAF6),
              border: Border(
                bottom: BorderSide(
                  color: dark
                      ? const Color(0xFF2A3228)
                      : const Color(0xFFD8E0D2),
                ),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onPanStart: (_) => unawaited(onStartDrag()),
                  onDoubleTap: () => unawaited(onToggleMaximize()),
                  child: const BlockLogo(),
                ),
                const SizedBox(width: 13),
                GestureDetector(
                  onPanStart: (_) => unawaited(onStartDrag()),
                  onDoubleTap: () => unawaited(onToggleMaximize()),
                  child: Text(
                    'Baogan Craft Launcher',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: dark ? Colors.white : const Color(0xFF26351F),
                    ),
                  ),
                ),
                if (activeDownloadBanner != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: activeDownloadBanner,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (Platform.isWindows)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  _windowControlButton(
                    tooltip: '最小化',
                    icon: Icons.minimize_rounded,
                    onPressed: onMinimize,
                    color: windowButtonColor,
                  ),
                  _windowControlButton(
                    tooltip: isMaximized ? '还原' : '最大化',
                    icon: isMaximized
                        ? Icons.filter_none_rounded
                        : Icons.crop_square_rounded,
                    onPressed: onToggleMaximize,
                    color: windowButtonColor,
                  ),
                  _windowControlButton(
                    tooltip: '关闭',
                    icon: Icons.close_rounded,
                    onPressed: onClose,
                    color: windowButtonColor,
                    hoverColor: const Color(0xFFE81123),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _windowControlButton({
    required String tooltip,
    required IconData icon,
    required Future<void> Function() onPressed,
    required Color color,
    Color? hoverColor,
  }) {
    return SizedBox(
      width: 42,
      height: 42,
      child: IconButton(
        tooltip: tooltip,
        onPressed: () => unawaited(onPressed()),
        icon: Icon(icon, size: 17),
        color: color,
        hoverColor: hoverColor?.withValues(alpha: 0.9),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}
