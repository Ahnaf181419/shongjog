import 'dart:convert';

/// A single emergency contact — national or user-added.
class Contact {
  final String id;
  final String nameBn;
  final String phone;
  final ContactCategory category;
  final bool isCustom;

  const Contact({
    required this.id,
    required this.nameBn,
    required this.phone,
    required this.category,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameBn': nameBn,
        'phone': phone,
        'category': category.name,
        'isCustom': isCustom,
      };

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
        id: j['id'] as String,
        nameBn: j['nameBn'] as String,
        phone: j['phone'] as String,
        category: ContactCategory.values.byName(j['category'] as String),
        isCustom: j['isCustom'] as bool? ?? false,
      );

  Contact copyWith({String? nameBn, String? phone, ContactCategory? category}) =>
      Contact(
        id: id,
        nameBn: nameBn ?? this.nameBn,
        phone: phone ?? this.phone,
        category: category ?? this.category,
        isCustom: isCustom,
      );

  static String encodeList(List<Contact> list) =>
      jsonEncode(list.map((c) => c.toJson()).toList());

  static List<Contact> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => Contact.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Contact grouping for the national list + custom contacts.
enum ContactCategory {
  police,
  fire,
  ambulance,
  disaster,
  redCrescent,
  health,
  other,
}
