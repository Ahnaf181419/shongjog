import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'mesh_models.dart';
import 'sos_payload.dart';
import 'sos_relay.dart';

/// Subscribes to incoming mesh messages and runs SOS-shaped
/// payloads through the relay engine. Re-broadcasts via the
/// injected [sendToAll] callback when the engine says relay.
class SosRelayListener {
  final SosRelayEngine engine;
  final Future<void> Function(Uint8List bytes) sendToAll;

  const SosRelayListener({
    required this.engine,
    required this.sendToAll,
  });

  /// Called for every incoming `MeshMessage`. The caller passes the
  /// raw bytes that came off the wire (we ignore the `text` field
  /// and parse from the raw bytes for accuracy).
  Future<void> onIncoming(MeshMessage msg, {required Uint8List rawBytes}) async {
    SosPayload payload;
    try {
      payload = SosPayload.decode(utf8.decode(rawBytes, allowMalformed: true));
    } catch (_) {
      // Not a SOS payload — pass through.
      return;
    }
    final verdict = engine.onReceive(
      payload,
      from: msg.senderName,
    );
    if (verdict.shouldRelay && verdict.relayed != null) {
      await sendToAll(Uint8List.fromList(utf8.encode(verdict.relayed!.encode())));
    }
  }
}
