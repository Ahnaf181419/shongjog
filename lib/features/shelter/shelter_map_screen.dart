import 'package:flutter/material.dart';

/// Skeleton placeholder. Phase 4.2 (Ahnaf) replaces this with the bundled
/// GeoJSON map + GPS-centered nearest-shelter flow (design.md §7.3).
class ShelterMapScreen extends StatelessWidget {
  const ShelterMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('নিকটস্থ আশ্রয়কেন্দ্র'),
      ),
      body: const Center(
        child: Text('মানচিত্র — শীঘ্রই আসছে'),
      ),
    );
  }
}