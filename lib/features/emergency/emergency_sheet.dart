import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import 'emergency_actions.dart';
import 'sos_sms_template.dart';

/// Full-screen emergency action sheet with slide-to-confirm dial.
///
/// Per design.md §7.5:
/// - Always darkBody background (emergency context demands focus)
/// - Large ৯৯৯ in alertRed, 96sp
/// - Slide-to-confirm knob (≥90% track width triggers dial)
/// - SOS SMS secondary link
/// - Accessibility fallback: collapses to large button for reduced motion
class EmergencySheet extends StatefulWidget {
  const EmergencySheet({super.key});

  /// Show the sheet as a full-screen modal route.
  static Future<void> show(BuildContext context) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => const EmergencySheet(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends State<EmergencySheet> {
  double _dragProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: ShongjogTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: ShongjogTheme.darkInk,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'বাতিল',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('জরুরি কল'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.phone_in_talk,
                  size: 56, color: ShongjogTheme.alertRedDark),
              const SizedBox(height: 16),
              const Text(
                '৯৯৯',
                style: TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.w600,
                  color: ShongjogTheme.alertRedDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'জরুরি সেবায় কল করতে ডানে স্লাইড করুন',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (reduceMotion)
                _reducedMotionButton()
              else
                _slideToConfirm(),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _sendSos,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.message_outlined,
                        color: ShongjogTheme.calmTealPlus),
                    SizedBox(width: 8),
                    Text('পরিবর্তে SOS পাঠান',
                        style: TextStyle(color: ShongjogTheme.calmTealPlus)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slideToConfirm() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final knobSize = 56.0;
        final maxDrag = trackWidth - knobSize - 8;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Container(
              height: knobSize + 8,
              decoration: BoxDecoration(
                color: ShongjogTheme.darkSurface,
                borderRadius: BorderRadius.circular(knobSize),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      _dragProgress >= 0.9
                          ? 'ছেড়ে দিন'
                          : 'ডানে স্লাইড করুন',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: _dragProgress == 0 || _dragProgress >= 0.9
                        ? const Duration(milliseconds: 200)
                        : Duration.zero,
                    curve: Curves.easeOut,
                    left: 4 + (_dragProgress * maxDrag),
                    top: 4,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (d) {
                        setLocalState(() {
                          _dragProgress =
                              (_dragProgress + d.delta.dx / maxDrag)
                                  .clamp(0.0, 1.0);
                        });
                      },
                      onHorizontalDragEnd: (_) {
                        if (_dragProgress >= 0.9) {
                          _confirmDial();
                        } else {
                          setLocalState(() => _dragProgress = 0);
                        }
                      },
                      child: Container(
                        width: knobSize,
                        height: knobSize,
                        decoration: const BoxDecoration(
                          color: ShongjogTheme.alertRedDark,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _dragProgress >= 0.9
                              ? Icons.phone
                              : Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _reducedMotionButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _confirmDial,
        icon: const Icon(Icons.phone),
        label: const Text('কল করুন'),
      ),
    );
  }

  void _confirmDial() async {
    HapticFeedback.heavyImpact();
    await EmergencyActions.dial(EmergencyActions.police);
    if (mounted) Navigator.pop(context);
  }

  void _sendSos() async {
    double lat = 0.0;
    double lon = 0.0;
    String name = 'ব্যবহারকারী';
    String phone = 'অজানা';

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        lat = pos.latitude;
        lon = pos.longitude;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      name = prefs.getString('user_name') ?? name;
      phone = prefs.getString('user_phone') ?? phone;
    } catch (_) {}

    final body = sosSmsBody(name: name, phone: phone, lat: lat, lon: lon);
    await EmergencyActions.sendSos(body);
    if (mounted) Navigator.pop(context);
  }
}