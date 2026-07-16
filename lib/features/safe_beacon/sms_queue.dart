/// Pure-Dart SMS queue.
///
/// Each entry is a `body::phone` string. [drain] attempts to send
/// every queued message via the injected [sendOne] callback. On
/// failure the message is re-queued at the head so the next drain
/// will retry it first.
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
    _pending.add('$body::$phone');
  }

  /// Drain until either the queue is empty or a send fails.
  /// Returns the number of messages sent successfully.
  Future<int> drain() async {
    int sent = 0;
    while (_pending.isNotEmpty) {
      final entry = _pending.first;
      final sep = entry.indexOf('::');
      if (sep < 0) {
        // Defensive: malformed entry, drop it.
        _pending.removeAt(0);
        continue;
      }
      final body = entry.substring(0, sep);
      final phone = entry.substring(sep + 2);
      final ok = await _sendOne(body, phone);
      if (!ok) {
        // Stop draining; the failed message stays at the head.
        break;
      }
      _pending.removeAt(0);
      sent++;
    }
    return sent;
  }
}