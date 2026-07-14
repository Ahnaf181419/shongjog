import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'cards_data.dart';

/// Quick cards screen — 6 static Bangla emergency cards.
/// Works with no model loaded (safety net, docs/prd.md M4).
/// Per design.md §7.2: ExpansionTile, numbered Bangla steps, 12dp spacing.
class QuickCardsScreen extends StatelessWidget {
  const QuickCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('জরুরি সহায়তা কার্ড')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: kQuickCards.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _CardTile(card: kQuickCards[i]),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final QuickCard card;
  const _CardTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ShongjogTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShongjogTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: card.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(card.icon, color: card.color, size: 24),
          ),
          title: Text(
            card.titleBn,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
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
                            _bnNum(e.key + 1),
                            style: TextStyle(
                              fontSize: 13,
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
                            color: ShongjogTheme.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _bnNum(int n) {
    const digits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return n.toString().split('').map((d) => digits[int.parse(d)]).join();
  }
}