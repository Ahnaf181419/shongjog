import 'dart:async';

import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/haptics.dart';
import 'mesh_service.dart';

class MeshRadarScreen extends StatefulWidget {
  const MeshRadarScreen({super.key});

  @override
  State<MeshRadarScreen> createState() => _MeshRadarScreenState();
}

class _MeshRadarScreenState extends State<MeshRadarScreen> {
  final List<MeshMessage> _messages = [];
  final _msgCtrl = TextEditingController();
  StreamSubscription? _msgSub;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _startMesh();
  }

  Future<void> _startMesh() async {
    final ok = await meshService.start();
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ব্লুটুথ অনুমতি প্রয়োজন — সেটিংসে অনুমতি দিন'),
        ),
      );
      return;
    }

    setState(() => _started = true);
    _msgSub = meshService.messages.listen((m) {
      if (mounted) {
        setState(() => _messages.add(m));
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    meshService.stop();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    HapticService.lightTap();
    meshService.sendMessage(text);
    setState(() {
      _messages.add(MeshMessage(senderId: 'Me', text: text));
    });
    _msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('অফলাইন যোগাযোগ'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: cs.primary.withValues(alpha: 0.10),
            child: Row(
              children: [
                Icon(Icons.radar, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: StreamBuilder<List<String>>(
                    stream: meshService.peers,
                    initialData: const [],
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Text(
                        'নিকটস্থ ডিভাইসের সংখ্যা: $count',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: ShongjogTheme.body(context),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (!_started)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ব্লুটুথ সংযোগ চালু হচ্ছে...',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          if (_started)
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bluetooth_searching_rounded,
                                size: 48,
                                color: cs.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text(
                              'কাছের ডিভাইস খোঁজা হচ্ছে...\nকেউ সংযুক্ত হলে এখানে দেখা যাবে।',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final m = _messages[index];
                        final isMe = m.senderId == 'Me';
                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? cs.primary
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              m.text,
                              style: TextStyle(
                                color:
                                    isMe ? cs.onPrimary : cs.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          if (_started)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        decoration: const InputDecoration(
                          hintText: 'মেসেজ লিখুন...',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
