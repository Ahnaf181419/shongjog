import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/core/admin_broadcast_service.dart';

void main() {
  // Audit F5 (2026-09-08): the screen's per-instance `_hasMarkedRead` flag
  // was dead code (initState runs once per State, so the flag flipped
  // back to false on every push). The static guard fix lives on the
  // screen State — this test pins the service half: a tap on a tile
  // must mark that one specific message read (not "all on open") via
  // AdminBroadcastService.markRead.

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await adminBroadcastService.clear();
  });

  test('markRead flips isRead on the targeted message', () async {
    await adminBroadcastService.addMessage('m1 body');
    await adminBroadcastService.addMessage('m2 body');
    expect(adminBroadcastService.messages.where((m) => !m.isRead).length, 2);

    // IDs are generated; capture them from the populated list.
    final ids = adminBroadcastService.messages.map((m) => m.id).toList();
    await adminBroadcastService.markRead(ids[0]);
    final byId = {for (final m in adminBroadcastService.messages) m.id: m};
    expect(byId[ids[0]]!.isRead, isTrue,
        reason: 'First message must be marked read after markRead');
    expect(byId[ids[1]]!.isRead, isFalse,
        reason: 'Second message must remain unread — markRead is per-tile');
  });

  test('markRead on an unknown id is a no-op', () async {
    await adminBroadcastService.addMessage('only message');
    final beforeCount = adminBroadcastService.messages.length;
    await adminBroadcastService.markRead('does-not-exist');
    expect(adminBroadcastService.messages.length, beforeCount);
    expect(adminBroadcastService.messages.first.isRead, isFalse);
  });
}
