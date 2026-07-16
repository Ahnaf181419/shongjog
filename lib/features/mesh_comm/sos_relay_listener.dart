import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'mesh_models.dart';
import 'sos_payload.dart';
import 'sos_relay.dart';

/// Bridges incoming raw mesh bytes to the SOS relay engine.
///
/// On every message, the listener:
/// 1. Tries to decode the bytes as a [SosPayload].
/// 2. If decoding fails, emits a [MeshMessage] with no hopCount
///    (it's plain text — pass through).
/// 3. If decoding succeeds, runs the engine. If the engine says
///    relay, calls [sendToAll] with the relayed bytes. Either
///    way, emits a [MeshMessage] annotated with the payload's
///    [SosPayload.hopCount] so the chat bubble can render the
///    "↻ N hops" chip.
class SosRelayListener {
  final SosRelayEngine engine;
  final Future<void> Function(Uint8List bytes) sendToAll;
  final void Function(MeshMessage msg) emit;

  const SosRelayListener({
    required this.engine,
    required this.sendToAll,
    required this.emit,
  });

  Future<void> onIncoming(MeshMessage msg, {required Uint8List rawBytes}) async {
    SosPayload payload;
    try {
      payload = SosPayload.decode(utf8.decode(rawBytes, allowMalformed: true));
    } catch (_) {
      // Not a SOS payload — pass through with no hopCount.
      emit(msg);
      return;
    }
    final verdict = engine.onReceive(
      payload,
      from: msg.senderName,
    );
    if (verdict.shouldRelay && verdict.relayed != null) {
      await sendToAll(
        Uint8List.fromList(utf8.encode(verdict.relayed!.encode())),
      );
    }
    // Always emit a local message with the hopCount, regardless of
    // whether we relayed or not. The chat bubble decides what to show.
    emit(MeshMessage(
      senderId: msg.senderId,
      senderName: msg.senderName,
      text: payload.message,
      type: MessageType.text,
      hopCount: payload.hopCount,
    ));
  }
}