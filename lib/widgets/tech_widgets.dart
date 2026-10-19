import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:luvedube/theme/app_theme.dart';

/// Animated dark background: drifting neon glows + slowly scrolling grid.
class TechBackground extends StatefulWidget {
  const TechBackground({super.key, required this.child});
  final Widget child;

  @override
  State<TechBackground> createState() => _TechBackgroundState();
}

class _TechBackgroundState extends State<TechBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 16))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(painter: _GridPainter(_c.value)),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Tech.bg);

    void glow(Offset c, double r, Color col) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            col.withValues(alpha: .20),
            col.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    final a = t * 2 * math.pi;
    glow(
      Offset(size.width * (.2 + .1 * math.sin(a)),
          size.height * (.12 + .05 * math.cos(a))),
      size.width * .95,
      Tech.violet,
    );
    glow(
      Offset(size.width * (.85 + .08 * math.cos(a)),
          size.height * (.88 + .05 * math.sin(a))),
      size.width * .95,
      Tech.cyan,
    );

    const step = 38.0;
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .035)
      ..strokeWidth = 1;
    final off = (t * step * 3) % step;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = off; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.t != t;
}

/// Translucent "glass" panel with optional neon accent border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.accent,
    this.radius = 18,
    this.blur = false,
    this.baseColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? accent;
  final double radius;
  final bool blur;
  final Color? baseColor;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: r,
        color: baseColor,
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: .07),
            Colors.white.withValues(alpha: .025),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: accent == null
              ? Colors.white.withValues(alpha: .09)
              : accent!.withValues(alpha: .35),
        ),
        boxShadow: accent == null
            ? null
            : [BoxShadow(color: accent!.withValues(alpha: .12), blurRadius: 18)],
      ),
      child: child,
    );
    if (!blur) return inner;
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: inner,
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  const GradientText(this.text,
      {super.key, required this.gradient, required this.style, this.align});
  final String text;
  final Gradient gradient;
  final TextStyle style;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (b) =>
          gradient.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
      child: Text(text, style: style, textAlign: align),
    );
  }
}

/// Glowing gradient call-to-action button.
class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.gradient = Tech.brand,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(16);
    return Opacity(
      opacity: onTap == null ? .45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [
            BoxShadow(
              color: Tech.violet.withValues(alpha: .45),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(gradient: gradient, borderRadius: r),
            child: InkWell(
              borderRadius: r,
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        letterSpacing: .4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
