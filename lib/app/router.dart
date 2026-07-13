import 'package:flutter/material.dart';

import '../features/chat/chat_screen.dart';
import '../features/quick_cards/quick_cards_screen.dart';
import '../features/shelter/shelter_map_screen.dart';

/// Route constants — the public contract Maruf and Sehab code against.
///
/// Maruf's quick-cards screen (Phase 1.3) and Sehab's about page (Phase 4.7)
/// will be added here at IC-2 / IC-3. Adding a route here MUST be paired with
/// adding the screen to AppRoutes.all() in the same commit.
class AppRoutes {
  static const chat = '/';
  static const quickCards = '/cards';
  static const shelterMap = '/shelter';

  static Map<String, WidgetBuilder> all() => {
        chat: (_) => const ChatScreen(),
        quickCards: (_) => const QuickCardsScreen(),
        shelterMap: (_) => const ShelterMapScreen(),
      };
}