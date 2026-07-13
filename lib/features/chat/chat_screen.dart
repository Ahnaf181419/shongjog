import 'package:flutter/material.dart';

/// Skeleton placeholder. Phase 3.4 (Ahnaf) replaces this with the real chat
/// screen — mic-first input, message bubbles, TTS read-aloud, model-ready
/// status row (design.md §7.1).
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('সংযোগ — জরুরি সহায়তা'),
      ),
      body: const Center(
        child: Text('চ্যাট — শীঘ্রই আসছে'),
      ),
    );
  }
}