import 'package:flutter/material.dart';

import '../../widgets/launcher/launcher_common.dart';
import 'setup_window_bar.dart';

class LauncherStartupSplash extends StatelessWidget {
  const LauncherStartupSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF101510) : const Color(0xFFF1F4ED),
      body: Stack(
        children: [
          const Positioned(top: 0, left: 0, right: 0, child: SetupWindowBar()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BlockLogo(size: 72, radius: 16),
                const SizedBox(height: 18),
                Text(
                  'Baogan Craft Launcher',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: dark ? Colors.white : const Color(0xFF26351F),
                  ),
                ),
                const SizedBox(height: 18),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
