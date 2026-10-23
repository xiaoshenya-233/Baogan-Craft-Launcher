import 'package:flutter/material.dart';

class LauncherShell extends StatelessWidget {
  const LauncherShell({
    super.key,
    required this.topBar,
    required this.sidebar,
    required this.content,
    required this.contentKey,
  });

  final Widget topBar;
  final Widget sidebar;
  final Widget content;
  final Key contentKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        topBar,
        Expanded(
          child: Row(
            children: [
              sidebar,
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slideAnimation = Tween<Offset>(
                      begin: const Offset(0.025, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: slideAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(key: contentKey, child: content),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
