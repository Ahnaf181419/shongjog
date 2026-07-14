import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contact_model.dart';

/// National emergency numbers (verified against BTRC directory) — always
/// shown above user-added custom contacts so the user can reach a real
/// hotline in one tap regardless of state.
final List<Contact> nationalContacts = [
  const Contact(
    id: 'police',
    nameBn: 'পুলিশ',
    phone: '999',
    category: ContactCategory.police,
  ),
  const Contact(
    id: 'fire',
    nameBn: 'ফায়ার সার্ভিস',
    phone: '16163',
    category: ContactCategory.fire,
  ),
  const Contact(
    id: 'ambulance',
    nameBn: 'অ্যাম্বুলেন্স',
    phone: '999',
    category: ContactCategory.ambulance,
  ),
  const Contact(
    id: 'disaster',
    nameBn: 'দুর্যোগ ব্যবস্থাপনা',
    phone: '333',
    category: ContactCategory.disaster,
  ),
  const Contact(
    id: 'redCrescent',
    nameBn: 'রেড ক্রিসেন্ট',
    phone: '966',
    category: ContactCategory.redCrescent,
  ),
  const Contact(
    id: 'health',
    nameBn: 'স্বাস্থ্য হটলাইন',
    phone: '16263',
    category: ContactCategory.health,
  ),
];

/// Per-category icon + Bangla label metadata.
const categoryMeta = <ContactCategory, ({IconData icon, String labelBn})>{
  ContactCategory.police:
      (icon: Icons.local_police_rounded, labelBn: 'পুলিশ'),
  ContactCategory.fire:
      (icon: Icons.local_fire_department_rounded, labelBn: 'ফায়ার'),
  ContactCategory.ambulance:
      (icon: Icons.medical_services_rounded, labelBn: 'অ্যাম্বুলেন্স'),
  ContactCategory.disaster:
      (icon: Icons.tornado_rounded, labelBn: 'দুর্যোগ'),
  ContactCategory.redCrescent:
      (icon: Icons.volunteer_activism_rounded, labelBn: 'রেড ক্রিসেন্ট'),
  ContactCategory.health:
      (icon: Icons.support_agent_rounded, labelBn: 'স্বাস্থ্য'),
  ContactCategory.other:
      (icon: Icons.person_rounded, labelBn: 'অন্যান্য'),
};

/// CRUD for user-added custom contacts, stored as JSON in shared_preferences.
class ContactsRepository {
  static const _key = 'pref_custom_contacts';

  static Future<List<Contact>> loadCustom() async {
    final prefs = await SharedPreferences.getInstance();
    return Contact.decodeList(prefs.getString(_key));
  }

  static Future<void> addCustom(Contact c) async {
    final prefs = await SharedPreferences.getInstance();
    final list = Contact.decodeList(prefs.getString(_key));
    list.add(c);
    await prefs.setString(_key, Contact.encodeList(list));
  }

  static Future<void> removeCustom(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = Contact.decodeList(prefs.getString(_key))
        .where((c) => c.id != id)
        .toList();
    await prefs.setString(_key, Contact.encodeList(list));
  }
}
