import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/haptics.dart';
import '../../l10n/app_localizations.dart';
import 'mesh_chat_screen.dart';
import 'mesh_models.dart';
import 'mesh_service.dart';
import 'mesh_transport.dart';
import 'mesh_voice_service.dart';
import '../../app/theme.dart';

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
  List<String> _savedContacts = [];

  @override
  void initState() {
    _loadSavedContacts();
    super.initState();
    _radarAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _startMesh();
  }

  Future<void> _loadSavedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _savedContacts = prefs.getStringList('pref_saved_contacts') ?? [];
    });
  }

  Future<void> _toggleSavedContact(String name) async {
    HapticService.lightTap();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_savedContacts.contains(name)) {
        _savedContacts.remove(name);
      } else {
        _savedContacts.add(name);
      }
    });
    await prefs.setStringList('pref_saved_contacts', _savedContacts);
  }

  List<MeshPeer> _getCombinedPeers() {
    final combined = <MeshPeer>[];
    final activeNames = <String>{};

    for (final p in _peers) {
      combined.add(p);
      activeNames.add(p.displayName);
    }

    for (final name in _savedContacts) {
      if (!activeNames.contains(name)) {
        combined.add(MeshPeer(
          endpointId: 'saved_$name',
          name: name,
          status: PeerStatus.disconnected,
        ));
      }
    }
    
    // Put connected/active peers at the top
    combined.sort((a, b) {
      final aActive = a.status == PeerStatus.connected || a.status == PeerStatus.reconnecting;
      final bActive = b.status == PeerStatus.connected || b.status == PeerStatus.reconnecting;
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      return 0;
    });

    return combined;
  }

  Future<void> _startMesh() async {
    if (!meshService.isRunning) {
      final result = await meshService.start();
      if (!mounted) return;
      if (!result.ok) {
        final msg = switch (result.reason) {
          'wifi_off' =>
            AppLocalizations.of(context).meshWifiOff,
          'permissions' =>
            AppLocalizations.of(context).meshPermissions,
          _ => AppLocalizations.of(context).meshStartFailed,
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

    // Kick off a fresh scan immediately on (re-)entry so the peer list
    // populates without waiting for the first periodic tick.
    // The app-wide discovery timer in MeshService handles ongoing scans.
    //
    // Skipped while a link is live: re-entering this screen mid-conversation
    // would otherwise bounce the radio the connection is riding on, and the
    // peer you are already talking to is by definition already found. The
    // refresh button in the app bar remains for an explicit rescan.
    if (!meshService.hasLiveLink) {
      meshService.restartDiscovery();
    }
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
          SnackBar(
            content: Text(AppLocalizations.of(context).meshRecordingFailed),
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                AppLocalizations.of(context).meshTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (_started)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: ShongjogTheme.toneChip(
                    context,
                    meshService.activeTransport == MeshTransportType.wifiDirect
                        ? SemanticTone.warning
                        : SemanticTone.success),
                child: Text(
                  meshService.activeTransport == MeshTransportType.wifiDirect
                      ? 'Wi-Fi Direct'
                      : 'Nearby',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ShongjogTheme.toneInk(
                        context,
                        meshService.activeTransport ==
                                MeshTransportType.wifiDirect
                            ? SemanticTone.warning
                            : SemanticTone.success),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          if (_started)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: AppLocalizations.of(context).meshRescanTooltip,
              onPressed: () {
                HapticService.lightTap();
                meshService.restartDiscovery();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).meshRescanning),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          if (_started)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  AppLocalizations.of(context).meshDeviceCount(_peers.length),
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
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 12),
                    Text(AppLocalizations.of(context).meshConnecting),
                  ],
                ),
              ),
            ),

          if (_started && _getCombinedPeers().isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bluetooth_searching_rounded,
                        size: 48, color: cs.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).meshSearching,
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

          if (_started && _getCombinedPeers().isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _getCombinedPeers().length,
                itemBuilder: (context, index) {
                  final peer = _getCombinedPeers()[index];
                  return _PeerTile(
                    peer: peer,
                    isSaved: _savedContacts.contains(peer.displayName),
                    onToggleSave: () => _toggleSavedContact(peer.displayName),
                    onTap: () async {
                      if (peer.status != PeerStatus.connected) {
                        HapticService.lightTap();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context).meshConnectingStatus),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        final ok = await meshService.connectToEndpoint(peer.endpointId);
                        if (!ok) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context).meshConnectFailed),
                            ),
                          );
                          return;
                        }
                      }
                      if (!context.mounted) return;
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
                          Icon(Icons.broadcast_on_personal_rounded,
                              size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context).meshBroadcastAll,
                            style: TextStyle(
                              fontSize: 14,
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
                            _recording ? Icons.stop_rounded : Icons.mic_rounded,
                            // Foreground follows the active fill so the icon
                            // stays legible in both themes.
                            color: _recording ? cs.onError : cs.onPrimary,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: _recording ? cs.error : cs.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quick text input
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).meshHint,
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
                                    SnackBar(
                                      content: Text(
                                          AppLocalizations.of(context).meshNoDevice),
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
                                  SnackBar(
                                    content: Text(
                                        AppLocalizations.of(context).meshNoDevice),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.send_rounded),
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
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  const _PeerTile({
    required this.peer, 
    required this.isSaved, 
    required this.onTap, 
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOfflineSaved = peer.endpointId.startsWith('saved_');
    final tone = switch (peer.status) {
      PeerStatus.connected => SemanticTone.success,
      PeerStatus.reconnecting => SemanticTone.warning,
      PeerStatus.disconnected => SemanticTone.danger,
    };
    // A saved-but-absent contact has no status to report, so it stays neutral
    // rather than borrowing a semantic colour it hasn't earned.
    final avatarFill = isOfflineSaved
        ? cs.onSurfaceVariant
        : ShongjogTheme.toneFill(context, tone);
    // The subtitle is TEXT, so it takes the ink step — the fill above is two
    // steps too light to read at this size.
    final statusInk = isOfflineSaved
        ? cs.onSurfaceVariant
        : ShongjogTheme.toneInk(context, tone);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: avatarFill.withValues(alpha: 0.15),
        child: Icon(Icons.person_rounded, color: avatarFill),
      ),
      title: Text(
        peer.displayName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        isOfflineSaved ? AppLocalizations.of(context).meshOfflineContact :
        peer.status == PeerStatus.connected
            ? AppLocalizations.of(context).meshConnected
            : peer.status == PeerStatus.reconnecting
                ? AppLocalizations.of(context).meshReconnecting
                : AppLocalizations.of(context).meshDisconnected,
        style: TextStyle(color: statusInk, fontSize: 14),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isSaved ? Icons.star_rounded : Icons.star_border_rounded,
              color: isSaved
                  ? ShongjogTheme.toneFill(context, SemanticTone.warning)
                  : cs.onSurfaceVariant,
            ),
            onPressed: onToggleSave,
          ),
          if (!isOfflineSaved) const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: isOfflineSaved ? null : onTap,
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
