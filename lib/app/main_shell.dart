import 'package:flutter/material.dart';

import '../features/chat/chat_screen.dart';
import '../features/home/home_screen.dart';
import '../features/quick_cards/quick_cards_screen.dart';
import 'dart:async';
import '../features/shelter/shelter_map_screen.dart';
import '../l10n/app_localizations.dart';
import '../features/mesh_comm/mesh_call_screen.dart';
import '../features/mesh_comm/mesh_call_service.dart';
import '../features/mesh_comm/mesh_models.dart';
import '../features/mesh_comm/mesh_service.dart';

/// Root app shell — a [NavigationBar] with 4 tabs. Tabs are lazily built
/// on first selection and kept alive via [Offstage] to preserve state.
/// Settings and Emergency are reached from the Home tab (push routes),
/// not as tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Switch the bottom-nav tab from outside the shell (e.g. a CTA on the
  /// chat empty state wanting to jump to the cards tab). The shell key is
  /// stashed on the topmost [ScaffoldMessenger] ancestor; we look it up by
  /// state type to keep this cheap and explicit.
  static void goToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainShellState>();
    state?._goToTab(index);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  StreamSubscription? _connectionSub;
  StreamSubscription? _incomingCallSub;

  @override
  void initState() {
    super.initState();
    _connectionSub = meshService.connectionRequests.listen((event) {
      if (!mounted) return;
      _showConnectionDialog(event);
    });
    _incomingCallSub = meshCallService.incomingCallStream.listen((sig) {
      if (!mounted) return;
      _showIncomingCall(sig);
    });
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _incomingCallSub?.cancel();
    super.dispose();
  }

  void _showConnectionDialog(ConnectionRequestEvent event) {
    final displayName = event.endpointName.startsWith(kMeshPeerPrefix) 
        ? event.endpointName.substring(kMeshPeerPrefix.length) 
        : event.endpointName;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('নতুন সংযোগের অনুরোধ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              child: Icon(Icons.person, size: 30),
            ),
            SizedBox(height: 16),
            Text(
              '$displayName আপনার সাথে কানেক্ট হতে চাচ্ছে।',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              meshService.rejectConnection(event.endpointId);
              Navigator.pop(ctx);
            },
            child: Text('প্রত্যাখ্যান'),
          ),
          FilledButton(
            onPressed: () {
              meshService.acceptConnection(event.endpointId);
              Navigator.pop(ctx);
            },
            child: Text('গ্রহণ করুন'),
          ),
        ],
      ),
    );
  }

  void _showIncomingCall(CallSignalMessage sig) {
    // Build a synthetic peer from the signal sender info.
    final peer = MeshPeer(
      endpointId: sig.fromId,
      name: sig.fromName,
      status: PeerStatus.connected,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeshCallScreen(peer: peer, isIncoming: true),
      ),
    );
  }

  int _index = 0;
  final Map<int, Widget> _tabCache = {};

  void _goToTab(int i) => setState(() => _index = i);

  Widget _buildTab(int index) {
    return _tabCache.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return HomeScreen(onNavigateToTab: _goToTab);
        case 1:
          return const ChatScreen();
        case 2:
          return const QuickCardsScreen();
        case 3:
          return const ShelterMapScreen();
        default:
          return const SizedBox.shrink();
      }
    });
  }

  List<NavigationDestination> _destinations(BuildContext context) => [
    NavigationDestination(
      selectedIcon: Icon(Icons.home_rounded),
      icon: Icon(Icons.home_outlined),
      label: AppLocalizations.of(context).navHome,
    ),
    NavigationDestination(
      selectedIcon: Icon(Icons.auto_awesome_rounded),
      icon: Icon(Icons.auto_awesome_outlined),
      label: AppLocalizations.of(context).navAi,
    ),
    NavigationDestination(
      selectedIcon: Icon(Icons.style_rounded),
      icon: Icon(Icons.style_outlined),
      label: AppLocalizations.of(context).navCards,
    ),
    NavigationDestination(
      selectedIcon: Icon(Icons.shield_rounded),
      icon: Icon(Icons.shield_outlined),
      label: AppLocalizations.of(context).navShelter,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: Stack(
          children: [
            for (int i = 0; i < 4; i++)
              Offstage(
                offstage: _index != i,
                child: _buildTab(i),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goToTab,
          destinations: _destinations(context),
        ),
      ),
    );
  }
}
