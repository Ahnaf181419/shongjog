import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../../app/theme.dart';
import '../nearest_shelter.dart';

/// Full-screen search overlay listing [ranked] shelters with a live
/// text filter. Tapping a row calls [onSelect]; the X in the suffix
/// slot (or the close action) calls [onClose].
///
/// State is owned by this widget: it allocates and disposes its own
/// [TextEditingController] for the filter field — preventing the
/// "controller created in a rebuild-able method" leak that the
/// inline version in the State class had.
class ShelterSearchPanel extends StatefulWidget {
  final List<RankedShelter> ranked;
  final ValueChanged<RankedShelter> onSelect;
  final VoidCallback onClose;

  const ShelterSearchPanel({
    super.key,
    required this.ranked,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<ShelterSearchPanel> createState() => _ShelterSearchPanelState();
}

class _ShelterSearchPanelState extends State<ShelterSearchPanel> {
  final TextEditingController _ctrl = TextEditingController();
  late List<RankedShelter> _displayed = widget.ranked;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant ShelterSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.ranked, oldWidget.ranked)) {
      _displayed = widget.ranked;
      _refresh();
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_refresh);
    _ctrl.dispose();
    super.dispose();
  }

  void _refresh() {
    final query = _ctrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _displayed = widget.ranked;
        return;
      }
      _displayed = widget.ranked.where((r) {
        final s = r.shelter;
        return s.name.toLowerCase().contains(query) ||
            s.nameBn.contains(query) ||
            s.source.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.shelterSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _displayed.isEmpty
                  ? Center(
                      child: Text(l10n.shelterSearchEmpty))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      itemCount: _displayed.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = _displayed[i];
                        final s = r.shelter;
                        final bnName =
                            s.nameBn.isNotEmpty ? s.nameBn : s.name;
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: ShongjogTheme.ocean
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.shield,
                                color: ShongjogTheme.ocean, size: 22),
                          ),
                          title: Text(bnName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            '${r.km.toStringAsFixed(1)} ${l10n.shelterKm}'
                            '${s.capacity != null ? '  •  ${s.capacity} ${l10n.shelterPeopleUnit}' : ''}'
                            '  •  ${s.source}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => widget.onSelect(r),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
