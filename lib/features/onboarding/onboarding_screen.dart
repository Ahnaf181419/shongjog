import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/locale_controller.dart';
import '../../l10n/app_localizations.dart';

/// First-run onboarding: welcome → permissions rationale → model download hint.
///
/// Shown only when `pref_has_onboarded` is false. The user can skip any step
/// but the rationale is shown so they understand why each permission matters.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  int _page = 0;

  static const _pages = 4;

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _next() async {
    await _saveName();
    if (_page < _pages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _goToHome();
    }
  }

  void _back() {
    if (_page > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _goToHome() async {
    await _saveName();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_has_onboarded', true);
    if (!mounted) return;
    widget.onComplete();
  }

  Future<void> _goToSettings() async {
    await _saveName();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_has_onboarded', true);
    if (!mounted) return;
    widget.onComplete();
    Navigator.pushNamed(context, AppRoutes.settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _welcomePage(),
                  _profilePage(),
                  _permissionsPage(),
                  _modelPage(),
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'bn',
                  label: Text(AppLocalizations.of(context).langBn),
                ),
                ButtonSegment(
                  value: 'en',
                  label: Text(AppLocalizations.of(context).langEn),
                ),
              ],
              selected: {localeController.languageCode},
              onSelectionChanged: (s) {
                final locale = switch (s.first) {
                  'en' => const Locale('en'),
                  _ => const Locale('bn'),
                };
                localeController.setLocale(locale);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            AppLocalizations.of(context).onboardingWelcome,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).onboardingDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ShongjogTheme.bodyFloor,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _profilePage() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline_rounded,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).onboardingYourName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).onboardingNameDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ShongjogTheme.bodyFloor,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).onboardingNameLabel,
              hintText: AppLocalizations.of(context).onboardingNameHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ShongjogTheme.radius),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _permissionsPage() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.admin_panel_settings_outlined,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).onboardingPermRequired,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          _permissionItem(
            icon: Icons.mic_rounded,
            title: AppLocalizations.of(context).onboardingMic,
            desc: AppLocalizations.of(context).onboardingMicDesc,
          ),
          _permissionItem(
            icon: Icons.location_on_rounded,
            title: AppLocalizations.of(context).onboardingGps,
            desc: AppLocalizations.of(context).onboardingGpsDesc,
          ),
          _permissionItem(
            icon: Icons.phone_rounded,
            title: AppLocalizations.of(context).onboardingPhone,
            desc: AppLocalizations.of(context).onboardingPhoneDesc,
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).onboardingPermHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _modelPage() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.downloading_rounded,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).onboardingModelTitle,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).onboardingModelDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ShongjogTheme.bodyFloor,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).onboardingModelHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _permissionItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: ShongjogTheme.iconBadge(context),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
                Text(desc,
                    style: TextStyle(
                        fontSize: 14,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    if (_page == _pages - 1) return _finalPageActions();
    return _walkingActions();
  }

  Widget _walkingActions() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pageDots(activeColor: cs.primary, inactiveColor: cs.outlineVariant),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: _goToHome,
                child: Text(AppLocalizations.of(context).skip),
              ),
              if (_page > 0) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: AppLocalizations.of(context).back,
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ],
              const Spacer(),
              IconButton.filledTonal(
                tooltip: AppLocalizations.of(context).next,
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward_rounded),
                iconSize: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _finalPageActions() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pageDots(activeColor: cs.primary, inactiveColor: cs.outlineVariant),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _goToSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: Text(AppLocalizations.of(context).settingsTitle),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _goToHome,
                  icon: const Icon(Icons.home_rounded),
                  label: Text(AppLocalizations.of(context).goToHome),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _back,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(AppLocalizations.of(context).back),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageDots({
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
