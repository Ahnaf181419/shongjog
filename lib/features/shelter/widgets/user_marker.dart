import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../shelter_constants.dart';

/// Builds the user's GPS location marker — a 56×56 pulsing dot.
///
/// The outer ring breathes between [ShelterConstants.pulseMinAlpha]
/// and [ShelterConstants.pulseMaxAlpha] driven by [pulse]
/// (1.4 s cycle, per design.md §7.3 — the only piece of "liveliness"
/// on an otherwise static map). The inner dot stays solid; the pulse
/// only affects the outer ring.
///
/// Wrap in [ExcludeSemantics] so screen readers don't announce the
/// breathing animation each frame.
Marker buildUserMarker(LatLng position, Animation<double> pulse) {
  return Marker(
    point: position,
    width: ShelterConstants.userDotOuter,
    height: ShelterConstants.userDotOuter,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: ShelterConstants.userDotOuter,
                height: ShelterConstants.userDotOuter,
                decoration: BoxDecoration(
                  color: ShongjogTheme.ocean.withValues(
                    alpha: ShelterConstants.pulseMinAlpha +
                        (ShelterConstants.pulseMaxAlpha -
                                ShelterConstants.pulseMinAlpha) *
                            pulse.value,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: ShelterConstants.userDotInner,
                height: ShelterConstants.userDotInner,
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
