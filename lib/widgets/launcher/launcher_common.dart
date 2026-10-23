import 'package:flutter/material.dart';

/// Launcher brand mark shared by the title bar, setup wizard and splash.
///
/// The packed artwork replaces the old hand-drawn block, so every surface
/// stays in sync with `assets/icons/launcher_logo.png`.
class BlockLogo extends StatelessWidget {
  const BlockLogo({super.key, this.size = 38, this.radius = 8});

  static const String assetPath = 'assets/icons/launcher_logo.png';

  /// Square edge length; the artwork is scaled without distortion.
  final double size;

  /// Corner rounding applied to the square artwork.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.grass,
            size: size * 0.62,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class TranslucentButtonSurface extends StatelessWidget {
  const TranslucentButtonSurface({
    super.key,
    required this.child,
    this.radius = 10,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? const Color(0x55414D3B) : const Color(0xA6F8FAF6),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

class TranslucentCircularButtonSurface extends StatelessWidget {
  const TranslucentCircularButtonSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipOval(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? const Color(0x55414D3B) : const Color(0xA6F8FAF6),
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(dimension: 48, child: Center(child: child)),
      ),
    );
  }
}
