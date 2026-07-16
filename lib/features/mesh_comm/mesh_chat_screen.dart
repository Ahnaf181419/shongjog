import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import 'mesh_models.dart';
import 'mesh_service.dart';
import 'mesh_voice_service.dart';

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

  @override
  void initState() {
    super.initState();
    // 1-on-1 view: only this device's messages and this peer's. Without the
    // filter, every connected peer's traffic appears in every open chat.
    _msgSub = meshService.messages
        .where((m) => m.belongsToChatWith(widget.peer.endpointId))
        .listen((m) {
      if (mounted) {
        setState(() => _messages.add(m));
        _scrollToBottom();
      }
    });
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
    meshService.sendMessage(text);
    _msgCtrl.clear();
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
      if (ok && mounted) setState(() => _recording = true);
    }
  }

  Future<void> _playVoice(String? filePath) async {
    if (filePath == null) return;
    try {
      if (filePath.startsWith('content://') || filePath.startsWith('/')) {
        await _player.play(DeviceFileSource(filePath));
      }
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
            Text(widget.peer.name),
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
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'কোনো মেসেজ নেই\n"${widget.peer.name}" এর সাথে কথা বলুন',
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
            : Text(
                message.text,
                style: TextStyle(
                  color: isMe ? cs.onPrimary : cs.onSurface,
                ),
              ),
      ),
    );
  }
}
