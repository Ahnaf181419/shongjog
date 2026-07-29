import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/haptics.dart';
import '../../l10n/app_localizations.dart';
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
  StreamSubscription<List<MeshPeer>>? _peerSub;
  late MeshPeer _currentPeer;
  bool _recording = false;
  bool _sendingMedia = false;
  final AudioPlayer _player = AudioPlayer();
  final MeshChatStore _store = MeshChatStore();
  final _imagePicker = ImagePicker();
  Future<void>? _lastPersist;

  @override
  void initState() {
    super.initState();
    _currentPeer = widget.peer;
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
    // Track live peer status so AppBar updates without needing to pop/re-enter.
    _peerSub = meshService.peers.listen((peers) {
      if (!mounted) return;
      final match = peers.where((p) => p.endpointId == widget.peer.endpointId);
      if (match.isNotEmpty && match.first != _currentPeer) {
        setState(() => _currentPeer = match.first);
      }
    });
  }

  Future<void> _loadPersistedMessages() async {
    final stored = await _store.load(
      widget.peer.displayName,
      oldEndpointId: widget.peer.endpointId,
    );
    if (mounted && stored.isNotEmpty) {
      setState(() {
        _messages.addAll(stored.map((m) => m.toMeshMessage()));
      });
      _scrollToBottom();
    }
  }

  Future<void> _persistMessages() async {
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
    _lastPersist = _store.save(_currentPeer.displayName, stored);
    await _lastPersist;
  }

  @override
  void dispose() {
    _peerSub?.cancel();
    _msgSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  void _confirmDeleteHistory() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.meshDeleteChatHistory),
        content: Text(l10n.meshDeleteChatBody(_currentPeer.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _store.clearPeer(_currentPeer.displayName);
              if (mounted) {
                setState(() => _messages.clear());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.meshDeleteChatDone),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.meshDeleteChatButton),
          ),
        ],
      ),
    );
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
        SnackBar(
          content: Text(AppLocalizations.of(context).meshSendMessageFailed),
        ),
      );
    }
  }

  Future<void> _pickAndSendMedia({required bool isVideo}) async {
    if (_sendingMedia) return;
    try {
      XFile? file;
      if (isVideo) {
        file = await _imagePicker.pickVideo(source: ImageSource.gallery);
      } else {
        file = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
      }
      if (file == null) return;
      if (!mounted) return;
      setState(() => _sendingMedia = true);
      final type = isVideo ? MessageType.video : MessageType.image;
      final result = await meshService.sendMediaMessage(
        file.path,
        type: type,
        targetEndpointId: widget.peer.endpointId,
      );
      if (mounted && result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).meshSendMediaFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingMedia = false);
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
          SnackBar(
            content: Text(AppLocalizations.of(context).meshRecordingFailed),
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentPeer.displayName),
            Text(
              _currentPeer.status == PeerStatus.connected
                  ? l10n.meshConnected
                  : _currentPeer.status == PeerStatus.reconnecting
                      ? l10n.meshReconnecting
                      : l10n.meshDisconnected,
              style: TextStyle(
                fontSize: 12,
                color: _currentPeer.status == PeerStatus.connected
                    ? Colors.green
                    : _currentPeer.status == PeerStatus.reconnecting
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          if (_currentPeer.status == PeerStatus.connected)
            IconButton(
              icon: const Icon(Icons.call_rounded),
              tooltip: l10n.meshCallTooltip,
              onPressed: () async {
                HapticService.lightTap();
                await meshCallService.call(_currentPeer);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeshCallScreen(
                      peer: _currentPeer,
                      isIncoming: false,
                    ),
                  ),
                );
              },
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _confirmDeleteHistory();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(l10n.meshDeleteChatMenu),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      l10n.meshEmptyChat(_currentPeer.displayName),
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
                  // ── Attachment picker
                  _AttachmentButton(
                    onPickImage: () => _pickAndSendMedia(isVideo: false),
                    onPickVideo: () => _pickAndSendMedia(isVideo: true),
                    sending: _sendingMedia,
                  ),
                  const SizedBox(width: 4),
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
                      decoration: InputDecoration(
                        hintText: l10n.meshInputHint,
                        border: const OutlineInputBorder(),
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
  // kept for API compatibility — voice bubbles now own their own player
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMe ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: message.type == MessageType.voice
            ? _VoicePlayerBubble(
                filePath: message.filePath,
                isMe: isMe,
              )
            : message.type == MessageType.image
                ? _ImageBubble(filePath: message.filePath, isMe: isMe)
                : message.type == MessageType.video
                    ? _VideoBubble(filePath: message.filePath, isMe: isMe)
                    : _TextBubbleContent(message: message, isMe: isMe),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Text bubble content (unchanged layout, extracted for clarity)
// ─────────────────────────────────────────────────────────────────────────────
class _TextBubbleContent extends StatelessWidget {
  final MeshMessage message;
  final bool isMe;
  const _TextBubbleContent({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.text,
            style: TextStyle(color: isMe ? cs.onPrimary : cs.onSurface),
          ),
          if (message.hopCount != null && message.hopCount! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  l10n.meshHopCount('${message.hopCount}'),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Animated voice player bubble
//  Each bubble owns its own AudioPlayer so multiple can exist simultaneously
//  without fighting over a single shared instance.
// ─────────────────────────────────────────────────────────────────────────────
class _VoicePlayerBubble extends StatefulWidget {
  final String? filePath;
  final bool isMe;

  const _VoicePlayerBubble({required this.filePath, required this.isMe});

  @override
  State<_VoicePlayerBubble> createState() => _VoicePlayerBubbleState();
}

class _VoicePlayerBubbleState extends State<_VoicePlayerBubble>
    with TickerProviderStateMixin {
  late final AudioPlayer _player;
  late final AnimationController _waveAnim;

  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Subscriptions
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  // Bangla digit map
  static const _bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    // Waveform animation — runs only while playing
    _waveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playerState = s);
      if (s == PlayerState.playing) {
        _waveAnim.repeat(reverse: true);
      } else {
        _waveAnim.stop();
      }
      // Auto-reset position label when clip finishes
      if (s == PlayerState.completed) {
        setState(() => _position = Duration.zero);
      }
    });

    _posSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _waveAnim.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (!isPlayableVoicePath(widget.filePath)) return;

    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else if (_playerState == PlayerState.paused) {
      await _player.resume();
    } else {
      try {
        await _player.play(DeviceFileSource(widget.filePath!));
      } catch (e) {
        debugPrint('_VoicePlayerBubble: play error: $e');
      }
    }
  }

  Future<void> _seekTo(double ratio) async {
    if (_duration == Duration.zero) return;
    final target = Duration(
      milliseconds: (ratio * _duration.inMilliseconds).round(),
    );
    await _player.seek(target);
  }

  // Converts a Duration to Bangla ০:০০ format
  String _bnTime(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String toStr(int n) =>
        n.toString().split('').map((c) => _bn[int.parse(c)]).join();
    final mm = toStr(m);
    final ss = s < 10 ? '${_bn[0]}${toStr(s)}' : toStr(s);
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMe = widget.isMe;
    final onColor = isMe ? cs.onPrimary : cs.onSurface;
    final onColorDim = onColor.withValues(alpha: 0.65);
    final playable = isPlayableVoicePath(widget.filePath);
    final isPlaying = _playerState == PlayerState.playing;

    final progress = (_duration.inMilliseconds > 0)
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Play / Pause button ───────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: GestureDetector(
              key: ValueKey(isPlaying),
              onTap: playable ? _togglePlayback : null,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: onColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: onColor,
                  size: 24,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ── Waveform + progress + time ────────────────────────
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform bars
                _WaveformBars(
                  animation: _waveAnim,
                  isPlaying: isPlaying,
                  color: onColor,
                  dimColor: onColorDim,
                  progress: progress,
                ),
                const SizedBox(height: 4),
                // Scrubable progress slider
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2.5,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: onColor,
                    inactiveTrackColor: onColor.withValues(alpha: 0.25),
                    thumbColor: onColor,
                    overlayColor: onColor.withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: playable ? _seekTo : null,
                  ),
                ),
                // Time label — position / duration
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _bnTime(_position),
                        style: TextStyle(
                          fontSize: 11,
                          color: onColorDim,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _bnTime(_duration),
                        style: TextStyle(
                          fontSize: 11,
                          color: onColorDim,
                          fontWeight: FontWeight.w500,
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

// ─────────────────────────────────────────────────────────────────────────────
//  5-bar animated waveform
//  Bars that haven't been heard yet are dimmed; heard bars are full-opacity.
//  While playing, each bar oscillates at a staggered phase via the shared
//  AnimationController.
// ─────────────────────────────────────────────────────────────────────────────
class _WaveformBars extends StatelessWidget {
  final Animation<double> animation;
  final bool isPlaying;
  final Color color;
  final Color dimColor;
  final double progress; // 0.0–1.0

  static const _barCount = 20;
  // Heights define a "voice waveform" envelope shape
  static const _heights = <double>[
    3, 5, 8, 12, 9, 14, 10, 7, 13, 11,
    14, 9, 12, 8, 11, 7, 9, 5, 8, 3,
  ];

  const _WaveformBars({
    required this.animation,
    required this.isPlaying,
    required this.color,
    required this.dimColor,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: List.generate(_barCount, (i) {
            final heard = (i / _barCount) < progress;
            final barColor = heard ? color : dimColor;

            // Staggered oscillation: each bar gets a different phase
            double height = _heights[i];
            if (isPlaying) {
              final phase = (animation.value + i / _barCount) % 1.0;
              final factor = 0.5 + 0.5 * (phase * 2 * 3.14159).abs().clamp(0.0, 1.0);
              height = height * factor + 2;
            }

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  height: height,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Attachment picker button — popup menu for image / video
// ─────────────────────────────────────────────────────────────────────────────
class _AttachmentButton extends StatelessWidget {
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final bool sending;

  const _AttachmentButton({
    required this.onPickImage,
    required this.onPickVideo,
    required this.sending,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      enabled: !sending,
      onSelected: (value) {
        if (value == 'image') onPickImage();
        if (value == 'video') onPickVideo();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'image',
          child: ListTile(
            leading: const Icon(Icons.photo_rounded),
            title: Text(l10n.meshSendImage),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'video',
          child: ListTile(
            leading: const Icon(Icons.videocam_rounded),
            title: Text(l10n.meshSendVideo),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: sending
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : Icon(Icons.add_circle_outline, color: cs.onSurfaceVariant),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Image bubble — displays a local image file with tap-to-fullscreen zoom
// ─────────────────────────────────────────────────────────────────────────────
class _ImageBubble extends StatelessWidget {
  final String? filePath;
  final bool isMe;

  const _ImageBubble({required this.filePath, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (filePath == null || !File(filePath!).existsSync()) {
      return _MissingMediaBubble(label: l10n.meshImageMissing);
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _FullImageScreen(path: filePath!),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220, maxHeight: 260),
          child: Image.file(
            File(filePath!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _MissingMediaBubble(
              label: l10n.meshImageLoadError,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen image viewer with pinch-to-zoom.
class _FullImageScreen extends StatelessWidget {
  final String path;
  const _FullImageScreen({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.file(File(path), fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Video bubble — thumbnail with play icon, tap for full-screen playback
// ─────────────────────────────────────────────────────────────────────────────
class _VideoBubble extends StatefulWidget {
  final String? filePath;
  final bool isMe;

  const _VideoBubble({required this.filePath, required this.isMe});

  @override
  State<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<_VideoBubble> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    if (widget.filePath == null || !File(widget.filePath!).existsSync()) {
      return _MissingMediaBubble(label: l10n.meshVideoMissing);
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _VideoPlayerScreen(path: widget.filePath!),
        ),
      ),
      child: Container(
        width: 200,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Film-strip decoration
            Icon(Icons.movie_rounded, size: 40, color: Colors.white24),
            // Play button
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            // Duration / label
            Positioned(
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.meshVideoBadge,
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen video player with play/pause controls.
class _VideoPlayerScreen extends StatefulWidget {
  final String path;
  const _VideoPlayerScreen({required this.path});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late final VideoPlayerController _ctrl;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
        _ctrl.play();
      }).catchError((e) {
        if (mounted) setState(() => _error = '$e');
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_ctrl.value.isPlaying) {
      _ctrl.pause();
    } else {
      _ctrl.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _error != null
          ? Center(
              child: Text(
                l10n.meshVideoLoadError,
                style: TextStyle(color: Colors.white70),
              ),
            )
          : !_initialized
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : GestureDetector(
                  onTap: _togglePlay,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _ctrl.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          VideoPlayer(_ctrl),
                          // Play/pause overlay
                          if (!_ctrl.value.isPlaying)
                            Center(
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          // Progress bar
                          VideoProgressIndicator(
                            _ctrl,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor:
                                  Theme.of(context).colorScheme.primary,
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Missing-media fallback bubble
// ─────────────────────────────────────────────────────────────────────────────
class _MissingMediaBubble extends StatelessWidget {
  final String label;
  const _MissingMediaBubble({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 160,
      height: 48,
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(color: cs.onErrorContainer, fontSize: 12),
      ),
    );
  }
}
