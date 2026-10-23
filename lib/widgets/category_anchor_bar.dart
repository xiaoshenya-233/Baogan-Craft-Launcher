import 'dart:ui';

import 'package:flutter/material.dart';

/// Floating capsule navigation bar that scrolls the page to a section.
///
/// [anchors] maps a section title to the [GlobalKey] placed on that section's
/// root widget; the section must live inside a scrollable view for
/// [Scrollable.ensureVisible] to work. Pages place it in a [Stack] pinned to
/// the bottom, so it stays visible while the content scrolls. The capsule fades
/// and slides in when it first appears instead of popping into place.
class CategoryAnchorBar extends StatefulWidget {
  const CategoryAnchorBar({
    super.key,
    required this.anchors,
    this.padding = EdgeInsets.zero,
  });

  final Map<String, GlobalKey> anchors;
  final EdgeInsetsGeometry padding;

  @override
  State<CategoryAnchorBar> createState() => _CategoryAnchorBarState();
}

class _CategoryAnchorBarState extends State<CategoryAnchorBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.4),
    end: Offset.zero,
  ).animate(_curve);
  late final Animation<double> _scale = Tween<double>(
    begin: 0.9,
    end: 1,
  ).animate(_curve);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _jump(GlobalKey key) async {
    final target = key.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.anchors.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(28);
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: Padding(
            padding: widget.padding,
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Material(
                  color: dark
                      ? Colors.black.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.72),
                  borderRadius: radius,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                        width: 0.6,
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final entry in widget.anchors.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: ActionChip(
                                label: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () => _jump(entry.value),
                                backgroundColor:
                                    scheme.surfaceContainerHighest.withValues(
                                      alpha: dark ? 0.35 : 0.85,
                                    ),
                                side: BorderSide(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                shape: const StadiumBorder(),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
