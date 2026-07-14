import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import 'nearest_shelter.dart';
import 'shelter_model.dart';
import 'shelter_repository.dart';

/// Shelter map with GPS-based nearest ranking + bottom-sheet details.
class ShelterMapScreen extends StatefulWidget {
  const ShelterMapScreen({super.key});
  @override
  State<ShelterMapScreen> createState() => _ShelterMapScreenState();
}

class _ShelterMapScreenState extends State<ShelterMapScreen> {
  late Future<List<Shelter>> _sheltersFuture;
  Position? _userPosition;
  String? _gpsError;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _sheltersFuture = ShelterRepository().loadAll();
    _resolveGps();
  }

  Future<void> _resolveGps() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _gpsError = 'GPS অনুমতি নেই');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _gpsError = 'GPS অনুমতি চিরতরে নিষিদ্ধ');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10)),
      );
      if (mounted) setState(() => _userPosition = pos);
    } catch (e) {
      if (mounted) setState(() => _gpsError = 'GPS পাওয়া যায়নি');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('নিকটস্থ আশ্রয়কেন্দ্র')),
      body: FutureBuilder<List<Shelter>>(
        future: _sheltersFuture,
        builder: (_, snap) {
          if (snap.hasError) return _errorState();
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final shelters = snap.data!;
          final ranked = _userPosition != null
              ? nearestShelters(
                  lat: _userPosition!.latitude,
                  lon: _userPosition!.longitude,
                  all: shelters,
                  k: shelters.length,
                )
              : null;

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _userPosition != null
                      ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                      : const LatLng(23.8, 90.4),
                  initialZoom: 8,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_userPosition != null)
                        Marker(
                          point: LatLng(_userPosition!.latitude,
                              _userPosition!.longitude),
                          width: 20,
                          height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: ShongjogTheme.calmTeal,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ...shelters.map((s) => Marker(
                            point: LatLng(s.lat, s.lon),
                            width: 40,
                            height: 40,
                            child: IconButton(
                              icon: const Icon(Icons.shield_outlined,
                                  color: ShongjogTheme.calmTeal, size: 30),
                              onPressed: () => _showShelterSheet(s),
                            ),
                          )),
                    ],
                  ),
                ],
              ),
              if (ranked != null && ranked.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _nearestCard(ranked.take(3).toList()),
                )
              else
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _gpsBanner(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _nearestCard(List<RankedShelter> top3) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('নিকটতম ৩টি',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ShongjogTheme.inkSecondary)),
            const SizedBox(height: 4),
            ...top3.map((r) => _shelterRow(r.shelter, r.km)),
          ],
        ),
      ),
    );
  }

  Widget _shelterRow(Shelter s, double km) {
    return InkWell(
      onTap: () => _showShelterSheet(s),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined,
                color: ShongjogTheme.calmTeal, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.nameBn.isNotEmpty ? s.nameBn : s.name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '${km.toStringAsFixed(1)} কিমি',
              style: TextStyle(
                  fontSize: 13, color: ShongjogTheme.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showShelterSheet(Shelter s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final km = _userPosition == null
            ? null
            : haversineKm(_userPosition!.latitude, _userPosition!.longitude,
                s.lat, s.lon);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: ShongjogTheme.calmTeal, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.nameBn.isNotEmpty ? s.nameBn : s.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (s.nameBn.isNotEmpty && s.name.isNotEmpty)
                Text(s.name,
                    style: TextStyle(
                        fontSize: 14, color: ShongjogTheme.inkSecondary)),
              const SizedBox(height: 16),
              if (km != null) _row('দূরত্ব', '${km.toStringAsFixed(1)} কিমি'),
              if (s.capacity != null)
                _row('ধারণক্ষমতা', '${s.capacity} জন'),
              _row('উৎস', s.source),
              _row(
                  'GPS',
                  '${s.lat.toStringAsFixed(4)}, ${s.lon.toStringAsFixed(4)}'),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(k,
                  style: TextStyle(
                      fontSize: 13, color: ShongjogTheme.inkSecondary))),
          Expanded(
              child: Text(v, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  Widget _gpsBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_off,
            color: _gpsError != null
                ? ShongjogTheme.alertRed
                : ShongjogTheme.inkSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _gpsError ??
                  'সমগ্র বাংলাদেশ দেখানো হচ্ছে — GPS থেকে দূরত্ব নির্ণয় করা যাবে না',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 56, color: ShongjogTheme.inkMuted),
            const SizedBox(height: 16),
            const Text('মানচিত্র লোড করা যায়নি'),
          ],
        ),
      ),
    );
  }
}