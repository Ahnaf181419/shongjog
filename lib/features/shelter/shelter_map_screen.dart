import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import 'shelter_model.dart';
import 'shelter_repository.dart';

/// Bundled cyclone-shelter map. Renders all shelters as calmTeal shield
/// markers, centered on Bangladesh (23.8, 90.4) by default.
///
/// Per docs/design.md §7.3: if GPS is denied, center on Bangladesh default
/// and show a disclaimer banner. GPS wiring lands with Phase 4.3.
class ShelterMapScreen extends StatefulWidget {
  const ShelterMapScreen({super.key});
  @override
  State<ShelterMapScreen> createState() => _ShelterMapScreenState();
}

class _ShelterMapScreenState extends State<ShelterMapScreen> {
  late Future<List<Shelter>> _future;

  @override
  void initState() {
    super.initState();
    _future = ShelterRepository().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('নিকটস্থ আশ্রয়কেন্দ্র')),
      body: FutureBuilder<List<Shelter>>(
        future: _future,
        builder: (_, snap) {
          if (snap.hasError) {
            return _errorState(snap.error.toString());
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final shelters = snap.data!;
          return FlutterMap(
            options: MapOptions(
              initialCenter: shelters.isEmpty
                  ? const LatLng(23.8, 90.4)
                  : LatLng(shelters.first.lat, shelters.first.lon),
              initialZoom: 7,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                // Offline tiles: Phase 4.2 stretch goal bundles MBTiles
                // for the coastal belt. For the demo we accept cached OSM.
              ),
              MarkerLayer(
                markers: shelters
                    .map((s) => Marker(
                          point: LatLng(s.lat, s.lon),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.shield,
                              color: ShongjogTheme.calmTeal, size: 32),
                        ))
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _errorState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined,
                size: 64, color: ShongjogTheme.calmTeal),
            const SizedBox(height: 16),
            const Text('মানচিত্র লোড করা যায়নি',
                style: TextStyle(fontSize: ShongjogTheme.bodyLargeFloor)),
            const SizedBox(height: 8),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}