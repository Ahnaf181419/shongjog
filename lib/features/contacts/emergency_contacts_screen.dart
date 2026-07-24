import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../emergency/emergency_actions.dart';
import '../emergency/emergency_sheet.dart';
import 'contact_model.dart';
import 'contacts_repository.dart';

/// Emergency contacts screen.
///
/// Top: slide-to-confirm 999 hero (alertRed, the panic path).
/// Middle: national numbers as tappable soft-elevation rows.
/// Bottom: user-added custom contacts + add button.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<Contact> _custom = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final list = await ContactsRepository.loadCustom();
    if (mounted) {
      setState(() {
        _custom = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).contactsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // ── Hero panic button ──
          _PanicHero(onTap: () => EmergencySheet.show(context)),
          const SizedBox(height: 24),

          // ── National list ──
          _SectionLabel(AppLocalizations.of(context).nationalNumbers),
          const SizedBox(height: 8),
          ...nationalContacts.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ContactRow(
                  contact: c,
                  onTap: () => EmergencyActions.dial(c.phone),
                ),
              )),

          // ── Custom contacts ──
          const SizedBox(height: 24),
          _SectionLabel(AppLocalizations.of(context).myContacts),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_custom.isEmpty)
            _EmptyCustomState(onAdd: _showAddSheet)
          else
            ..._custom.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ContactRow(
                    contact: c,
                    onTap: () => EmergencyActions.dial(c.phone),
                    onDelete: c.isCustom
                        ? () => _deleteContact(c)
                        : null,
                  ),
                )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(ShongjogTheme.radiusLg)),
      ),
      builder: (ctx) => _AddContactSheet(onSaved: (_) {
        Navigator.pop(ctx);
        _refresh();
      }),
    );
  }

  Future<void> _deleteContact(Contact c) async {
    await ContactsRepository.removeCustom(c.id);
    _refresh();
  }
}

// ════════════════════════════════════════════════════════════════
//  Hero panic button
// ════════════════════════════════════════════════════════════════

class _PanicHero extends StatelessWidget {
  final VoidCallback onTap;
  const _PanicHero({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.error,
      borderRadius: BorderRadius.circular(ShongjogTheme.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_in_talk_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).panicHeroTitle,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        fontFamily: ShongjogTheme.fontFamily,
                        color: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).panicHeroSubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: ShongjogTheme.fontFamily,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Contact row
// ════════════════════════════════════════════════════════════════

class _ContactRow extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ContactRow({
    required this.contact,
    required this.onTap,
    this.onDelete,
  });

  String get _phoneBn => contact.phone.split('').map((d) {
        const m = {
          '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
          '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
        };
        return m[d] ?? d;
      }).join();

  @override
  Widget build(BuildContext context) {
    final meta = categoryMeta[contact.category]!;
    final accent = Theme.of(context).colorScheme.primary;

    return Dismissible(
      key: ValueKey(contact.id),
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        if (onDelete == null) return false;
        onDelete!();
        return false;
      },
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: ShongjogTheme.cardDecoration(context),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      ShongjogTheme.iconBadge(context, tint: accent),
                  child: Icon(meta.icon, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.nameBn,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: ShongjogTheme.fontFamily,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta.labelBn,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: ShongjogTheme.fontFamily,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _phoneBn,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: ShongjogTheme.fontFamily,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.phone_rounded, color: accent, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Section label + empty state
// ════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFamily: ShongjogTheme.fontFamily,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _EmptyCustomState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCustomState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: ShongjogTheme.cardDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.person_add_rounded,
            size: 36,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).addCustomContact,
            style: TextStyle(
              fontSize: 15,
              fontFamily: ShongjogTheme.fontFamily,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(AppLocalizations.of(context).addContact),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Add-contact bottom sheet
// ════════════════════════════════════════════════════════════════

class _AddContactSheet extends StatefulWidget {
  final ValueChanged<Contact> onSaved;
  const _AddContactSheet({required this.onSaved});

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  ContactCategory _category = ContactCategory.other;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).nameAndNumberRequired)),
      );
      return;
    }
    final contact = Contact(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      nameBn: name,
      phone: phone,
      category: _category,
      isCustom: true,
    );
    await ContactsRepository.addCustom(contact);
    HapticFeedback.mediumImpact();
    widget.onSaved(contact);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            AppLocalizations.of(context).newContact,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: ShongjogTheme.fontFamily,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).nameLabel,
              hintText: AppLocalizations.of(context).nameHint,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).phoneLabel,
              hintText: AppLocalizations.of(context).phoneHint,
              prefixText: AppLocalizations.of(context).phonePrefix,
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ContactCategory>(
            initialValue: _category,
            decoration: InputDecoration(labelText: AppLocalizations.of(context).categoryLabel),
            items: ContactCategory.values.map((c) {
              final meta = categoryMeta[c]!;
              return DropdownMenuItem(
                value: c,
                child: Row(
                  children: [
                    Icon(meta.icon, size: 20),
                    const SizedBox(width: 10),
                    Text(meta.labelBn),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _category = v ?? ContactCategory.other),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
  }
}
