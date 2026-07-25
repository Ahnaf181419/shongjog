import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import 'mesh_models.dart';
import 'mesh_service.dart';

/// Wire-level call signalling message types.
/// Sent as JSON bytes over the mesh payload channel.
enum CallSignal { invite, accept, reject, hangup }

/// A single signalling envelope sent between peers.
class CallSignalMessage {
  final CallSignal signal;
  final String fromId;
  final String fromName;

  CallSignalMessage({
    required this.signal,
    required this.fromId,
    required this.fromName,
  });

  Map<String, dynamic> toJson() => {
        '_call': true,
        'sig': signal.name,
        'fromId': fromId,
        'fromName': fromName,
      };

  static CallSignalMessage? tryParse(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['_call'] != true) return null;
      return CallSignalMessage(
        signal: CallSignal.values.byName(m['sig'] as String),
        fromId: m['fromId'] as String,
        fromName: m['fromName'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

/// State machine for an active call.
enum CallState { idle, ringing, active, ended }

/// Full-duplex offline voice call over Nearby Connections.
///
/// Architecture:
///   MIC → record package startStream (PCM 8kHz mono 16-bit) → Uint8List chunks
///        → Nearby().sendBytesPayload(peer) (via a special payload prefix)
///
///   Nearby bytes payload → strip prefix → MethodChannel → Android AudioTrack
///        → speaker (earpiece or loudspeaker)
///
/// The 8kHz/16-bit mono rate (~16 KB/s) is intentionally conservative to
/// fit within BLE/Wi-Fi Direct bandwidth budgets for disaster zones.
/// Quality is equivalent to a standard voice call (G.711 µ-law).
class MeshCallService {
  static const _audioPrefix = 'CALL_AUDIO:';
  static const _signalPrefix = 'CALL_SIG:';
  static const _audioChannel = MethodChannel('com.example.shongjog/audio_track');

  final AudioRecorder _recorder = AudioRecorder();

  String? _remotePeerId;
  String? _remoteName;
  CallState _state = CallState.idle;
  bool _muted = false;
  bool _speakerOn = true;
  bool _audioStarted = false;

  final _stateController = StreamController<CallState>.broadcast();
  final _incomingCallController = StreamController<CallSignalMessage>.broadcast();

  Stream<CallState> get callStateStream => _stateController.stream;
  Stream<CallSignalMessage> get incomingCallStream => _incomingCallController.stream;

  CallState get state => _state;
  bool get muted => _muted;
  bool get speakerOn => _speakerOn;
  String? get remoteName => _remoteName;

  StreamSubscription? _msgSub;
  StreamSubscription? _micSub;

  Future<void> initialize() async {
    // Listen for signalling messages coming in from mesh peers.
    _msgSub = meshService.messages.listen(_onMeshMessage);
    debugPrint('MeshCallService: initialized');
  }

  void _onMeshMessage(MeshMessage msg) {
    if (msg.isMe) return;
    if (msg.text.startsWith(_signalPrefix)) {
      final raw = msg.text.substring(_signalPrefix.length);
      final sig = CallSignalMessage.tryParse(raw);
      if (sig == null) return;
      _handleSignal(sig, msg.senderId);
    }
  }

  /// Called directly by [MeshService._onPayloadReceived] when raw bytes
  /// start with the CALL_SIG prefix.  This is the primary path; the
  /// [_msgSub] subscription is a fallback.
  void handleRawSignal(String rawJson, String senderEndpointId) {
    final sig = CallSignalMessage.tryParse(rawJson);
    if (sig != null) _handleSignal(sig, senderEndpointId);
  }

  Future<void> _handleSignal(CallSignalMessage sig, String senderEndpointId) async {
    switch (sig.signal) {
      case CallSignal.invite:
        if (_state == CallState.idle) {
          _remotePeerId = senderEndpointId;
          _remoteName = sig.fromName;
          _setState(CallState.ringing);
          _incomingCallController.add(sig);
        } else {
          _sendSignal(CallSignal.reject, senderEndpointId);
        }
        break;
      case CallSignal.accept:
        if (_state == CallState.ringing) {
          _setState(CallState.active);
          await _startAudio();
        }
        break;
      case CallSignal.reject:
        _endCallLocally();
        break;
      case CallSignal.hangup:
        _endCallLocally();
        break;
    }
  }

  /// Initiate a call to [peer].
  Future<void> call(MeshPeer peer) async {
    if (_state != CallState.idle) return;
    _remotePeerId = peer.endpointId;
    _remoteName = peer.displayName;
    _setState(CallState.ringing);
    _sendSignal(CallSignal.invite, peer.endpointId);
  }

  /// Accept an incoming call.
  Future<void> accept() async {
    if (_state != CallState.ringing) return;
    _sendSignal(CallSignal.accept, _remotePeerId!);
    _setState(CallState.active);
    await _startAudio();
  }

  /// Reject an incoming call.
  void reject() {
    if (_state != CallState.ringing) return;
    _sendSignal(CallSignal.reject, _remotePeerId!);
    _endCallLocally();
  }

  /// Hang up the current call.
  Future<void> hangUp() async {
    if (_state == CallState.idle) return;
    _sendSignal(CallSignal.hangup, _remotePeerId!);
    await _endCallLocally();
  }

  void toggleMute() {
    _muted = !_muted;
    _stateController.add(_state);
  }

  Future<void> toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    try {
      await _audioChannel.invokeMethod('setSpeaker', {'on': _speakerOn});
    } catch (e) {
      debugPrint('MeshCallService: setSpeaker error $e');
    }
    _stateController.add(_state);
  }

  Future<void> _startAudio() async {
    debugPrint('MeshCallService: _startAudio called');
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      debugPrint('MeshCallService: no microphone permission');
      return;
    }

    try {
      // Start AudioTrack playback on the native side.
      await _audioChannel.invokeMethod('start', {
        'sampleRate': 8000,
        'numChannels': 1,
      });
      _audioStarted = true;
      debugPrint('MeshCallService: AudioTrack started');
    } catch (e) {
      debugPrint('MeshCallService: AudioTrack start failed: $e');
      return;
    }

    // Default to speaker for mesh calls (user holds phone in front, not at ear).
    try {
      await _audioChannel.invokeMethod('setSpeaker', {'on': true});
    } catch (_) {}

    // Start recording and stream mic PCM chunks to the peer.
    try {
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 8000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
          androidConfig: const AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceCommunication,
            audioManagerMode: AudioManagerMode.modeInCommunication,
            speakerphone: true,
          ),
        ),
      );
      _micSub = stream.listen((data) {
        if (!_muted && _remotePeerId != null) {
          _sendAudioChunk(data);
        }
      });
      debugPrint('MeshCallService: recorder stream started');
    } catch (e) {
      debugPrint('MeshCallService: recorder start failed: $e');
    }
  }

  void feedIncomingAudio(Uint8List data) {
    if (_state != CallState.active || !_audioStarted) return;
    _audioChannel.invokeMethod('feed', {'data': data}).catchError((e) {
      debugPrint('MeshCallService: audio feed error $e');
    });
  }

  void _sendSignal(CallSignal sig, String targetId) {
    final env = CallSignalMessage(
      signal: sig,
      fromId: meshService.userName,
      fromName: meshService.userName
          .replaceFirst(kMeshPeerPrefix, ''),
    );
    meshService.sendMessage(
      '$_signalPrefix${jsonEncode(env.toJson())}',
      targetEndpointId: targetId,
      echoSelf: false,
    );
  }

  void _sendAudioChunk(Uint8List data) {
    try {
      final prefix = utf8.encode(_audioPrefix);
      final packet = Uint8List(prefix.length + data.length);
      packet.setAll(0, prefix);
      packet.setAll(prefix.length, data);
      meshService.sendBytesToPeer(_remotePeerId!, packet);
    } catch (e) {
      debugPrint('MeshCallService: audio send error $e');
    }
  }

  Future<void> _endCallLocally() async {
    _setState(CallState.ended);
    _audioStarted = false;
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    try {
      await _audioChannel.invokeMethod('stop');
    } catch (_) {}
    _remotePeerId = null;
    _remoteName = null;
    _muted = false;
    await Future.delayed(const Duration(milliseconds: 300));
    _setState(CallState.idle);
    debugPrint('MeshCallService: call ended');
  }

  void _setState(CallState s) {
    _state = s;
    _stateController.add(s);
  }

  Future<void> dispose() async {
    _msgSub?.cancel();
    _micSub?.cancel();
    _stateController.close();
    _incomingCallController.close();
  }
}

final meshCallService = MeshCallService();
