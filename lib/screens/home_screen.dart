import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:luvedube/screens/write_song_screen.dart';
import 'package:luvedube/theme/app_theme.dart';
import 'package:luvedube/widgets/tech_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _spin;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _fade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, .4, curve: Curves.easeIn),
    );
    _slide = Tween<Offset>(begin: const Offset(0, .12), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, .5, curve: Curves.easeOutCubic),
    ));

    _timer = Timer(const Duration(seconds: 3), _go);
  }

  void _go() {
    if (!mounted) return;
    // pushReplacement: Back from the studio must NOT return to the splash.
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 700),
      pageBuilder: (_, __, ___) => const WriteASongPage(),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intro.dispose();
    _spin.dispose();
    super.dispose();
  }

  String _status(double v) {
    if (v < .35) return 'BOOTING STUDIO';
    if (v < .7) return 'LOADING MODULES';
    if (v < .98) return 'TUNING INSTRUMENTS';
    return 'READY';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TechBackground(
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _spin,
                            builder: (_, __) => CustomPaint(
                              size: const Size(220, 220),
                              painter: _RingPainter(_spin.value),
                            ),
                          ),
                          Container(
                            width: 168,
                            height: 168,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Tech.surface.withValues(alpha: .8),
                              boxShadow: [
                                BoxShadow(
                                  color: Tech.cyan.withValues(alpha: .25),
                                  blurRadius: 40,
                                ),
                              ],
                            ),
                          ),
                          Image.asset(
                            'assets/icons/Luvedube.png',
                            height: 120,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.music_note_rounded,
                              size: 84,
                              color: Tech.cyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const GradientText(
                      'LuveDuve',
                      gradient: Tech.brand,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('WRITE  ·  ARRANGE  ·  LOCK  ·  EXPORT',
                        style: Tech.mono(size: 10.5, spacing: 2)),
                    const SizedBox(height: 36),
                    AnimatedBuilder(
                      animation: _intro,
                      builder: (_, __) => Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 220,
                              height: 4,
                              child: Stack(
                                children: [
                                  Container(
                                      color: Colors.white.withValues(alpha: .08)),
                                  FractionallySizedBox(
                                    widthFactor: _intro.value,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                          gradient: Tech.brand),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(_status(_intro.value),
                              style: Tech.mono(size: 10, color: Tech.cyan)),
                        ],
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

class _RingPainter extends CustomPainter {
  _RingPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: .06),
    );

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [
            Tech.cyan.withValues(alpha: 0),
            Tech.cyan,
            Tech.violet,
            Tech.magenta.withValues(alpha: 0),
          ],
          stops: const [0, .45, .75, 1],
          transform: GradientRotation(t * 2 * math.pi),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}