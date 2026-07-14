import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router.dart';
import '../../app/theme.dart';

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
  int _page = 0;

  static const _pages = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_has_onboarded', true);
    if (!mounted) return;
    widget.onComplete();
  }

  Future<void> _goToSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_has_onboarded', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.settings);
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: ShongjogTheme.ocean.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              size: 56,
              color: ShongjogTheme.ocean,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'সংযোগে স্বাগতম',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'বন্যা, ঘুর্ণিঝড় বা জরুরি পরিস্থিতিতে '
            'অফলাইনে সাহায্য পান। ভয়েস চ্যাট, '
            'দ্রুত নির্দেশিকা কার্ড, এবং আশ্রয়কেন্দ্রের '
            'তথ্য — সবকিছু আপনার হাতে।',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ShongjogTheme.bodyFloor,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionsPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.admin_panel_settings_outlined,
              size: 64, color: ShongjogTheme.ocean),
          const SizedBox(height: 24),
          const Text(
            'অনুমতি প্রয়োজন',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          _permissionItem(
            icon: Icons.mic_rounded,
            title: 'মাইক্রোফোন',
            desc: 'ভয়েসে প্রশ্ন করার জন্য',
          ),
          _permissionItem(
            icon: Icons.location_on_rounded,
            title: 'অবস্থান (GPS)',
            desc: 'নিকটস্থ আশ্রয়কেন্দ্র খুঁজতে',
          ),
          _permissionItem(
            icon: Icons.phone_rounded,
            title: 'ফোন ও SMS',
            desc: 'জরুরি কল ও SOS পাঠাতে',
          ),
          const SizedBox(height: 24),
          Text(
            'পরবর্তীতে সেটিংস থেকে যেকোনো সময় পরিবর্তন করতে পারবেন',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modelPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.downloading_rounded,
              size: 64, color: ShongjogTheme.ocean),
          const SizedBox(height: 24),
          const Text(
            'AI মডেল ডাউনলোড',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(
            'সম্পূর্ণ অফলাইন AI সহায়কের জন্য '
            'Gemma 4 E2B মডেল (~1.5 GB) ডাউনলোড করুন।\n\n'
            'ইন্টারনেট থাকলে ক্লাউড AI কাজ করবে। '
            'অফলাইনে ক্লাউড AI ছাড়াই দ্রুত কার্ড ও '
            'তথ্যকোষ থেকে উত্তর পাবেন।',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ShongjogTheme.bodyFloor,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'মডেল ডাউনলোড করতে সেটিংস → AI মডেল এ যান।',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
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
                        fontSize: 13,
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
                child: const Text('স্কিপ'),
              ),
              if (_page > 0) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'পূর্ববর্তী',
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ],
              const Spacer(),
              IconButton.filledTonal(
                tooltip: 'পরবর্তী',
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
                  label: const Text('সেটিংস'),
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
                  label: const Text('হোমে যান'),
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
              label: const Text('পূর্ববর্তী'),
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
