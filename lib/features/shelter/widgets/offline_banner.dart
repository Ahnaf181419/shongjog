import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Top-positioned banner surfacing the offline state inside the
/// map view (visible only when _isOnline is false). Differs from
/// the AppBar.bottom pill: this banner overlays the map itself.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ShongjogTheme.surfaceDark,
          borderRadius: BorderRadius.circular(ShongjogTheme.radius),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded,
                color: ShongjogTheme.oceanBright, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'অফলাইন — মানচিত্রের টাইলস লোড হবে না, তবে আশ্রয়কেন্দ্রের অবস্থান দেখা যাচ্ছে',
                style: TextStyle(
                  fontSize: 14,
                  color: ShongjogTheme.inkDark.withValues(alpha: 0.85),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
