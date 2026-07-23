import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import 'mesh_chat_screen.dart';
import 'mesh_models.dart';
import 'mesh_service.dart';
import 'mesh_voice_service.dart';

class MeshRadarScreen extends StatefulWidget {
  const MeshRadarScreen({super.key});

  @override
  State<MeshRadarScreen> createState() => _MeshRadarScreenState();
}

class _MeshRadarScreenState extends State<MeshRadarScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarAnim;
  final TextEditingController _msgCtrl = TextEditingController();
  StreamSubscription? _peerSub;
  List<MeshPeer> _peers = [];
  bool _started = false;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _radarAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _startMesh();
  }

  Future<void> _startMesh() async {
    if (!meshService.isRunning) {
      final result = await meshService.start();
      if (!mounted) return;
      if (!result.ok) {
        final msg = switch (result.reason) {
          'wifi_off' =>
            'Wi-Fi বন্ধ আছে — Wi-Fi চালু করে আবার চেষ্টা করুন',
          'permissions' =>
            'Wi-Fi ও অনুমতি প্রয়োজন — সেটিংসে অনুমতি দিন',
          _ => 'মেশ সংযোগ শুরু করা যায়নি — Wi-Fi চালু আছে কিনা দেখুন',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() => _started = true);

    _peerSub = meshService.peers.listen((peers) {
      if (mounted) setState(() => _peers = peers);
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _peerSub?.cancel();
    _radarAnim.dispose();
    // NOTE: Do NOT call meshService.stop() — it runs at app level.
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    HapticService.lightTap();
    if (_recording) {
      await meshVoiceService.stopRecordingAndSend();
      if (mounted) setState(() => _recording = false);
    } else {
      final ok = await meshVoiceService.startRecording(
        onAutoStop: () {
          if (mounted) setState(() => _recording = false);
        },
      );
      if (ok && mounted) {
        setState(() => _recording = true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('রেকর্ডিং শুরু করা যায়নি — মাইক্রোফোন অনুমতি দিন'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('অফলাইন যোগাযোগ'),
        actions: [
          if (_started)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_peers.length} ডিভাইস',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Radar animation strip
          Container(
            height: 120,
            color: cs.primary.withValues(alpha: 0.06),
            child: Center(
              child: AnimatedBuilder(
                animation: _radarAnim,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(100, 100),
                    painter: _RadarPainter(
                      progress: _radarAnim.value,
                      peerCount: _peers.length,
                      color: cs.primary,
                    ),
                  );
                },
              ),
            ),
          ),

          // Peer list
          if (!_started)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Wi-Fi সংযোগ চালু হচ্ছে...'),
                  ],
                ),
              ),
            ),

          if (_started && _peers.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bluetooth_searching_rounded,
                        size: 48, color: cs.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'কাছের ডিভাইস খোঁজা হচ্ছে...\n'
                      'Wi-Fi চালু রাখুন এবং Shongjog\n'
                      'ব্যবহারকারী কাছে থাকলে এখানে দেখা যাবে।',
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
            ),

          if (_started && _peers.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _peers.length,
                itemBuilder: (context, index) {
                  final peer = _peers[index];
                  return _PeerTile(
                    peer: peer,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MeshChatScreen(peer: peer),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

          // Bottom input bar
          if (_started)
            SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_peers.any((p) => p.status == PeerStatus.connected))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.broadcast_on_personal,
                              size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            'সবাইকে পাঠানো হবে',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        // Voice record button
                        IconButton.filled(
                          onPressed: _toggleRecording,
                          icon: Icon(
                            _recording ? Icons.stop : Icons.mic,
                            color: _recording ? Colors.white : cs.onPrimary,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                _recording ? Colors.red : cs.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quick text input
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            decoration: const InputDecoration(
                              hintText: 'মেসেজ লিখুন...',
                              border: OutlineInputBorder(),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onSubmitted: (text) {
                              final trimmed = text.trim();
                              if (trimmed.isNotEmpty) {
                                HapticService.lightTap();
                                final ok = meshService.sendMessage(trimmed);
                                _msgCtrl.clear();
                                if (!ok && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'কোনো ডিভাইস সংযুক্ত নেই — মেসেজ পাঠানো যায়নি'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () {
                            final text = _msgCtrl.text.trim();
                            if (text.isNotEmpty) {
                              HapticService.lightTap();
                              final ok = meshService.sendMessage(text);
                              _msgCtrl.clear();
                              if (!ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'কোনো ডিভাইস সংযুক্ত নেই — মেসেজ পাঠানো যায়নি'),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.send),
                          style: IconButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PeerTile extends StatelessWidget {
  final MeshPeer peer;
  final VoidCallback onTap;

  const _PeerTile({required this.peer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (peer.status) {
      PeerStatus.connected => Colors.green,
      PeerStatus.reconnecting => Colors.orange,
      PeerStatus.disconnected => Colors.red,
    };
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Icon(Icons.person, color: statusColor),
      ),
      title: Text(
        peer.displayName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        peer.status == PeerStatus.connected
            ? 'সংযুক্ত'
            : peer.status == PeerStatus.reconnecting
                ? 'পুনঃসংযোগ হচ্ছে...'
                : 'বিচ্ছিন্ন',
        style: TextStyle(color: statusColor, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final int peerCount;
  final Color color;

  _RadarPainter({
    required this.progress,
    required this.peerCount,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw concentric rings.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      ringPaint.color = color.withValues(alpha: 0.1 + (i * 0.05));
      canvas.drawCircle(center, maxRadius * i / 3, ringPaint);
    }

    // Draw sweep line.
    final sweepAngle = progress * 2 * pi;
    final sweepPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2;
    canvas.drawLine(
      center,
      Offset(
        center.dx + maxRadius * cos(sweepAngle),
        center.dy + maxRadius * sin(sweepAngle),
      ),
      sweepPaint,
    );

    // Draw peer dots.
    if (peerCount > 0) {
      final dotPaint = Paint()..color = color;
      for (int i = 0; i < peerCount && i < 8; i++) {
        final angle = (i / (peerCount < 1 ? 1 : peerCount)) * 2 * pi;
        final radius = maxRadius * 0.5 + (i % 3) * maxRadius * 0.15;
        canvas.drawCircle(
          Offset(
            center.dx + radius * cos(angle),
            center.dy + radius * sin(angle),
          ),
          4,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.progress != progress || old.peerCount != peerCount;
}
