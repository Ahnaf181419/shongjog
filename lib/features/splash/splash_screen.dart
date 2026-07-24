import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/main_shell.dart';

// ═══════════════════════════════════════════════════════════════════
//  Shongjog Splash Screen
//  Code-based animated splash — no external image assets.
//  Shield (protection) + Heart (hope) + Pulse (rapid response).
// ═══════════════════════════════════════════════════════════════════

/// Brand colors used across the splash and icon.
class SplashColors {
  SplashColors._();

  static const Color teal = Color(0xFF0D9488);
  static const Color deepBlue = Color(0xFF0C4A6E);
  static const Color amber = Color(0xFFF59E0B);
  static const Color white = Color(0xFFFFFFFF);
}

/// Animated splash screen — fully code-generated visuals.
///
/// Displays a shield-and-heart emblem with pulse rings, then an
/// animated tagline. After ~2.5 s calls [onComplete] so the parent
/// can navigate to the next screen.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────
  late final AnimationController _shieldCtrl;
  late final AnimationController _heartCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _textCtrl;

  // ── Animations ───────────────────────────────────────────
  late final Animation<double> _shieldScale;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;
  late final Animation<double> _pulseExpansion;
  late final Animation<double> _pulseOpacity;
  late final Animation<double> _textSlide;
  late final Animation<double> _textOpacity;

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // Shield: elastic scale-in over 600ms.
    _shieldCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shieldScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shieldCtrl, curve: Curves.elasticOut),
    );

    // Heart: scale + fade over 500ms, starts at 300ms.
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _heartScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOutBack),
    );
    _heartOpacity = CurvedAnimation(parent: _heartCtrl, curve: Curves.easeIn);

    // Pulse rings: expand + fade over 1200ms, starts at 600ms.
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseExpansion = Tween<double>(begin: 0.8, end: 2.5).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    // Text: slide-up + fade over 600ms, starts at 1000ms.
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic),
    );
    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn);

    _runSequence();
  }

  Future<void> _runSequence() async {
    // 0ms — shield appears
    _shieldCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _heartCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _pulseCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _textCtrl.forward();

    // Navigate after 2.5s total.
    _navTimer = Timer(const Duration(milliseconds: 1500), _done);
  }

  void _done() {
    if (!mounted) return;
    try {
      widget.onComplete();
    } catch (e) {
      debugPrint('[SplashScreen] onComplete failed: $e');
      // Fallback: navigate to MainShell using our own Navigator context.
      // This bypasses _StartupGate's onboarding check, but is better than
      // the app freezing on the splash screen permanently.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _shieldCtrl.dispose();
    _heartCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              SplashColors.teal,
              SplashColors.deepBlue,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // ── Shield + Heart emblem with pulse rings ──
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulse rings
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, _) => CustomPaint(
                        size: const Size(200, 200),
                        painter: _PulsePainter(
                          expansion: _pulseExpansion.value,
                          opacity: _pulseOpacity.value,
                        ),
                      ),
                    ),
                    // Shield
                    ScaleTransition(
                      scale: _shieldScale,
                      child: SizedBox(
                        width: 140,
                        height: 160,
                        child: CustomPaint(
                          painter: const _ShieldPainter(),
                        ),
                      ),
                    ),
                    // Heart
                    ScaleTransition(
                      scale: _heartScale,
                      child: FadeTransition(
                        opacity: _heartOpacity,
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 44,
                          color: SplashColors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── App name ──
              AnimatedBuilder(
                animation: _textCtrl,
                builder: (_, _) => Opacity(
                  opacity: _textOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _textSlide.value),
                    child: const Text(
                      'Shongjog',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: SplashColors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Tagline ──
              AnimatedBuilder(
                animation: _textCtrl,
                builder: (_, _) => Opacity(
                  opacity: _textOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _textSlide.value),
                    child: const Text(
                      'সঙ্গী — Food · Rescue · Community',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xCCFFFFFF),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // ── Bottom tagline ──
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (_, _) => Opacity(
                    opacity: _textOpacity.value * 0.5,
                    child: const Text(
                      'জরুরি সঙ্গী',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CustomPainter — Shield outline
// ═══════════════════════════════════════════════════════════════════

class _ShieldPainter extends CustomPainter {
  const _ShieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SplashColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Shield: rounded top, tapered bottom with point.
    path.moveTo(w * 0.5, h * 0.02);
    path.cubicTo(w * 0.85, h * 0.02, w * 0.98, h * 0.15, w * 0.98, h * 0.35);
    path.cubicTo(w * 0.98, h * 0.60, w * 0.75, h * 0.80, w * 0.5, h * 0.98);
    path.cubicTo(w * 0.25, h * 0.80, w * 0.02, h * 0.60, w * 0.02, h * 0.35);
    path.cubicTo(w * 0.02, h * 0.15, w * 0.15, h * 0.02, w * 0.5, h * 0.02);
    path.close();

    canvas.drawPath(path, paint);

    // Inner glow line (slightly smaller, semi-transparent).
    final glowPaint = Paint()
      ..color = SplashColors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final innerPath = Path();
    final s = 0.08; // inset fraction
    innerPath.moveTo(w * 0.5, h * (0.02 + s));
    innerPath.cubicTo(
      w * 0.85, h * (0.02 + s),
      w * 0.98, h * (0.15 + s),
      w * 0.98, h * (0.35 + s),
    );
    innerPath.cubicTo(
      w * 0.98, h * 0.60,
      w * 0.75, h * 0.80,
      w * 0.5, h * 0.98,
    );
    innerPath.cubicTo(
      w * 0.25, h * 0.80,
      w * 0.02, h * 0.60,
      w * 0.02, h * (0.35 + s),
    );
    innerPath.cubicTo(
      w * 0.02, h * (0.15 + s),
      w * (0.15 + s), h * (0.02 + s),
      w * 0.5, h * (0.02 + s),
    );
    innerPath.close();

    canvas.drawPath(innerPath, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════
//  CustomPainter — Pulse rings
// ═══════════════════════════════════════════════════════════════════

class _PulsePainter extends CustomPainter {
  final double expansion;
  final double opacity;

  const _PulsePainter({required this.expansion, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.22;

    for (int i = 0; i < 2; i++) {
      final delay = i * 0.15;
      final t = (expansion - 0.8).clamp(0.0, 1.7);
      final radius = baseRadius * (1.0 + t * (1.0 + delay));
      final alpha = (opacity * (1.0 - delay)).clamp(0.0, 1.0);

      if (alpha <= 0) continue;

      final paint = Paint()
        ..color = SplashColors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) =>
      old.expansion != expansion || old.opacity != opacity;
}


