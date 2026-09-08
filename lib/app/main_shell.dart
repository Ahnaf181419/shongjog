import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/local_notification_service.dart';
import '../core/pending_chat_prompt.dart';
import '../features/chat/chat_screen.dart';
import '../features/home/home_screen.dart';
import '../features/quick_cards/quick_cards_screen.dart';
import '../features/tools/tools_screen.dart';
import 'dart:async';
import '../features/shelter/shelter_map_screen.dart';
import '../l10n/app_localizations.dart';
import '../features/mesh_comm/mesh_call_screen.dart';
import '../features/mesh_comm/mesh_call_service.dart';
import '../features/mesh_comm/mesh_models.dart';
import '../features/mesh_comm/mesh_service.dart';
import 'theme.dart';

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
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.meshConnectionRequest),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                child: Icon(Icons.person_rounded, size: 30),
              ),
              SizedBox(height: 16),
              Text(
                l10n.meshWantsToConnect(displayName),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              style: ShongjogTheme.dialogAction(),
              onPressed: () {
                meshService.rejectConnection(event.endpointId);
                Navigator.pop(ctx);
              },
              child: Text(l10n.meshReject),
            ),
            FilledButton(
              style: ShongjogTheme.dialogAction(),
              onPressed: () {
                meshService.acceptConnection(event.endpointId);
                Navigator.pop(ctx);
              },
              child: Text(l10n.meshAccept),
            ),
          ],
        );
      },
    );
  }

  void _showIncomingCall(CallSignalMessage sig) {
    final displayName = sig.fromName.startsWith(kMeshPeerPrefix)
        ? sig.fromName.substring(kMeshPeerPrefix.length)
        : sig.fromName;

    // Vibrate immediately for tactile feedback.
    try {
      HapticFeedback.vibrate();
    } catch (_) {}

    // Show a heads-up notification (visible even when on another page).
    localNotificationService.showCallNotification(
      callerName: displayName,
      onTap: () {
        // Navigate to the call screen when notification is tapped.
        if (!mounted) return;
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
      },
    );

    // Also navigate directly if the app is in the foreground.
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

  void _onRequestAiChat(String prompt) {
    PendingChatPrompt.of(context)?.requestPrompt(prompt);
    _goToTab(1);
  }

  Widget _buildTab(int index) {
    return _tabCache.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return HomeScreen(onNavigateToTab: _goToTab);
        case 1:
          return const ChatScreen();
        case 2:
          return const ToolsScreen();
        case 3:
          return QuickCardsScreen(onRequestAiChat: _onRequestAiChat);
        case 4:
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
      selectedIcon: Icon(Icons.build_rounded),
      icon: Icon(Icons.build_outlined),
      label: AppLocalizations.of(context).navTools,
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

  Widget _buildFloatingNavBar(BuildContext context) {
    final dests = _destinations(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dests.length, (i) {
            final isSelected = _index == i;
            final dest = dests[i];
            // Audit F6 (2026-09-08): the custom GestureDetector pill had
            // no Semantics label — TalkBack on the four unselected pills
            // announced only "button" with no name. Using Semantics(onTap)
            // here (rather than wrapping the GestureDetector) gives one
            // shared labelled, tappable node instead of two stacked ones,
            // and announces the selected state to screen readers.
            return Semantics(
              button: true,
              selected: isSelected,
              enabled: true,
              label: dest.label,
              onTap: () {
                try {
                  HapticFeedback.lightImpact();
                } catch (_) {}
                _goToTab(i);
              },
              child: ExcludeSemantics(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 16 : 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: Icon(
                          isSelected
                              ? (dest.selectedIcon as Icon).icon
                              : (dest.icon as Icon).icon,
                          key: ValueKey<bool>(isSelected),
                          color: isSelected
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.6),
                          size: 24,
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: isSelected
                            ? Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  dest.label,
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            for (int i = 0; i < 5; i++)
              Offstage(
                offstage: _index != i,
                child: _buildTab(i),
              ),
          ],
        ),
        bottomNavigationBar: _buildFloatingNavBar(context),
      ),
    );
  }
}
