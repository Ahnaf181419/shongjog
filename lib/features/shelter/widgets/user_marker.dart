import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';

/// Builds the user's GPS location marker — a 56×56 pulsing dot.
///
/// The outer ring breathes between 18% and 36% opacity driven by
/// [pulse] (1.4 s cycle, per design.md §7.3 — the only piece of
/// "liveliness" on an otherwise static map). The inner 18×18 dot
/// stays solid; the pulse only affects the outer ring.
///
/// Wrap in [ExcludeSemantics] so screen readers don't announce the
/// breathing animation each frame.
Marker buildUserMarker(LatLng position, Animation<double> pulse) {
  return Marker(
    point: position,
    width: 56,
    height: 56,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: ShongjogTheme.ocean
                      .withValues(alpha: 0.18 + 0.18 * pulse.value),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: ShongjogTheme.ocean,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
