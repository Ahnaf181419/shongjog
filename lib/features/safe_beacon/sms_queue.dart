import 'dart:convert';

/// Pure-Dart SMS queue.
///
/// Each entry is a JSON-encoded map with `body` and `phone` keys.
/// [drain] attempts to send every queued message via the injected
/// [sendOne] callback. On failure the message is re-queued at the
/// head so the next drain will retry it first.
///
/// The queue has no built-in connectivity awareness — the
/// `safe_beacon` screen wires the connectivity_provider stream to
/// call [drain] when the device comes online.
class SmsQueue {
  final List<String> _pending = [];
  final Future<bool> Function(String body, String phone) _sendOne;

  SmsQueue(this._sendOne);

  /// Pending message count.
  int get pending => _pending.length;

  /// Append a message. If the queue is empty, the caller may call
  /// [drain] immediately; if it's non-empty, the message waits.
  void enqueue(String body, String phone) {
    _pending.add(jsonEncode({'body': body, 'phone': phone}));
  }

  /// Drain until either the queue is empty or a send fails.
  /// Failed entries are skipped (moved to a retry list) so one
  /// bad contact does not block the remaining ones.
  Future<int> drain() async {
    final List<String> retry = [];
    int sent = 0;
    while (_pending.isNotEmpty) {
      final entry = _pending.removeAt(0);
      final Map<String, dynamic> decoded;
      try {
        decoded = jsonDecode(entry) as Map<String, dynamic>;
      } catch (_) {
        // Malformed entry, drop it.
        continue;
      }
      final body = decoded['body'] as String? ?? '';
      final phone = decoded['phone'] as String? ?? '';
      if (phone.isEmpty) continue;
      final ok = await _sendOne(body, phone);
      if (!ok) {
        retry.add(entry);
        continue;
      }
      sent++;
    }
    // Re-queue failed entries at the head for the next drain attempt.
    _pending.insertAll(0, retry);
    return sent;
  }
}