import 'package:flutter/material.dart';

import '../features/chat/chat_screen.dart';
import '../features/home/home_screen.dart';
import '../features/quick_cards/quick_cards_screen.dart';
import '../features/shelter/shelter_map_screen.dart';

/// Root app shell — a [NavigationBar] with 4 tabs, each preserving its own
/// state via an [IndexedStack]. Settings and Emergency are reached from the
/// Home tab (push routes), not as tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _goToTab(int i) => setState(() => _index = i);

  static const _destinations = [
    NavigationDestination(
      selectedIcon: Icon(Icons.home_rounded),
      icon: Icon(Icons.home_outlined),
      label: 'হোম',
    ),
    NavigationDestination(
      selectedIcon: Icon(Icons.auto_awesome_rounded),
      icon: Icon(Icons.auto_awesome_outlined),
      label: 'এআই',
    ),
    NavigationDestination(
      selectedIcon: Icon(Icons.style_rounded),
      icon: Icon(Icons.style_outlined),
      label: 'কার্ড',
    ),
    NavigationDestination(
      selectedIcon: Icon(Icons.shield_rounded),
      icon: Icon(Icons.shield_outlined),
      label: 'আশ্রয়',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onNavigateToTab: _goToTab),
          const ChatScreen(),
          const QuickCardsScreen(),
          const ShelterMapScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        destinations: _destinations,
      ),
    );
  }
}
