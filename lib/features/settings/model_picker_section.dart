import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/model_manager.dart';
import '../../core/device_capability.dart';
import '../../main.dart';

class ModelPickerSection extends StatefulWidget {
  const ModelPickerSection({super.key});

  @override
  State<ModelPickerSection> createState() => _ModelPickerSectionState();
}

class _ModelPickerSectionState extends State<ModelPickerSection> {
  List<ModelRecommendation>? _recommendations;
  DeviceTier? _tier;
  Map<ModelVariant, int> _storageUsage = {};
  int _totalStorage = 0;

  @override
  void initState() {
    super.initState();
    modelManager.addListener(_onModelChanged);
    _initData();
  }

  Future<void> _initData() async {
    final tier = await DeviceCapability.detectTier();
    final recs = await DeviceCapability.getRecommendations();
    if (mounted) {
      setState(() {
        _tier = tier;
        _recommendations = recs;
      });
      // Defer disk checks to avoid triggering setState during layout
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        int total = 0;
        final usage = <ModelVariant, int>{};
        for (final rec in recs) {
          await modelManager.markReadyIfOnDisk(rec.variant);
          try {
            final size = await modelManager.getVariantSizeBytes(rec.variant);
            usage[rec.variant] = size;
            total += size;
          } catch (_) {
            // getVariantSizeBytes uses dart:io File — unsupported on web
          }
        }
        if (mounted) {
          setState(() {
            _storageUsage = usage;
            _totalStorage = total;
          });
        }
      });
    }
  }

  void _onModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    modelManager.removeListener(_onModelChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recommendations == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final cs = Theme.of(context).colorScheme;

    // Convert tier to user-friendly string
    String ramText = '';
    String tierBadge = '';
    if (_tier == DeviceTier.low) {
      ramText = '৪GB বা কম';
      tierBadge = 'হালকা';
    }
    if (_tier == DeviceTier.mid) {
      ramText = '৬-৮GB';
      tierBadge = 'মাঝারি';
    }
    if (_tier == DeviceTier.high) {
      ramText = '১২GB+';
      tierBadge = 'শক্তিশালী';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flexible: the label is long Bangla text and the badge is
              // fixed-width, so on a narrow phone (or with a large system
              // text scale) an unconstrained Text overflows the row.
              Flexible(
                child: Text('আপনার RAM: $ramText', style: TextStyle(
                  fontFamily: ShongjogTheme.fontFamily,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                )),
              ),
              const SizedBox(width: 8),
              _TierBadge(tierBadge),
            ],
          ),
        ),
        if (_totalStorage > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'ডাউনলোড করা: ${DeviceCapability.formatBytesBn(_totalStorage)}',
              style: TextStyle(
                fontFamily: ShongjogTheme.fontFamily,
                color: cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
        // Unverified variants (broken URL / guessed size) are not offered.
        ..._recommendations!.where((r) => r.available).map((r) => _ModelCard(
          rec: r,
          storageUsage: _storageUsage[r.variant] ?? 0,
        )),
      ],
    );
  }
}

class _TierBadge extends StatelessWidget {
  final String label;
  const _TierBadge(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLight ? ShongjogTheme.ocean.withValues(alpha: 0.12) : ShongjogTheme.oceanBright.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: isLight ? ShongjogTheme.ocean : ShongjogTheme.oceanBright,
      )),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final ModelRecommendation rec;
  final int storageUsage;
  const _ModelCard({required this.rec, required this.storageUsage});

  /// The app-wide `filledButtonTheme` sets `minimumSize: Size.fromHeight(52)`
  /// — a full-width CTA default, where the width is `double.infinity`. A Row
  /// offers its non-flex children unbounded width, so inheriting that default
  /// inside this card's button row throws "BoxConstraints forces an infinite
  /// width" and silently kills the whole card's layout. In-row buttons must
  /// therefore declare a finite minimum.
  static final ButtonStyle _inRowButtonStyle = FilledButton.styleFrom(
    visualDensity: VisualDensity.compact,
    minimumSize: const Size(0, 40),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;
    final state = modelManager.getState(rec.variant);
    final progress = modelManager.getProgress(rec.variant);
    final isActive = modelManager.activeVariant == rec.variant;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: ShongjogTheme.cardDecoration(context).copyWith(
        border: Border.all(
          color: isActive ? cs.primary : ShongjogTheme.hairline(context),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive ? [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      // The radio reads as selectable, so the whole card must be tappable —
      // an already-downloaded variant is switched by tapping it, not only via
      // the button below.
      child: InkWell(
        onTap: state == ModelState.ready && !isActive
            ? () => modelManager.setActiveVariant(rec.variant)
            : null,
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isActive ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Wrap, not Row: on a 360dp phone (with the system text
                      // scale bumped) the label + badge overflow a Row.
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(rec.label, style: const TextStyle(
                            fontFamily: ShongjogTheme.fontFamily,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          )),
                          if (rec.recommended && !rec.advancedOnly)
                            _Badge('✅ প্রত্যাশিত', isLight ? ShongjogTheme.success : ShongjogTheme.successBright)
                          else if (rec.advancedOnly)
                            _Badge('⚠️ উন্নত', isLight ? ShongjogTheme.alert : ShongjogTheme.alertBright)
                          else
                            _Badge('⚠️ ভারী', isLight ? ShongjogTheme.alert : ShongjogTheme.alertBright)
                        ],
                      ),
                      Text(rec.sizeBn, style: TextStyle(
                        fontFamily: ShongjogTheme.fontFamily,
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      )),
                      Text(rec.description, style: TextStyle(
                        fontFamily: ShongjogTheme.fontFamily,
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      )),
                    ],
                  ),
                ),
              ],
            ),
            
            if (state == ModelState.downloading)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: progress ?? 0),
                    const SizedBox(height: 4),
                    Text('${((progress ?? 0) * 100).round()}%', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  if (state == ModelState.notDownloaded || state == ModelState.failed)
                    FilledButton.icon(
                      onPressed: () => _download(context),
                      icon: const Icon(Icons.download, size: 18),
                      label: Text(
                          state == ModelState.failed ? 'আবার চেষ্টা করুন' : 'ডাউনলোড'),
                      style: _inRowButtonStyle,
                    ),

                  if (state == ModelState.ready && !isActive)
                    FilledButton.icon(
                      onPressed: () => modelManager.setActiveVariant(rec.variant),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('সক্রিয় করুন'),
                      style: _inRowButtonStyle,
                    ),
                    
                  if (state == ModelState.ready && isActive)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
                      child: Text('মডেল সক্রিয় আছে', style: TextStyle(fontWeight: FontWeight.bold, color: ShongjogTheme.calmTeal)),
                    ),

                  if (storageUsage > 0) ...[
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        DeviceCapability.formatBytesBn(storageUsage),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],

                  if (state == ModelState.ready) ...[
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => _confirmDelete(context),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: cs.error,
                      ),
                      child: const Text('মুছুন'),
                    )
                  ]
                ],
              ),
            )
          ],
        ),
        ),
      ),
    );
  }

  /// Start the download in the background. The user can navigate away —
  /// progress is surfaced via [modelManager]'s ChangeNotifier on the Home
  /// AppBar chip. Completion / failure snackbars fire from the Home screen
  /// listener so they work even if this widget is long disposed.
  void _download(BuildContext context) {
    modelManager.ensureModel(variant: rec.variant).catchError((e) {
      debugPrint('Model download failed (${rec.variant.name}): $e');
    });
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('${rec.label} ডাউনলোড শুরু হয়েছে — পটভূমিতে চলবে।'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('মডেল মুছে ফেলবেন?'),
        content: Text('${rec.label} (${rec.sizeBn}) মুছে যাবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('মুছুন'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await modelManager.deleteVariant(rec.variant);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('মডেল মুছে ফেলা হয়েছে')),
        );
      }
    }
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: FontWeight.bold,
      )),
    );
  }
}
