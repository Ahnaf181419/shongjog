import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/main_shell.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

// ═══════════════════════════════════════════════════════════════════
//  Shongjog Splash — "the mark on the waterline"
//
//  Bangladesh is a delta. The S in the mark reads as a river channel,
//  and the disasters this app exists for arrive as water. So the
//  composition puts the mark ON a horizon: a hairline that draws
//  outward from the centre and fades to nothing where the mark sits,
//  so it passes BEHIND the monogram rather than striking through it.
//
//  That horizon is the one bold element. Everything else — the fade,
//  the 10px rise, the wordmark — is deliberately quiet. Premium here
//  is restraint, not ornament.
//
//  Colour comes entirely from existing tokens. The monogram is tinted
//  to `oceanBright` at paint time rather than shipping a second asset,
//  so it can never drift from the launcher icon: same file, same shape.
//  It previously drew the raw asset, whose S is navy #041128 — 1.29:1
//  on this ground, i.e. invisible.
//
//  design.md §5.5 (easeOutCubic only, never bounce), §7.8, §2 (Bangla
//  on the user surface).
// ═══════════════════════════════════════════════════════════════════

/// Animated splash — the app's first visual impression.
///
/// Calls [onComplete] at ~1.6 s so the parent can crossfade onward.
///
/// Honours [MediaQuery.disableAnimations]: with reduced motion the final
/// composition is shown at rest and the screen moves on quickly.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  /// Total time on screen before [onComplete] fires.
  ///
  /// This is an emergency app; the splash is a cost paid on every single
  /// launch, forever. 1.6 s is enough for the horizon to draw and settle
  /// and not a frame more.
  static const Duration duration = Duration(milliseconds: 1600);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// One controller drives the whole sequence; each element reads its own
  /// slice via [Interval]. Four controllers chained on `await Future.delayed`
  /// drift against each other and are harder to reason about than one
  /// timeline with named windows.
  late final AnimationController _ctrl;

  late final Animation<double> _markOpacity;
  late final Animation<double> _markRise;
  late final Animation<double> _horizonExtent;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<double> _wordmarkRise;
  late final Animation<double> _taglineOpacity;

  Timer? _navTimer;
  bool _started = false;

  static const _ease = Curves.easeOutCubic;

  Animation<double> _slice(
    double begin,
    double end, {
    double from = 0,
    double to = 1,
  }) {
    return Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(begin, end, curve: _ease),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: SplashScreen.duration);

    // Windows are fractions of the 1600 ms timeline.
    //   mark      0    – 500 ms
    //   horizon   340  – 900 ms
    //   wordmark  600  – 1150 ms
    //   tagline   860  – 1300 ms
    _markOpacity = _slice(0.00, 0.31);
    _markRise = _slice(0.00, 0.31, from: 12, to: 0);
    _horizonExtent = _slice(0.21, 0.56);
    _wordmarkOpacity = _slice(0.37, 0.72);
    _wordmarkRise = _slice(0.37, 0.72, from: 10, to: 0);
    _taglineOpacity = _slice(0.54, 0.81);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.of(context).disableAnimations) {
      _ctrl.value = 1.0;
      _navTimer = Timer(const Duration(milliseconds: 300), _done);
      return;
    }
    _ctrl.forward();
    _navTimer = Timer(SplashScreen.duration, _done);
  }

  void _done() {
    if (!mounted) return;
    try {
      widget.onComplete();
    } catch (e) {
      debugPrint('[SplashScreen] onComplete failed: $e');
      Navigator.of(context).pushReplacement(_fadeRoute(const MainShell()));
    }
  }

  /// Fade, never a hard swap.
  static PageRoute<T> _fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 400),
  );

  @override
  void dispose() {
    _navTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // Single-theme by design: the cold-boot window on Android is dark
      // regardless of system preference, so a light splash would flash.
      backgroundColor: ShongjogTheme.scaffoldDark,
      // SizedBox.expand, not a bare DecoratedBox: DecoratedBox sizes itself to
      // its child, so without this the whole composition shrink-wraps to the
      // width of the widest text and sits off-centre in the left of the screen.
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.15),
              radius: 0.95,
              colors: [
                ShongjogTheme.surfaceDimDark, // #172033 — a breath of lift
                ShongjogTheme.scaffoldDark, // #0F172A — settles to the base
              ],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => Column(
                children: [
                  // Optical centring: the mark sits slightly above true centre
                  // so the wordmark below balances it rather than hanging.
                  const Spacer(flex: 5),
                  _buildMarkOnHorizon(),
                  const SizedBox(height: 34),
                  _buildWordmark(l10n),
                  const SizedBox(height: 10),
                  _buildTagline(l10n),
                  const Spacer(flex: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The signature: the monogram straddling a horizon that fades out
  /// behind it.
  Widget _buildMarkOnHorizon() {
    return SizedBox(
      height: 132,
      // Full width: the horizon has to run past the mark to read as a
      // horizon at all. Constrained to the mark's own 132px it was just an
      // underline.
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The horizon draws outward from the centre. Its gradient is
          // transparent across the middle third, so the line never crosses the
          // monogram — it reads as receding behind it, not striking it out —
          // and fades to nothing at both screen edges rather than stopping.
          Positioned.fill(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: _horizonExtent.value,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ShongjogTheme.oceanBright.withValues(alpha: 0),
                        ShongjogTheme.oceanBright.withValues(alpha: 0.50),
                        ShongjogTheme.oceanBright.withValues(alpha: 0),
                        ShongjogTheme.oceanBright.withValues(alpha: 0),
                        ShongjogTheme.oceanBright.withValues(alpha: 0.50),
                        ShongjogTheme.oceanBright.withValues(alpha: 0),
                      ],
                      // The clear band (0.38–0.62) is sized to clear the
                      // 132px mark on a 360dp screen with margin either side.
                      stops: const [0.0, 0.22, 0.38, 0.62, 0.78, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: _markOpacity.value,
            child: Transform.translate(
              offset: Offset(0, _markRise.value),
              // srcIn keeps the asset's alpha and replaces its colour, so the
              // splash and the launcher icon are guaranteed to be the same
              // shape — one file, tinted per surface.
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  ShongjogTheme.oceanBright,
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/icon_foreground.png',
                  width: 132,
                  height: 132,
                  // The asset is a launcher foreground: the glyph occupies
                  // 78% of the canvas with transparent padding around it, so
                  // it is drawn slightly oversized to compensate.
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordmark(AppLocalizations l10n) {
    return Opacity(
      opacity: _wordmarkOpacity.value,
      child: Transform.translate(
        offset: Offset(0, _wordmarkRise.value),
        child: Text(
          l10n.splashTitle,
          style: const TextStyle(
            fontFamily: ShongjogTheme.fontFamily,
            fontFamilyFallback: ShongjogTheme.fontFallback,
            fontSize: 38,
            fontWeight: FontWeight.w600,
            height: 1.1,
            // Bangla conjuncts already carry a lot of horizontal detail;
            // extra tracking pulls the matras away from their base glyph.
            letterSpacing: 0,
            color: ShongjogTheme.inkDark,
          ),
        ),
      ),
    );
  }

  Widget _buildTagline(AppLocalizations l10n) {
    return Opacity(
      opacity: _taglineOpacity.value,
      child: Text(
        l10n.splashTagline2,
        style: const TextStyle(
          fontFamily: ShongjogTheme.fontFamily,
          fontFamilyFallback: ShongjogTheme.fontFallback,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.6,
          color: ShongjogTheme.inkSecondaryDark,
        ),
      ),
    );
  }
}
