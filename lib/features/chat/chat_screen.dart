import 'package:flutter/material.dart';

import '../../core/model_manager.dart';

/// Skeleton chat screen with model-manager wiring. The full chat UI
/// (message bubbles, input, TTS) lands in Phase 3.4; this surface lets
/// the Phase 0 spike exercise download + init on a real device.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _model = ModelManager();
  String _statusText = 'AI প্রস্তুত হচ্ছে...';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('সংযোগ — জরুরি সহায়তা'),
        actions: [
          IconButton(
            tooltip: 'জরুরি কার্ড',
            icon: const Icon(Icons.style),
            onPressed: () => Navigator.pushNamed(context, '/cards'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'চ্যাট UI শীঘ্রই আসছে',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _ensureModel,
        icon: const Icon(Icons.download),
        label: const Text('AI প্রস্তুত করুন'),
      ),
    );
  }

  Future<void> _ensureModel() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _statusText = 'মডেল ডাউনলোড হচ্ছে...';
    });
    try {
      await _model.ensureModel(onProgress: (p) {
        if (!mounted) return;
        setState(() =>
            _statusText = 'মডেল ডাউনলোড: ${(p * 100).toStringAsFixed(0)}%');
      });
      if (!mounted) return;
      setState(() => _statusText = 'AI চালু হচ্ছে...');
      await _model.initialize();
      if (!mounted) return;
      setState(() => _statusText = 'AI প্রস্তুত');
      messenger.showSnackBar(const SnackBar(content: Text('AI প্রস্তুত')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusText = 'ত্রুটি: $e');
      messenger.showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}