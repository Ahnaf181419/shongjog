import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../app/theme.dart';
import '../../core/locale_controller.dart';
import 'cards_data.dart';
import '../../core/bangla_numerals.dart';

/// Quick cards screen — 25 static emergency cards (bn+en).
/// Source of truth for card copy: assets/data/cards.json (see Phase 2.1
/// of docs/superpowers/plans/2026-09-09-text-consolidation.md).
///
/// Cards are loaded per-build via [FutureBuilder] from [loadQuickCards]
/// using the live locale. TextLoader caches per-locale so this is
/// essentially free after the first call, and locale switches refresh
/// the list immediately because the whole MaterialApp rebuilds.
class QuickCardsScreen extends StatefulWidget {
  final void Function(String prompt) onRequestAiChat;

  const QuickCardsScreen({super.key, required this.onRequestAiChat});

  @override
  State<QuickCardsScreen> createState() => _QuickCardsScreenState();
}

class _QuickCardsScreenState extends State<QuickCardsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _cardsLocale = localeController.languageCode;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rebuild the FutureBuilder when the locale changes so the card list
    // refreshes without the user leaving the screen.
    final current = AppLocalizations.of(context).localeName;
    if (current != _cardsLocale) {
      _cardsLocale = current;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.quickCardsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.quickCardsSearchHint,
                hintStyle: TextStyle(
                  color: ShongjogTheme.bodySecondary(context),
                  fontSize: 16,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: ShongjogTheme.bodySecondary(context)),
                filled: true,
                fillColor: ShongjogTheme.cardSurface(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                  borderSide: BorderSide(color: ShongjogTheme.hairline(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                  borderSide: BorderSide(color: ShongjogTheme.hairline(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: ShongjogTheme.bodySecondary(context)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<QuickCardEntry>>(
              key: ValueKey(_cardsLocale),
              future: loadQuickCards(_cardsLocale),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.commonLoading,
                        style: TextStyle(color: ShongjogTheme.bodySecondary(context)),
                      ),
                    ),
                  );
                }
                final cards = snap.data ?? const <QuickCardEntry>[];
                final filtered = _query.isEmpty
                    ? cards
                    : cards.where((c) {
                        final q = _query.toLowerCase();
                        return c.title.toLowerCase().contains(q) ||
                            c.steps.any((s) => s.toLowerCase().contains(q));
                      }).toList();
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _CardTile(
                    card: filtered[i],
                    onRequestAiChat: widget.onRequestAiChat,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final QuickCardEntry card;
  final void Function(String prompt) onRequestAiChat;

  const _CardTile({required this.card, required this.onRequestAiChat});

  @override
  Widget build(BuildContext context) {
    final localeName = AppLocalizations.of(context).localeName;
    return Container(
      decoration: BoxDecoration(
        color: ShongjogTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
        border: Border.all(color: ShongjogTheme.hairline(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: card.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
            ),
            child: Icon(card.icon, color: card.color, size: 24),
          ),
          title: Text(
            card.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ShongjogTheme.body(context),
            ),
          ),
          iconColor: ShongjogTheme.bodySecondary(context),
          collapsedIconColor: ShongjogTheme.bodySecondary(context),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ...card.steps.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 1, right: 10),
                        decoration: BoxDecoration(
                          color: card.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            numberForLocale(e.key + 1, localeName),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: card.color,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            color: ShongjogTheme.body(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 34),
              child: ActionChip(
                avatar: Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: card.color,
                ),
                label: Text(AppLocalizations.of(context).cardAiButton),
                backgroundColor: card.color.withValues(alpha: 0.08),
                side: BorderSide(color: card.color.withValues(alpha: 0.3)),
                onPressed: () {
                  final firstStep =
                      card.steps.isNotEmpty ? card.steps.first : '';
                  final sep = localeController.isBangla ? '। ' : '. ';
                  onRequestAiChat('${card.title}$sep$firstStep');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
