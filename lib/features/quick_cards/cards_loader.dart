import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/text_loader.dart';

const _kAssetPath = 'assets/data/cards.json';

class QuickCardEntry {
  final String id;
  final String title;
  final List<String> steps;
  final IconData icon;
  final Color color;

  const QuickCardEntry({
    required this.id,
    required this.title,
    required this.steps,
    required this.icon,
    required this.color,
  });
}

const Map<String, IconData> _iconRegistry = {
  'water_drop': Icons.water_drop_rounded,
  'local_drink': Icons.local_drink_rounded,
  'shield': Icons.shield_rounded,
  'pool': Icons.pool_rounded,
  'dangerous': Icons.dangerous_rounded,
  'medical_information': Icons.medical_information_rounded,
  'healing': Icons.healing_rounded,
  'thermostat': Icons.thermostat_rounded,
  'flood': Icons.flood_rounded,
  'cyclone': Icons.cyclone_rounded,
  'warning': Icons.warning_rounded,
  'local_fire_department': Icons.local_fire_department_rounded,
  'landslide': Icons.landslide_rounded,
  'bolt': Icons.bolt_rounded,
  'waves': Icons.waves_rounded,
  'wb_sunny': Icons.wb_sunny_rounded,
  'ac_unit': Icons.ac_unit_rounded,
  'tsunami': Icons.tsunami_rounded,
  'science': Icons.science_rounded,
  'favorite': Icons.favorite_rounded,
  'phone_in_talk': Icons.phone_in_talk_rounded,
  'air': Icons.air_rounded,
  'accessibility_new': Icons.accessibility_new_rounded,
  'help': Icons.help_outline_rounded,
};

Color _colorFromHex(String hex) {
  final stripped = hex.replaceFirst('#', '');
  return Color(int.parse('FF$stripped', radix: 16));
}

QuickCardEntry _parse(Map<String, dynamic> j) => QuickCardEntry(
      id: j['id'] as String,
      title: j['title'] as String,
      steps: (j['steps'] as List<dynamic>).cast<String>(),
      icon: _iconRegistry[j['iconName'] as String] ?? Icons.help_outline_rounded,
      color: _colorFromHex(j['colorHex'] as String),
    );

Future<List<QuickCardEntry>> loadQuickCards(String? locale) {
  return TextLoader.loadJson<List<QuickCardEntry>>(
    _kAssetPath,
    (raw) {
      final outer = jsonDecode(raw) as Map<String, dynamic>;
      // pickBundle returns the bn block or en block; the chosen block IS
      // the array of cards (it has shape [{...}, {...}, ...] directly).
      final block = TextLoader.pickBundle(outer, locale);
      final list = block['cards'] as List<dynamic>;
      return list
          .map((e) => _parse(e as Map<String, dynamic>))
          .toList(growable: false);
    },
  );
}
