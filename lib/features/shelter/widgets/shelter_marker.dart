import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../shelter_constants.dart';
import '../shelter_model.dart';

/// Builds a marker for a single shelter on the map. Renders a
/// [ShelterConstants.markerSmall]-sized teal-green shield by
/// default and a [ShelterConstants.markerLarge]-sized alert-red
/// shield when [isSelected] (matches the shelter the route is
/// currently drawn to).
///
/// [onTap] is invoked when the user taps the marker (the parent
/// uses this to start a route).
Marker buildShelterMarker(
  Shelter shelter,
  bool isSelected,
  VoidCallback onTap,
) {
  final size =
      isSelected ? ShelterConstants.markerLarge : ShelterConstants.markerSmall;
  final iconSize = isSelected
      ? ShelterConstants.shelterIconLarge
      : ShelterConstants.shelterIconSmall;
  return Marker(
    point: LatLng(shelter.lat, shelter.lon),
    width: size,
    height: size,
    child: Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isSelected
                ? ShongjogTheme.alert
                : ShongjogTheme.success.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.3 : 0.2),
                blurRadius: isSelected ? 8 : 3,
              ),
            ],
          ),
          child: Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    ),
  );
}
