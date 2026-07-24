import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';

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
///   MIC → FlutterSoundRecorder (PCM 8kHz mono 16-bit) → raw Uint8List chunks
///        → Nearby().sendBytesPayload(peer) (via a special payload prefix)
///
///   Nearby bytes payload → strip prefix → FlutterSoundPlayer PCM stream
///        → speaker (earpiece or loudspeaker)
///
/// The 8kHz/16-bit mono rate (~16 KB/s) is intentionally conservative to
/// fit within BLE/Wi-Fi Direct bandwidth budgets for disaster zones.
/// Quality is equivalent to a standard voice call (G.711 µ-law).
class MeshCallService {
  static const _audioPrefix = 'CALL_AUDIO:';
  static const _signalPrefix = 'CALL_SIG:';

  final _recorder = FlutterSoundRecorder();
  final _player = FlutterSoundPlayer();

  bool _recorderReady = false;
  bool _playerReady = false;

  String? _remotePeerId;
  String? _remoteName;
  CallState _state = CallState.idle;
  bool _muted = false;
  bool _speakerOn = false;

  final _stateController = StreamController<CallState>.broadcast();
  final _incomingCallController = StreamController<CallSignalMessage>.broadcast();

  Stream<CallState> get callStateStream => _stateController.stream;
  Stream<CallSignalMessage> get incomingCallStream => _incomingCallController.stream;

  CallState get state => _state;
  bool get muted => _muted;
  bool get speakerOn => _speakerOn;
  String? get remoteName => _remoteName;

  StreamSubscription? _msgSub;

  Future<void> initialize() async {
    await _recorder.openRecorder();
    await _player.openPlayer();
    _recorderReady = true;
    _playerReady = true;

    // Listen for signalling messages coming in from mesh peers.
    _msgSub = meshService.messages.listen(_onMeshMessage);
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

  void _handleSignal(CallSignalMessage sig, String senderEndpointId) {
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
          _startAudio();
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
    if (_muted) {
      _recorder.pauseRecorder();
    } else {
      _recorder.resumeRecorder();
    }
    _stateController.add(_state); // Notify UI to refresh mute icon.
  }

  void toggleSpeaker() {
    _speakerOn = !_speakerOn;
    _player.setVolume(_speakerOn ? 1.0 : 0.5);
    _stateController.add(_state);
  }

  StreamController<Uint8List>? _micStreamCtrl;

  Future<void> _startAudio() async {
    if (!_recorderReady || !_playerReady) return;

    // Open the player to accept raw PCM from a stream.
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 8000,
      bufferSize: 8192,
      interleaved: true,
    );

    _micStreamCtrl = StreamController<Uint8List>.broadcast();
    _micStreamCtrl?.stream.listen((data) {
      if (!_muted && _remotePeerId != null) {
        _sendAudioChunk(data);
      }
    });

    // Start recording and stream mic PCM chunks to the peer.
    await _recorder.startRecorder(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 8000,
      toStream: _micStreamCtrl?.sink,
    );
  }

  void feedIncomingAudio(Uint8List data) {
    if (_state != CallState.active || !_playerReady) return;
    _player.feedUint8FromStream(data);
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
      // H5 FIX: route through meshService transport (which may be Nearby OR
      // WifiDirect) rather than hardcoding Nearby(). Hardcoding Nearby()
      // crashed on GMS-free devices that fall back to WifiDirectTransport.
      meshService.sendBytesToPeer(_remotePeerId!, packet);
    } catch (e) {
      debugPrint('MeshCallService: audio send error $e');
    }
  }

  Future<void> _endCallLocally() async {
    _setState(CallState.ended);
    await _recorder.stopRecorder();
    await _player.stopPlayer();
    await _micStreamCtrl?.close();
    _micStreamCtrl = null;
    _remotePeerId = null;
    _remoteName = null;
    _muted = false;
    await Future.delayed(const Duration(milliseconds: 300));
    _setState(CallState.idle);
  }

  void _setState(CallState s) {
    _state = s;
    _stateController.add(s);
  }

  Future<void> dispose() async {
    _msgSub?.cancel();
    await _recorder.closeRecorder();
    await _player.closePlayer();
    _stateController.close();
    _incomingCallController.close();
    _recorderReady = false;
    _playerReady = false;
  }
}

final meshCallService = MeshCallService();
