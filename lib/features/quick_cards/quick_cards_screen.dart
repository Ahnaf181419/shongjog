import 'package:flutter/material.dart';

/// Skeleton placeholder. Phase 1.3 (Maruf) replaces this with the 6-card
/// static safety net — ORS / water / snakebite / severe diarrhea / shelter /
/// bleeding control (design.md §7.2). No model dependency.
class QuickCardsScreen extends StatelessWidget {
  const QuickCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('জরুরি সহায়তা কার্ড'),
      ),
      body: const Center(
        child: Text('কার্ডসমূহ — শীঘ্রই আসছে'),
      ),
    );
  }
}