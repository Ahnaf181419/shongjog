import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'mesh_service.dart';

/// Handles voice recording and playback for mesh voice messages.
///
/// Recording: captures audio as .m4a, returns the temp file path.
/// Playback: sends the file path to [meshService.sendVoiceMessage].
class MeshVoiceService {
  /// Hard cap so a forgotten recording can't fill the temp dir. The `record`
  /// package's RecordConfig has no duration option, so a Timer enforces it.
  static const maxRecordingDuration = Duration(seconds: 60);

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool get isRecording => _isRecording;
  Timer? _autoStopTimer;

  /// Check if microphone permission is available.
  Future<bool> hasPermission() async {
    return _recorder.hasPermission();
  }

  /// Start recording audio. Returns when recording begins.
  ///
  /// Recording auto-stops (and sends) after [maxRecordingDuration];
  /// [onAutoStop] lets the calling screen sync its recording indicator.
  Future<bool> startRecording({void Function()? onAutoStop}) async {
    if (_isRecording) return false;

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      debugPrint('MeshVoiceService: no microphone permission');
      return false;
    }

    // Get a temp directory for the recording.
    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/mesh_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    _isRecording = true;
    _autoStopTimer = Timer(maxRecordingDuration, () async {
      if (_isRecording) {
        await stopRecordingAndSend();
        onAutoStop?.call();
      }
    });
    return true;
  }

  /// Stop recording and send the audio file to all connected peers.
  /// Returns the file path of the recording, or null if not recording.
  Future<String?> stopRecordingAndSend() async {
    if (!_isRecording) return null;

    _autoStopTimer?.cancel();
    final path = await _recorder.stop();
    _isRecording = false;

    if (path != null) {
      meshService.sendVoiceMessage(path);
    }

    return path;
  }

  /// Stop recording without sending (e.g., user cancelled).
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    _autoStopTimer?.cancel();
    final path = await _recorder.stop();
    _isRecording = false;

    // Clean up the file if not sent.
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  void dispose() {
    _autoStopTimer?.cancel();
    _recorder.dispose();
  }
}

final meshVoiceService = MeshVoiceService();
