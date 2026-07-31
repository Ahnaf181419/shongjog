import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/l10n/app_localizations.dart';
import 'package:shongjog/l10n/app_localizations_bn.dart';
import 'package:shongjog/l10n/app_localizations_en.dart';

/// The rotating home-screen tips were a `static const` list of Bangla
/// literals rendered under a *localized* heading, so an English-locale user
/// saw an English title above a Bangla paragraph — on the most-viewed card of
/// the most-viewed screen. These pin that both locales carry a real string.
void main() {
  final bn = AppLocalizationsBn();
  final en = AppLocalizationsEn();

  List<String> tips(AppLocalizations l) => [
        l.homeTip1, l.homeTip2, l.homeTip3, l.homeTip4, l.homeTip5,
        l.homeTip6, l.homeTip7, l.homeTip8, l.homeTip9, l.homeTip10,
        l.homeTip11, l.homeTip12, l.homeTip13, l.homeTip14, l.homeTip15,
        l.homeTip16, l.homeTip17, l.homeTip18, l.homeTip19,
      ];

  /// Bangla block: U+0980..U+09FF.
  bool hasBangla(String s) =>
      s.runes.any((r) => r >= 0x0980 && r <= 0x09FF);

  test('every tip exists in both locales', () {
    expect(tips(bn), hasLength(19));
    expect(tips(en), hasLength(19));
    for (final t in [...tips(bn), ...tips(en)]) {
      expect(t.trim(), isNotEmpty);
    }
  });

  test('the English tips contain no Bangla script', () {
    for (var i = 0; i < 19; i++) {
      expect(hasBangla(tips(en)[i]), isFalse,
          reason: 'homeTip${i + 1} leaks Bangla into the English locale');
    }
  });

  test('the Bangla tips are actually in Bangla', () {
    for (var i = 0; i < 19; i++) {
      expect(hasBangla(tips(bn)[i]), isTrue,
          reason: 'homeTip${i + 1} is not Bangla in the Bangla locale');
    }
  });

  test('the two locales are genuinely different strings', () {
    for (var i = 0; i < 19; i++) {
      expect(tips(en)[i], isNot(tips(bn)[i]));
    }
  });

  test('the model-info figures are localized too', () {
    expect(hasBangla(en.modelInfoParamsE2b), isFalse);
    expect(hasBangla(en.modelInfoRamE4b), isFalse);
    expect(hasBangla(bn.modelInfoParamsE2b), isTrue);
  });

  test('the situation-summary chrome is localized', () {
    expect(hasBangla(en.situationGenerate), isFalse);
    expect(hasBangla(en.situationRetry), isFalse);
    expect(hasBangla(en.situationDone), isFalse);
    expect(hasBangla(bn.situationGenerate), isTrue);
  });
}
