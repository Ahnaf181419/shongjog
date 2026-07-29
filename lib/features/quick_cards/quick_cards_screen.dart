import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../app/theme.dart';
import 'cards_data.dart';
import '../../core/bangla_numerals.dart';

/// Quick cards screen — 8 static Bangla emergency cards.
/// Works with no model loaded (safety net, docs/prd.md M4).
/// Per design.md §7.2: ExpansionTile, numbered Bangla steps, 12dp spacing.
class QuickCardsScreen extends StatefulWidget {
  final void Function(String prompt) onRequestAiChat;

  const QuickCardsScreen({super.key, required this.onRequestAiChat});

  @override
  State<QuickCardsScreen> createState() => _QuickCardsScreenState();
}

class _QuickCardsScreenState extends State<QuickCardsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QuickCard> get _filteredCards {
    if (_query.isEmpty) return kQuickCards;
    final q = _query.toLowerCase();
    return kQuickCards.where((card) {
      final titleMatch = card.titleBn.toLowerCase().contains(q);
      final stepsMatch = card.stepsBn.any((s) => s.toLowerCase().contains(q));
      return titleMatch || stepsMatch;
    }).toList();
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
                  borderSide: BorderSide(color: ShongjogTheme.ocean, width: 2),
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
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _filteredCards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _CardTile(
                card: _filteredCards[i],
                onRequestAiChat: widget.onRequestAiChat,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final QuickCard card;
  final void Function(String prompt) onRequestAiChat;

  const _CardTile({required this.card, required this.onRequestAiChat});

  @override
  Widget build(BuildContext context) {
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
            card.titleBn,
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
            ...card.stepsBn.asMap().entries.map((e) => Padding(
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
                            banglaNumber(e.key + 1),
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
                      card.stepsBn.isNotEmpty ? card.stepsBn.first : '';
                  onRequestAiChat('${card.titleBn}। $firstStep');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}