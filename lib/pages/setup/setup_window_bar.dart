import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../widgets/launcher/launcher_common.dart';

class SetupWindowBar extends StatelessWidget {
  const SetupWindowBar({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {
                if (Platform.isWindows) {
                  unawaited(windowManager.startDragging());
                }
              },
              onDoubleTap: () {
                if (Platform.isWindows) unawaited(_toggleMaximize());
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    const BlockLogo(),
                    const SizedBox(width: 12),
                    Text(
                      'Baogan Craft Launcher',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: dark ? Colors.white : const Color(0xFF26351F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (Platform.isWindows) ...[
            IconButton(
              tooltip: '最小化',
              onPressed: () => unawaited(windowManager.minimize()),
              icon: const Icon(Icons.minimize_rounded, size: 17),
              color: dark ? Colors.white : const Color(0xFF26351F),
            ),
            IconButton(
              tooltip: '关闭',
              onPressed: () => unawaited(windowManager.close()),
              icon: const Icon(Icons.close_rounded, size: 17),
              color: dark ? Colors.white : const Color(0xFF26351F),
              hoverColor: const Color(0xFFE81123),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }
}
