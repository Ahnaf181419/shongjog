import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import 'contact_model.dart';

/// National emergency numbers (verified against BTRC directory) — always
/// shown above user-added custom contacts so the user can reach a real
/// hotline in one tap regardless of state.
///
/// Names are localized via [l10n] using [buildNationalContacts].
List<Contact> buildNationalContacts(AppLocalizations l10n) => [
  Contact(
    id: 'police',
    nameBn: l10n.nationalContactPolice,
    phone: '999',
    category: ContactCategory.police,
  ),
  Contact(
    id: 'fire',
    nameBn: l10n.nationalContactFireService,
    phone: '16163',
    category: ContactCategory.fire,
  ),
  Contact(
    id: 'ambulance',
    nameBn: l10n.nationalContactAmbulance,
    phone: '999',
    category: ContactCategory.ambulance,
  ),
  Contact(
    id: 'disaster',
    nameBn: l10n.nationalContactDisasterMgmt,
    phone: '333',
    category: ContactCategory.disaster,
  ),
  Contact(
    id: 'redCrescent',
    nameBn: l10n.nationalContactRedCrescent,
    phone: '966',
    category: ContactCategory.redCrescent,
  ),
  Contact(
    id: 'health',
    nameBn: l10n.nationalContactHealthHotline,
    phone: '16263',
    category: ContactCategory.health,
  ),
];

/// Per-category icon metadata.
const categoryMeta = <ContactCategory, ({IconData icon})>{
  ContactCategory.police:
      (icon: Icons.local_police_rounded),
  ContactCategory.fire:
      (icon: Icons.local_fire_department_rounded),
  ContactCategory.ambulance:
      (icon: Icons.medical_services_rounded),
  ContactCategory.disaster:
      (icon: Icons.tornado_rounded),
  ContactCategory.redCrescent:
      (icon: Icons.volunteer_activism_rounded),
  ContactCategory.health:
      (icon: Icons.support_agent_rounded),
  ContactCategory.other:
      (icon: Icons.person_rounded),
};

extension ContactCategoryLabel on ContactCategory {
  String label(BuildContext context) => switch (this) {
    ContactCategory.police => AppLocalizations.of(context).nationalContactPolice,
    ContactCategory.fire => AppLocalizations.of(context).nationalContactFireService,
    ContactCategory.ambulance => AppLocalizations.of(context).nationalContactAmbulance,
    ContactCategory.disaster => AppLocalizations.of(context).nationalContactDisasterMgmt,
    ContactCategory.redCrescent => AppLocalizations.of(context).nationalContactRedCrescent,
    ContactCategory.health => AppLocalizations.of(context).nationalContactHealthHotline,
    ContactCategory.other => AppLocalizations.of(context).contactOther,
  };
}

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
