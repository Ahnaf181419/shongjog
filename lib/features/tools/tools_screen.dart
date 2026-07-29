import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../l10n/app_localizations.dart';
import '../../app/theme.dart';

/// Dedicated Tools tab showing all AI-powered tools as a grid.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final tools = [
      _ToolEntry(
        icon: Icons.assignment_turned_in_outlined,
        label: l10n.homeToolPlan,
        route: AppRoutes.planner,
      ),
      _ToolEntry(
        icon: Icons.luggage_outlined,
        label: l10n.homeToolKit,
        route: AppRoutes.kit,
      ),
      _ToolEntry(
        icon: Icons.shield_outlined,
        label: l10n.homeToolRisk,
        route: AppRoutes.risk,
      ),
      _ToolEntry(
        icon: Icons.camera_alt_outlined,
        label: l10n.homeToolDamageScan,
        route: AppRoutes.damageScanner,
      ),
      _ToolEntry(
        icon: Icons.summarize_outlined,
        label: l10n.homeToolSummary,
        route: AppRoutes.situationSummary,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navTools),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            for (final tool in tools)
              _ToolTile(
                icon: tool.icon,
                label: tool.label,
                onTap: () => pushNamedSafe(context, tool.route),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolEntry {
  final IconData icon;
  final String label;
  final String route;
  const _ToolEntry({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: cs.primary, size: 32),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
