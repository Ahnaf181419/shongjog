import 'package:flutter/material.dart';

import '../features/about/about_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/hub/emergency_hub_screen.dart';
import '../features/quick_cards/quick_cards_screen.dart';
import '../features/shelter/shelter_map_screen.dart';

/// Route constants — the public contract the team codes against.
///
/// Hub is the home route (initialRoute). From there the user reaches
/// chat, cards, shelter, about, and emergency via single taps.
class AppRoutes {
  static const hub = '/';
  static const chat = '/chat';
  static const quickCards = '/cards';
  static const shelterMap = '/shelter';
  static const about = '/about';

  static Map<String, WidgetBuilder> all() => {
        hub: (_) => const EmergencyHubScreen(),
        chat: (_) => const ChatScreen(),
        quickCards: (_) => const QuickCardsScreen(),
        shelterMap: (_) => const ShelterMapScreen(),
        about: (_) => const AboutScreen(),
      };
}