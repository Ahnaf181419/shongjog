import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import 'mesh_call_screen.dart';
import 'mesh_call_service.dart';
import 'mesh_chat_store.dart';
import 'mesh_models.dart';
import 'mesh_service.dart';
import 'mesh_voice_service.dart';

/// A voice file path is "playable" only if it points at real on-device
/// storage. `content://` URIs from `nearby_connections` cannot be passed to
/// `audioplayers`; `MeshService._materializeVoiceFile` is the one legal
/// source of these paths. Anything else is a stale UI bubble from before
/// the receive-path fix and must be ignored so the user sees a no-op tap,
/// not a hang or crash.
bool isPlayableVoicePath(String? filePath) =>
    filePath != null && filePath.startsWith('/');

/// Per-peer chat screen. Shows text + voice messages exchanged with nearby
/// peers via mesh.
class MeshChatScreen extends StatefulWidget {
  final MeshPeer peer;

  const MeshChatScreen({super.key, required this.peer});

  @override
  State<MeshChatScreen> createState() => _MeshChatScreenState();
}

class _MeshChatScreenState extends State<MeshChatScreen> {
  final List<MeshMessage> _messages = [];
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  StreamSubscription? _msgSub;
  bool _recording = false;
  final AudioPlayer _player = AudioPlayer();
  final MeshChatStore _store = MeshChatStore();

  @override
  void initState() {
    super.initState();
    _loadPersistedMessages();
    // 1-on-1 view: only this device's messages and this peer's. Without the
    // filter, every connected peer's traffic appears in every open chat.
    _msgSub = meshService.messages
        .where((m) => m.belongsToChatWith(widget.peer.endpointId))
        .listen((m) {
      if (mounted) {
        setState(() => _messages.add(m));
        _scrollToBottom();
        _persistMessages();
      }
    });
  }

  Future<void> _loadPersistedMessages() async {
    final stored = await _store.load(widget.peer.endpointId);
    if (mounted && stored.isNotEmpty) {
      setState(() {
        _messages.addAll(stored.map((m) => m.toMeshMessage()));
      });
      _scrollToBottom();
    }
  }

  void _persistMessages() {
    final stored = _messages
        .map((m) => MeshChatMessage(
              senderId: m.senderId,
              senderName: m.senderName,
              text: m.text,
              type: m.type,
              filePath: m.filePath,
              hopCount: m.hopCount,
              timestamp: m.timestamp,
            ))
        .toList();
    _store.save(widget.peer.endpointId, stored);
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendText() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    HapticService.lightTap();
    final ok = meshService.sendMessage(text, targetEndpointId: widget.peer.endpointId);
    _msgCtrl.clear();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('মেসেজ পাঠানো যায়নি — পিয়ার সংযুক্ত আছে কিনা দেখুন'),
        ),
      );
    }
  }

  Future<void> _toggleRecording() async {
    HapticService.lightTap();
    if (_recording) {
      await meshVoiceService.stopRecordingAndSend(
        targetEndpointId: widget.peer.endpointId,
      );
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

  Future<void> _playVoice(String? filePath) async {
    if (!isPlayableVoicePath(filePath)) {
      // content:// URIs and missing paths cannot be played by audioplayers —
      // MeshService.materializeVoiceFile is the only legal source of these
      // paths. Anything else is a stale UI from before the fix.
      debugPrint('MeshChatScreen: ignoring unplayable voice path: $filePath');
      return;
    }
    try {
      await _player.play(DeviceFileSource(filePath!));
    } catch (e) {
      debugPrint('MeshChatScreen: failed to play voice: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peer.displayName),
            Text(
              widget.peer.status == PeerStatus.connected
                  ? 'সংযুক্ত'
                  : 'পুনঃসংযোগ হচ্ছে...',
              style: TextStyle(
                fontSize: 12,
                color: widget.peer.status == PeerStatus.connected
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.peer.status == PeerStatus.connected)
            IconButton(
              icon: const Icon(Icons.call_rounded),
              tooltip: 'ভয়েস কল',
              onPressed: () async {
                HapticService.lightTap();
                await meshCallService.call(widget.peer);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeshCallScreen(
                      peer: widget.peer,
                      isIncoming: false,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'কোনো মেসেজ নেই\n"${widget.peer.displayName}" এর সাথে কথা বলুন',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      return _MessageBubble(
                        message: m,
                        onPlayVoice: _playVoice,
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
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
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        hintText: 'মেসেজ লিখুন...',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendText,
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

class _MessageBubble extends StatelessWidget {
  final MeshMessage message;
  final Future<void> Function(String?) onPlayVoice;

  const _MessageBubble({
    required this.message,
    required this.onPlayVoice,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMe = message.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: message.type == MessageType.voice
            ? GestureDetector(
                onTap: () => onPlayVoice(message.filePath),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow,
                      color: isMe ? cs.onPrimary : cs.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ভয়েস মেসেজ',
                      style: TextStyle(
                        color: isMe ? cs.onPrimary : cs.onSurface,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                  if (message.hopCount != null && message.hopCount! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.errorContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '↻ ${message.hopCount} হপ',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
