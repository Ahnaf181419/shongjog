import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In bn, this message translates to:
  /// **'Shongjog'**
  String get appTitle;

  /// No description provided for @splashTitle.
  ///
  /// In bn, this message translates to:
  /// **'সংযোগ'**
  String get splashTitle;

  /// No description provided for @pageNotFound.
  ///
  /// In bn, this message translates to:
  /// **'পাওয়া যায়নি'**
  String get pageNotFound;

  /// No description provided for @pageNotFoundDesc.
  ///
  /// In bn, this message translates to:
  /// **'এই পৃষ্ঠাটি পাওয়া যায়নি।'**
  String get pageNotFoundDesc;

  /// No description provided for @navHome.
  ///
  /// In bn, this message translates to:
  /// **'হোম'**
  String get navHome;

  /// No description provided for @navAi.
  ///
  /// In bn, this message translates to:
  /// **'এআই'**
  String get navAi;

  /// No description provided for @navTools.
  ///
  /// In bn, this message translates to:
  /// **'টুলস'**
  String get navTools;

  /// No description provided for @navCards.
  ///
  /// In bn, this message translates to:
  /// **'কার্ড'**
  String get navCards;

  /// No description provided for @navShelter.
  ///
  /// In bn, this message translates to:
  /// **'আশ্রয়'**
  String get navShelter;

  /// No description provided for @onboardingWelcome.
  ///
  /// In bn, this message translates to:
  /// **'সংযোগে স্বাগতম'**
  String get onboardingWelcome;

  /// No description provided for @onboardingDesc.
  ///
  /// In bn, this message translates to:
  /// **'বন্যা, ঘুর্ণিঝড় বা জরুরি পরিস্থিতিতে অফলাইনে সাহায্য পান। ভয়েস চ্যাট, দ্রুত নির্দেশিকা কার্ড, এবং আশ্রয়কেন্দ্রের তথ্য — সবকিছু আপনার হাতে।'**
  String get onboardingDesc;

  /// No description provided for @onboardingPermRequired.
  ///
  /// In bn, this message translates to:
  /// **'অনুমতি প্রয়োজন'**
  String get onboardingPermRequired;

  /// No description provided for @onboardingMic.
  ///
  /// In bn, this message translates to:
  /// **'মাইক্রোফোন'**
  String get onboardingMic;

  /// No description provided for @onboardingMicDesc.
  ///
  /// In bn, this message translates to:
  /// **'ভয়েসে প্রশ্ন করার জন্য'**
  String get onboardingMicDesc;

  /// No description provided for @onboardingGps.
  ///
  /// In bn, this message translates to:
  /// **'অবস্থান (GPS)'**
  String get onboardingGps;

  /// No description provided for @onboardingGpsDesc.
  ///
  /// In bn, this message translates to:
  /// **'নিকটস্থ আশ্রয়কেন্দ্র খুঁজতে'**
  String get onboardingGpsDesc;

  /// No description provided for @onboardingPhone.
  ///
  /// In bn, this message translates to:
  /// **'ফোন ও SMS'**
  String get onboardingPhone;

  /// No description provided for @onboardingPhoneDesc.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি কল ও SOS পাঠাতে'**
  String get onboardingPhoneDesc;

  /// No description provided for @onboardingPermHint.
  ///
  /// In bn, this message translates to:
  /// **'পরবর্তীতে সেটিংস থেকে যেকোনো সময় পরিবর্তন করতে পারবেন'**
  String get onboardingPermHint;

  /// No description provided for @onboardingModelTitle.
  ///
  /// In bn, this message translates to:
  /// **'AI মডেল ডাউনলোড'**
  String get onboardingModelTitle;

  /// No description provided for @onboardingModelDesc.
  ///
  /// In bn, this message translates to:
  /// **'সম্পূর্ণ অফলাইন AI সহায়কের জন্য Gemma 4 E2B মডেল (~1.5 GB) ডাউনলোড করুন।\n\nইন্টারনেট থাকলে ক্লাউড AI কাজ করবে। অফলাইনে ক্লাউড AI ছাড়াই দ্রুত কার্ড ও তথ্যকোষ থেকে উত্তর পাবেন।'**
  String get onboardingModelDesc;

  /// No description provided for @onboardingModelHint.
  ///
  /// In bn, this message translates to:
  /// **'মডেল ডাউনলোড করতে সেটিংস → AI মডেল এ যান।'**
  String get onboardingModelHint;

  /// No description provided for @skip.
  ///
  /// In bn, this message translates to:
  /// **'স্কিপ'**
  String get skip;

  /// No description provided for @back.
  ///
  /// In bn, this message translates to:
  /// **'পূর্ববর্তী'**
  String get back;

  /// No description provided for @next.
  ///
  /// In bn, this message translates to:
  /// **'পরবর্তী'**
  String get next;

  /// No description provided for @goToHome.
  ///
  /// In bn, this message translates to:
  /// **'হোমে যান'**
  String get goToHome;

  /// No description provided for @settingsTitle.
  ///
  /// In bn, this message translates to:
  /// **'সেটিংস'**
  String get settingsTitle;

  /// No description provided for @sectionAppearance.
  ///
  /// In bn, this message translates to:
  /// **'উপস্থিতি'**
  String get sectionAppearance;

  /// No description provided for @themeLabel.
  ///
  /// In bn, this message translates to:
  /// **'থিম'**
  String get themeLabel;

  /// No description provided for @themeDesc.
  ///
  /// In bn, this message translates to:
  /// **'লাইট, ডার্ক, বা সিস্টেম অনুসরণ'**
  String get themeDesc;

  /// No description provided for @themeLight.
  ///
  /// In bn, this message translates to:
  /// **'লাইট'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In bn, this message translates to:
  /// **'ডার্ক'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In bn, this message translates to:
  /// **'সিস্টেম'**
  String get themeSystem;

  /// No description provided for @sectionLanguage.
  ///
  /// In bn, this message translates to:
  /// **'ভাষা'**
  String get sectionLanguage;

  /// No description provided for @languageLabel.
  ///
  /// In bn, this message translates to:
  /// **'ভাষা'**
  String get languageLabel;

  /// No description provided for @languageDesc.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাপের ভাষা পরিবর্তন করুন'**
  String get languageDesc;

  /// No description provided for @langBn.
  ///
  /// In bn, this message translates to:
  /// **'বাংলা'**
  String get langBn;

  /// No description provided for @langEn.
  ///
  /// In bn, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @sectionVoice.
  ///
  /// In bn, this message translates to:
  /// **'ভয়েস'**
  String get sectionVoice;

  /// No description provided for @autoRead.
  ///
  /// In bn, this message translates to:
  /// **'স্বয়ংক্রিয় পঠন'**
  String get autoRead;

  /// No description provided for @autoReadDesc.
  ///
  /// In bn, this message translates to:
  /// **'AI উত্তর স্বয়ংক্রিয়ভাবে পড়ে শোনাবে'**
  String get autoReadDesc;

  /// No description provided for @voiceInput.
  ///
  /// In bn, this message translates to:
  /// **'ভয়েস ইনপুট'**
  String get voiceInput;

  /// No description provided for @voiceInputDesc.
  ///
  /// In bn, this message translates to:
  /// **'কথা বলে প্রশ্ন করুন'**
  String get voiceInputDesc;

  /// No description provided for @soundHint.
  ///
  /// In bn, this message translates to:
  /// **'শব্দ ইঙ্গিত'**
  String get soundHint;

  /// No description provided for @soundHintDesc.
  ///
  /// In bn, this message translates to:
  /// **'AI উত্তর প্রস্তুত হলে চিম বাজবে'**
  String get soundHintDesc;

  /// No description provided for @prepTips.
  ///
  /// In bn, this message translates to:
  /// **'প্রস্তুতি পরামর্শ'**
  String get prepTips;

  /// No description provided for @prepTipsDesc.
  ///
  /// In bn, this message translates to:
  /// **'চ্যাট ইতিহাস অনুযায়ী হোম স্ক্রিনে পরামর্শ কার্ড'**
  String get prepTipsDesc;

  /// Mesh media auto-save consent toggle
  ///
  /// In bn, this message translates to:
  /// **'মেশ মিডিয়া গ্যালারিতে সেভ করুন'**
  String get meshAutoSaveMedia;

  /// Mesh media auto-save consent toggle
  ///
  /// In bn, this message translates to:
  /// **'কাছের ব্যবহারকারীদের পাঠানো ছবি ও ভিডিও স্বয়ংক্রিয়ভাবে গ্যালারিতে জমা হবে'**
  String get meshAutoSaveMediaDesc;

  /// No description provided for @sectionEmergency.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি'**
  String get sectionEmergency;

  /// No description provided for @emergencyContacts.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি পরিচিতি'**
  String get emergencyContacts;

  /// No description provided for @emergencyContactsDesc.
  ///
  /// In bn, this message translates to:
  /// **'জাতীয় নম্বর ও নিজের পরিচিতি'**
  String get emergencyContactsDesc;

  /// No description provided for @sectionCampaign.
  ///
  /// In bn, this message translates to:
  /// **'অভিযান অনুরোধ'**
  String get sectionCampaign;

  /// No description provided for @campaignRequest.
  ///
  /// In bn, this message translates to:
  /// **'দান/উদ্ধার অভিযান অনুরোধ করুন'**
  String get campaignRequest;

  /// No description provided for @campaignRequestDesc.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাডমিন অনুমোদনে মানচিত্রে দেখাবে'**
  String get campaignRequestDesc;

  /// No description provided for @sectionAiModel.
  ///
  /// In bn, this message translates to:
  /// **'AI মডেল'**
  String get sectionAiModel;

  /// No description provided for @sectionDiagnostics.
  ///
  /// In bn, this message translates to:
  /// **'ডায়াগনস্টিকস'**
  String get sectionDiagnostics;

  /// No description provided for @kbVersion.
  ///
  /// In bn, this message translates to:
  /// **'তথ্যকোষ সংস্করণ'**
  String get kbVersion;

  /// No description provided for @offlineAiFailed.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন AI চালু হয়নি'**
  String get offlineAiFailed;

  /// No description provided for @offlineAiError.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন AI ত্রুটি'**
  String get offlineAiError;

  /// No description provided for @close.
  ///
  /// In bn, this message translates to:
  /// **'বন্ধ করুন'**
  String get close;

  /// No description provided for @sectionInfo.
  ///
  /// In bn, this message translates to:
  /// **'তথ্য'**
  String get sectionInfo;

  /// No description provided for @clearCache.
  ///
  /// In bn, this message translates to:
  /// **'ক্যাশ মুছুন'**
  String get clearCache;

  /// No description provided for @clearCacheDesc.
  ///
  /// In bn, this message translates to:
  /// **'চ্যাট ইতিহাস মুছে ফেলুন'**
  String get clearCacheDesc;

  /// No description provided for @aboutApp.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাপ সম্পর্কে'**
  String get aboutApp;

  /// No description provided for @aboutAppDesc.
  ///
  /// In bn, this message translates to:
  /// **'তথ্যসূত্র, লাইসেন্স, সংস্করণ'**
  String get aboutAppDesc;

  /// No description provided for @adminLogin.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাডমিন লগইন'**
  String get adminLogin;

  /// No description provided for @adminLoginDesc.
  ///
  /// In bn, this message translates to:
  /// **'বার্তা ব্রডকাস্ট এবং ব্যবস্থাপনা'**
  String get adminLoginDesc;

  /// No description provided for @clearCacheConfirmTitle.
  ///
  /// In bn, this message translates to:
  /// **'ক্যাশ মুছুন?'**
  String get clearCacheConfirmTitle;

  /// No description provided for @clearCacheConfirmDesc.
  ///
  /// In bn, this message translates to:
  /// **'সব চ্যাট ইতিহাস মুছে যাবে। এটি পূর্বাবস্থায় ফেরানো যাবে না।'**
  String get clearCacheConfirmDesc;

  /// No description provided for @cancel.
  ///
  /// In bn, this message translates to:
  /// **'বাতিল'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In bn, this message translates to:
  /// **'মুছুন'**
  String get delete;

  /// No description provided for @cacheCleared.
  ///
  /// In bn, this message translates to:
  /// **'ক্যাশ মুছে ফেলা হয়েছে'**
  String get cacheCleared;

  /// No description provided for @campaignDialogTitle.
  ///
  /// In bn, this message translates to:
  /// **'অভিযান অনুরোধ জমা দিন'**
  String get campaignDialogTitle;

  /// No description provided for @campaignTypeLabel.
  ///
  /// In bn, this message translates to:
  /// **'অভিযানের ধরন'**
  String get campaignTypeLabel;

  /// No description provided for @campaignTypeValidator.
  ///
  /// In bn, this message translates to:
  /// **'ধরন বেছে নিন'**
  String get campaignTypeValidator;

  /// No description provided for @campaignLocationSelected.
  ///
  /// In bn, this message translates to:
  /// **'অবস্থান নির্বাচিত'**
  String get campaignLocationSelected;

  /// No description provided for @campaignLocationPrompt.
  ///
  /// In bn, this message translates to:
  /// **'মানচিত্র থেকে অবস্থান নির্বাচন করুন'**
  String get campaignLocationPrompt;

  /// No description provided for @campaignLocationTap.
  ///
  /// In bn, this message translates to:
  /// **'ট্যাপ করে মানচিত্রে পিন দিন'**
  String get campaignLocationTap;

  /// No description provided for @campaignAddress.
  ///
  /// In bn, this message translates to:
  /// **'ঠিকানা/স্থান'**
  String get campaignAddress;

  /// No description provided for @campaignAddressHint.
  ///
  /// In bn, this message translates to:
  /// **'যেমন: ঢাকা মেডিকেল কলেজ হাসপাতাল'**
  String get campaignAddressHint;

  /// No description provided for @campaignAddressValidator.
  ///
  /// In bn, this message translates to:
  /// **'ঠিকানা লিখুন'**
  String get campaignAddressValidator;

  /// No description provided for @campaignLandmark.
  ///
  /// In bn, this message translates to:
  /// **'স্পষ্ট ঠিকানা/ল্যান্ডমার্ক'**
  String get campaignLandmark;

  /// No description provided for @campaignLandmarkHint.
  ///
  /// In bn, this message translates to:
  /// **'যেমন: মসজিদের পাশে, দোকান নম্বর ১২'**
  String get campaignLandmarkHint;

  /// No description provided for @campaignDescLabel.
  ///
  /// In bn, this message translates to:
  /// **'বিবরণ (ঐচ্ছিক)'**
  String get campaignDescLabel;

  /// No description provided for @campaignDescHint.
  ///
  /// In bn, this message translates to:
  /// **'অভিযানের লক্ষ্য, সময়, যোগাযোগ নম্বর ইত্যাদি'**
  String get campaignDescHint;

  /// No description provided for @campaignLocationRequired.
  ///
  /// In bn, this message translates to:
  /// **'মানচিত্র থেকে অবস্থান নির্বাচন করুন'**
  String get campaignLocationRequired;

  /// No description provided for @campaignSubmitted.
  ///
  /// In bn, this message translates to:
  /// **'অভিযান অনুরোধ জমা দেওয়া হয়েছে'**
  String get campaignSubmitted;

  /// No description provided for @campaignSubmit.
  ///
  /// In bn, this message translates to:
  /// **'জমা দিন'**
  String get campaignSubmit;

  /// No description provided for @profileSet.
  ///
  /// In bn, this message translates to:
  /// **'প্রোফাইল সেট করুন'**
  String get profileSet;

  /// No description provided for @emergencyCall.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি কল'**
  String get emergencyCall;

  /// No description provided for @notificationsTooltip.
  ///
  /// In bn, this message translates to:
  /// **'বিজ্ঞপ্তি'**
  String get notificationsTooltip;

  /// No description provided for @statusOnline.
  ///
  /// In bn, this message translates to:
  /// **'অনলাইনে চলছে'**
  String get statusOnline;

  /// No description provided for @statusOffline.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইনে চলে'**
  String get statusOffline;

  /// No description provided for @dataReady.
  ///
  /// In bn, this message translates to:
  /// **'তথ্য প্রস্তুত'**
  String get dataReady;

  /// No description provided for @emergencyCards.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি কার্ড'**
  String get emergencyCards;

  /// No description provided for @emergencyCardsCount.
  ///
  /// In bn, this message translates to:
  /// **'{count}টি দ্রুত নির্দেশিকা'**
  String emergencyCardsCount(Object count);

  /// No description provided for @nearbyShelter.
  ///
  /// In bn, this message translates to:
  /// **'নিকটস্থ আশ্রয়'**
  String get nearbyShelter;

  /// No description provided for @shelterFromGps.
  ///
  /// In bn, this message translates to:
  /// **'GPS থেকে শেল্টার'**
  String get shelterFromGps;

  /// No description provided for @emergencyNumbers.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি নম্বর'**
  String get emergencyNumbers;

  /// No description provided for @emergencyDirectoryDesc.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন ডিরেক্টরি — জাতীয় ও বিভাগীয় হটলাইন'**
  String get emergencyDirectoryDesc;

  /// No description provided for @imSafe.
  ///
  /// In bn, this message translates to:
  /// **'আমার অবস্থা জানান'**
  String get imSafe;

  /// No description provided for @imSafeDesc.
  ///
  /// In bn, this message translates to:
  /// **'নিরাপদ বা বিপদে'**
  String get imSafeDesc;

  /// No description provided for @triageWizard.
  ///
  /// In bn, this message translates to:
  /// **'ট্রায়াজ উইজার্ড'**
  String get triageWizard;

  /// No description provided for @firstAid.
  ///
  /// In bn, this message translates to:
  /// **'প্রাথমিক চিকিৎসা'**
  String get firstAid;

  /// No description provided for @todaysTip.
  ///
  /// In bn, this message translates to:
  /// **'আজকের পরামর্শ'**
  String get todaysTip;

  /// Rotating home-screen preparedness tip #1
  ///
  /// In bn, this message translates to:
  /// **'বন্যা মৌসুমে পানি অন্তত ১ মিনিট ফুটিয়ে পান। পানিবাহিত রোগ প্রতিরোধে ORS মজুত রাখুন।'**
  String get homeTip1;

  /// Rotating home-screen preparedness tip #2
  ///
  /// In bn, this message translates to:
  /// **'ঝড় আসার আগে জানালা-দরজা বন্ধ করুন। ভাঙা কাচের ক্ষতি থেকে বাঁচতে মোটা কাপড় দিয়ে ঢাকুন।'**
  String get homeTip2;

  /// Rotating home-screen preparedness tip #3
  ///
  /// In bn, this message translates to:
  /// **'ভূমিকম্পে টেবিলের নিচে ঢুকুন, দেয়াল থেকে দূরে সরে যান। লিফট ব্যবহার করবেন না।'**
  String get homeTip3;

  /// Rotating home-screen preparedness tip #4
  ///
  /// In bn, this message translates to:
  /// **'অগ্নিকাণ্ডে ধোঁয়া থেকে বাঁচতে মাটি পর্যন্ত নিচু হয়ে যান। ধোঁয়া সবসময় উপরে ওঠে।'**
  String get homeTip4;

  /// Rotating home-screen preparedness tip #5
  ///
  /// In bn, this message translates to:
  /// **'গ্রীষ্মে প্রতি ৩০ মিনিটে পানি পান করুন। হিটস্ট্রোক থেকে বাঁচতে হালকা রঙের কাপড় পরুন।'**
  String get homeTip5;

  /// Rotating home-screen preparedness tip #6
  ///
  /// In bn, this message translates to:
  /// **'ডায়রিয়ায় ORS ঘরে তৈরি করুন: ১ লিটার ফুটিয়ে ঠান্ডা করা পানিতে ১ চা চামচ চিনি + আধা চা চামচ লবণ মেশান।'**
  String get homeTip6;

  /// Rotating home-screen preparedness tip #7
  ///
  /// In bn, this message translates to:
  /// **'সাপে কামড়ালে কামড়ানো জায়গাটি হৃদপিণ্ডের নিচে রাখুন। কাঁচি বা ছুরি দিয়ে কাটবেন না।'**
  String get homeTip7;

  /// Rotating home-screen preparedness tip #8
  ///
  /// In bn, this message translates to:
  /// **'বন্যায় পানিতে নামার আগে বৈদ্যুতিক সরঞ্জামের সংযোগ বিচ্ছিন্ন করুন। গ্যাস সিলিন্ডার ও লাইটার দূরে সরিয়ে রাখুন।'**
  String get homeTip8;

  /// Rotating home-screen preparedness tip #9
  ///
  /// In bn, this message translates to:
  /// **'মাঠে বা খোলা জায়গায় ভূমিকম্প অনুভব করলে খোলা জায়গাতেই থাকুন, গাছ বা বিদ্যুতের খুঁটির পাশে যাবেন না।'**
  String get homeTip9;

  /// Rotating home-screen preparedness tip #10
  ///
  /// In bn, this message translates to:
  /// **'ঘরের ভেতরে আগুন লাগলে সারিবদ্ধভাবে শান্তভাবে বাইরে যান। ধোঁয়া বেশি হলে ভেজা কাপড় মুখে চেপে ধরুন।'**
  String get homeTip10;

  /// Rotating home-screen preparedness tip #11
  ///
  /// In bn, this message translates to:
  /// **'গরমে শিশুদের দ্রুত পানিশূন্যতা হতে পারে। সবার আগে তাদের পানি খাইয়ে ছায়ায় বসান।'**
  String get homeTip11;

  /// Rotating home-screen preparedness tip #12
  ///
  /// In bn, this message translates to:
  /// **'তীব্র ঝড়ে বাড়ির বাইরে থাকলে নিচু জায়গায় মাটিতে শুয়ে পড়ুন। গাছের পাশে দাঁড়াবেন না।'**
  String get homeTip12;

  /// Rotating home-screen preparedness tip #13
  ///
  /// In bn, this message translates to:
  /// **'প্রতি পরিবারে অন্তত ৩ দিনের খাবার পানি ও শুকনো খাবার মজুত রাখুন। পরিষ্কারের জন্য আলাদা পানি রাখুন।'**
  String get homeTip13;

  /// Rotating home-screen preparedness tip #14
  ///
  /// In bn, this message translates to:
  /// **'বাড়িতে প্রাথমিক চিকিৎসা বাক্স রাখুন: ব্যান্ডেজ, অ্যান্টিসেপটিক, প্যারাসিটামল, ORS প্যাকেট।'**
  String get homeTip14;

  /// Rotating home-screen preparedness tip #15
  ///
  /// In bn, this message translates to:
  /// **'বন্যার পর পুকুরের পানি সরাসরি ব্যবহার করবেন না। ফুটিয়ে বা ক্লোরিন ট্যাবলেট দিয়ে বিশুদ্ধ করুন।'**
  String get homeTip15;

  /// Rotating home-screen preparedness tip #16
  ///
  /// In bn, this message translates to:
  /// **'ভূমিকম্পের পর ভবনের ক্ষতিগ্রস্ত অংশ পরীক্ষা না করে ভেতরে ঢুকবেন না।'**
  String get homeTip16;

  /// Rotating home-screen preparedness tip #17
  ///
  /// In bn, this message translates to:
  /// **'জ্বর হলে শরীর ভেজা কাপড় দিয়ে মুছে দিন এবং প্রচুর পানি পান করুন। ৪০° সেলসিয়াসের বেশি হলে হাসপাতালে যান।'**
  String get homeTip17;

  /// Rotating home-screen preparedness tip #18
  ///
  /// In bn, this message translates to:
  /// **'সামুদ্রিক ঝড়ের সময় সমুদ্র থেকে দূরে থাকুন। ঢেউ অস্বাভাবিক মনে হলে তাৎক্ষণিক উঁচু জায়গায় যান।'**
  String get homeTip18;

  /// Rotating home-screen preparedness tip #19
  ///
  /// In bn, this message translates to:
  /// **'বিদ্যুতের বিপদে হাত ভেজা অবস্থায় সুইচে হাত দেবেন না। রাবারের জুতা পরে থাকুন।'**
  String get homeTip19;

  /// No description provided for @offlineMessage.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন মেসেজ'**
  String get offlineMessage;

  /// No description provided for @offlineMessageDesc.
  ///
  /// In bn, this message translates to:
  /// **'Wi-Fi চালু রেখে কাছের মানুষদের সাথে কথা বলুন'**
  String get offlineMessageDesc;

  /// No description provided for @modelDownloadProgress.
  ///
  /// In bn, this message translates to:
  /// **'মডেল ডাউনলোড {progress}'**
  String modelDownloadProgress(Object progress);

  /// No description provided for @modelDownloading.
  ///
  /// In bn, this message translates to:
  /// **'পটভূমিতে চলছে'**
  String get modelDownloading;

  /// No description provided for @modelReady.
  ///
  /// In bn, this message translates to:
  /// **'মডেল প্রস্তুত — এখন অফলাইন এআই চালু।'**
  String get modelReady;

  /// No description provided for @downloadFailed.
  ///
  /// In bn, this message translates to:
  /// **'ডাউনলোড ব্যর্থ — সেটিংস থেকে আবার চেষ্টা করুন।'**
  String get downloadFailed;

  /// No description provided for @aboutTitle.
  ///
  /// In bn, this message translates to:
  /// **'তথ্যসূত্র'**
  String get aboutTitle;

  /// No description provided for @aboutBrand.
  ///
  /// In bn, this message translates to:
  /// **'সংযোগ'**
  String get aboutBrand;

  /// No description provided for @aboutTagline.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন জরুরি সহায়তা — বাংলায়'**
  String get aboutTagline;

  /// No description provided for @aboutDescription.
  ///
  /// In bn, this message translates to:
  /// **'শঙ্গ্যোগ-এর সমস্ত নির্দেশিকা নিচের প্রতিষ্ঠিত উৎস থেকে সংগৃহীত ও যাচাইকৃত। অ্যাপ কখনো রোগ নির্ণয় করে না বা ওষুধ দেয় না — শুধু সাধারণ সহায়তা দেয়।'**
  String get aboutDescription;

  /// No description provided for @aboutEmergencyNote.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি হলে সর্বদা ৯৯৯ নম্বরে কল করুন বা নিকটস্থ হাসপাতালে যান।'**
  String get aboutEmergencyNote;

  /// No description provided for @contactsTitle.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি পরিচিতি'**
  String get contactsTitle;

  /// No description provided for @panicHeroTitle.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি কল করুন (৯৯৯)'**
  String get panicHeroTitle;

  /// No description provided for @panicHeroSubtitle.
  ///
  /// In bn, this message translates to:
  /// **'স্লাইড করে নিশ্চিত করুন'**
  String get panicHeroSubtitle;

  /// No description provided for @nationalNumbers.
  ///
  /// In bn, this message translates to:
  /// **'জাতীয় জরুরি নম্বর'**
  String get nationalNumbers;

  /// No description provided for @myContacts.
  ///
  /// In bn, this message translates to:
  /// **'আমার পরিচিতি'**
  String get myContacts;

  /// No description provided for @addCustomContact.
  ///
  /// In bn, this message translates to:
  /// **'নিজের জরুরি পরিচিতি যোগ করুন'**
  String get addCustomContact;

  /// No description provided for @addContact.
  ///
  /// In bn, this message translates to:
  /// **'যোগ করুন'**
  String get addContact;

  /// No description provided for @nameAndNumberRequired.
  ///
  /// In bn, this message translates to:
  /// **'নাম ও নম্বর দিন'**
  String get nameAndNumberRequired;

  /// No description provided for @newContact.
  ///
  /// In bn, this message translates to:
  /// **'নতুন পরিচিতি'**
  String get newContact;

  /// No description provided for @nameLabel.
  ///
  /// In bn, this message translates to:
  /// **'নাম'**
  String get nameLabel;

  /// No description provided for @nameHint.
  ///
  /// In bn, this message translates to:
  /// **'যেমন: ডাক্তার সাহেব'**
  String get nameHint;

  /// No description provided for @phoneLabel.
  ///
  /// In bn, this message translates to:
  /// **'ফোন নম্বর'**
  String get phoneLabel;

  /// No description provided for @phoneHint.
  ///
  /// In bn, this message translates to:
  /// **'০১XXXXXXXXX'**
  String get phoneHint;

  /// No description provided for @phonePrefix.
  ///
  /// In bn, this message translates to:
  /// **'+৮৮ '**
  String get phonePrefix;

  /// No description provided for @categoryLabel.
  ///
  /// In bn, this message translates to:
  /// **'শ্রেণি'**
  String get categoryLabel;

  /// No description provided for @save.
  ///
  /// In bn, this message translates to:
  /// **'সংরক্ষণ করুন'**
  String get save;

  /// No description provided for @notificationsTitle.
  ///
  /// In bn, this message translates to:
  /// **'বিজ্ঞপ্তি'**
  String get notificationsTitle;

  /// No description provided for @noNewMessages.
  ///
  /// In bn, this message translates to:
  /// **'কোন নতুন বার্তা নেই'**
  String get noNewMessages;

  /// No description provided for @justNow.
  ///
  /// In bn, this message translates to:
  /// **'এইমাত্র'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In bn, this message translates to:
  /// **'{count} মিনিট আগে'**
  String minutesAgo(Object count);

  /// No description provided for @hoursAgo.
  ///
  /// In bn, this message translates to:
  /// **'{count} ঘণ্টা আগে'**
  String hoursAgo(Object count);

  /// No description provided for @allDivisions.
  ///
  /// In bn, this message translates to:
  /// **'সব'**
  String get allDivisions;

  /// No description provided for @noNumbersInDivision.
  ///
  /// In bn, this message translates to:
  /// **'এই বিভাগে কোনো নম্বর পাওয়া যায়নি'**
  String get noNumbersInDivision;

  /// No description provided for @callTooltip.
  ///
  /// In bn, this message translates to:
  /// **'কল করুন'**
  String get callTooltip;

  /// No description provided for @safeBeaconTitle.
  ///
  /// In bn, this message translates to:
  /// **'আমি নিরাপদ'**
  String get safeBeaconTitle;

  /// No description provided for @safeBeaconDesc.
  ///
  /// In bn, this message translates to:
  /// **'আপনার পরিবার ও সংযুক্ত মানুষদের জানান আপনি ভালো আছেন'**
  String get safeBeaconDesc;

  /// No description provided for @safeBeaconButton.
  ///
  /// In bn, this message translates to:
  /// **'আমি নিরাপদ আছি'**
  String get safeBeaconButton;

  /// No description provided for @lastSent.
  ///
  /// In bn, this message translates to:
  /// **'শেষ পাঠানো: {count}টি'**
  String lastSent(Object count);

  /// No description provided for @pendingWait.
  ///
  /// In bn, this message translates to:
  /// **'{count}টি অপেক্ষমান — সংযোগ ফিরলে পাঠানো হবে'**
  String pendingWait(Object count);

  /// No description provided for @beaconSentPending.
  ///
  /// In bn, this message translates to:
  /// **'বীকন পাঠানো হয়েছে। {count}টি অপেক্ষমান।'**
  String beaconSentPending(Object count);

  /// No description provided for @smsSent.
  ///
  /// In bn, this message translates to:
  /// **'{count}টি এসএমএস পাঠানো হয়েছে।'**
  String smsSent(Object count);

  /// No description provided for @willNotifyOnReconnect.
  ///
  /// In bn, this message translates to:
  /// **'{count}জনকে জানানো হবে সংযোগ ফিরলে।'**
  String willNotifyOnReconnect(Object count);

  /// No description provided for @chatTitle.
  ///
  /// In bn, this message translates to:
  /// **'AI সহায়ক'**
  String get chatTitle;

  /// No description provided for @chatStatusCorpus.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন (তথ্যকোষ)'**
  String get chatStatusCorpus;

  /// No description provided for @chatStatusCloud.
  ///
  /// In bn, this message translates to:
  /// **'ক্লাউড এআই (Gemma 4)'**
  String get chatStatusCloud;

  /// No description provided for @chatStatusLocal.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন এআই (Gemma 4)'**
  String get chatStatusLocal;

  /// No description provided for @chatEmergencyCall.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি কল'**
  String get chatEmergencyCall;

  /// No description provided for @chatLoading.
  ///
  /// In bn, this message translates to:
  /// **'তথ্য প্রস্তুত হচ্ছে...'**
  String get chatLoading;

  /// No description provided for @chatError.
  ///
  /// In bn, this message translates to:
  /// **'ত্রুটি হয়েছে। অনুগ্রহ করে ৯৯৯ এ কল করুন।'**
  String get chatError;

  /// No description provided for @chatThinking.
  ///
  /// In bn, this message translates to:
  /// **'ভাবছি...'**
  String get chatThinking;

  /// No description provided for @chatListening.
  ///
  /// In bn, this message translates to:
  /// **'শুনছি...'**
  String get chatListening;

  /// No description provided for @chatEmptyPrompt.
  ///
  /// In bn, this message translates to:
  /// **'আপনার জরুরি প্রশ্ন বলুন বা লিখুন'**
  String get chatEmptyPrompt;

  /// No description provided for @chatRetry.
  ///
  /// In bn, this message translates to:
  /// **'আবার চেষ্টা করুন'**
  String get chatRetry;

  /// No description provided for @chatCall999.
  ///
  /// In bn, this message translates to:
  /// **'৯৯৯ কল'**
  String get chatCall999;

  /// No description provided for @chatQuickCards.
  ///
  /// In bn, this message translates to:
  /// **'দ্রুত নির্দেশিকা কার্ড দেখুন'**
  String get chatQuickCards;

  /// No description provided for @chatVoiceInputDisabled.
  ///
  /// In bn, this message translates to:
  /// **'সেটিংসে ভয়েস ইনপুট চালু করুন'**
  String get chatVoiceInputDisabled;

  /// No description provided for @chatTryAgain.
  ///
  /// In bn, this message translates to:
  /// **'আবার চেষ্টা করুন'**
  String get chatTryAgain;

  /// No description provided for @chatSttNoBangla.
  ///
  /// In bn, this message translates to:
  /// **'এই ফোনে বাংলা ভয়েস প্যাক নেই। Google অ্যাপ → সেটিংস → ভয়েস থেকে বাংলা যোগ করুন, অথবা টাইপ করে পাঠান।'**
  String get chatSttNoBangla;

  /// No description provided for @chatSttNetwork.
  ///
  /// In bn, this message translates to:
  /// **'ভয়েস শনাক্তকরণের জন্য ইন্টারনেট দরকার। টাইপ করে পাঠান।'**
  String get chatSttNetwork;

  /// No description provided for @chatSttNoSpeech.
  ///
  /// In bn, this message translates to:
  /// **'কিছু শোনা যায়নি। আবার চেষ্টা করুন।'**
  String get chatSttNoSpeech;

  /// No description provided for @chatSttUnavailable.
  ///
  /// In bn, this message translates to:
  /// **'এই ফোনে ভয়েস শনাক্তকরণ নেই। টাইপ করে পাঠান।'**
  String get chatSttUnavailable;

  /// No description provided for @chatMicPermission.
  ///
  /// In bn, this message translates to:
  /// **'মাইক্রোফোন অনুমতি নেই। সেটিংসে যেতে চাপুন।'**
  String get chatMicPermission;

  /// No description provided for @meshTitle.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন যোগাযোগ'**
  String get meshTitle;

  /// No description provided for @meshDeviceCount.
  ///
  /// In bn, this message translates to:
  /// **'{count} ডিভাইস'**
  String meshDeviceCount(Object count);

  /// No description provided for @meshConnecting.
  ///
  /// In bn, this message translates to:
  /// **'Wi-Fi সংযোগ চালু হচ্ছে...'**
  String get meshConnecting;

  /// No description provided for @meshSearching.
  ///
  /// In bn, this message translates to:
  /// **'কাছের ডিভাইস খোঁজা হচ্ছে...\nWi-Fi চালু রাখুন এবং Shongjog\nব্যবহারকারী কাছে থাকলে এখানে দেখা যাবে।'**
  String get meshSearching;

  /// No description provided for @meshWifiOff.
  ///
  /// In bn, this message translates to:
  /// **'Wi-Fi বন্ধ আছে — Wi-Fi চালু করে আবার চেষ্টা করুন'**
  String get meshWifiOff;

  /// No description provided for @meshPermissions.
  ///
  /// In bn, this message translates to:
  /// **'Wi-Fi ও অনুমতি প্রয়োজন — সেটিংসে অনুমতি দিন'**
  String get meshPermissions;

  /// No description provided for @meshStartFailed.
  ///
  /// In bn, this message translates to:
  /// **'মেশ সংযোগ শুরু করা যায়নি — Wi-Fi চালু আছে কিনা দেখুন'**
  String get meshStartFailed;

  /// No description provided for @meshRecordingFailed.
  ///
  /// In bn, this message translates to:
  /// **'রেকর্ডিং শুরু করা যায়নি — মাইক্রোফোন অনুমতি দিন'**
  String get meshRecordingFailed;

  /// No description provided for @meshBroadcastAll.
  ///
  /// In bn, this message translates to:
  /// **'সবাইকে পাঠানো হবে'**
  String get meshBroadcastAll;

  /// No description provided for @meshHint.
  ///
  /// In bn, this message translates to:
  /// **'মেসেজ লিখুন...'**
  String get meshHint;

  /// No description provided for @meshNoDevice.
  ///
  /// In bn, this message translates to:
  /// **'কোনো ডিভাইস সংযুক্ত নেই — মেসেজ পাঠানো যায়নি'**
  String get meshNoDevice;

  /// No description provided for @meshConnected.
  ///
  /// In bn, this message translates to:
  /// **'সংযুক্ত'**
  String get meshConnected;

  /// No description provided for @meshReconnecting.
  ///
  /// In bn, this message translates to:
  /// **'পুনঃসংযোগ হচ্ছে...'**
  String get meshReconnecting;

  /// No description provided for @meshDisconnected.
  ///
  /// In bn, this message translates to:
  /// **'বিচ্ছিন্ন'**
  String get meshDisconnected;

  /// No description provided for @weatherNoInternet.
  ///
  /// In bn, this message translates to:
  /// **'ইন্টারনেট সংযোগ নেই'**
  String get weatherNoInternet;

  /// No description provided for @weatherNoLocation.
  ///
  /// In bn, this message translates to:
  /// **'অবস্থান নেই — ডিফল্ট ঢাকা'**
  String get weatherNoLocation;

  /// No description provided for @weatherFetchError.
  ///
  /// In bn, this message translates to:
  /// **'আবহাওয়া সার্ভার থেকে তথ্য পাওয়া যায়নি'**
  String get weatherFetchError;

  /// No description provided for @weatherTodayLabel.
  ///
  /// In bn, this message translates to:
  /// **'আবহাওয়া · আজ · {condition}'**
  String weatherTodayLabel(Object condition);

  /// No description provided for @weatherTapToView.
  ///
  /// In bn, this message translates to:
  /// **'আবহাওয়া দেখতে চাপুন'**
  String get weatherTapToView;

  /// No description provided for @weatherLoading.
  ///
  /// In bn, this message translates to:
  /// **'আবহাওয়া — লোড হচ্ছে'**
  String get weatherLoading;

  /// No description provided for @weatherFallbackLabel.
  ///
  /// In bn, this message translates to:
  /// **'📍 ঢাকা (ডিফল্ট)'**
  String get weatherFallbackLabel;

  /// No description provided for @weatherLocationRetry.
  ///
  /// In bn, this message translates to:
  /// **'অবস্থান আবার চেষ্টা করুন'**
  String get weatherLocationRetry;

  /// No description provided for @meshConnectionRequest.
  ///
  /// In bn, this message translates to:
  /// **'নতুন সংযোগের অনুরোধ'**
  String get meshConnectionRequest;

  /// No description provided for @meshWantsToConnect.
  ///
  /// In bn, this message translates to:
  /// **'{name} আপনার সাথে কানেক্ট হতে চাচ্ছে।'**
  String meshWantsToConnect(String name);

  /// No description provided for @meshReject.
  ///
  /// In bn, this message translates to:
  /// **'প্রত্যাখ্যান'**
  String get meshReject;

  /// No description provided for @meshAccept.
  ///
  /// In bn, this message translates to:
  /// **'গ্রহণ করুন'**
  String get meshAccept;

  /// No description provided for @airQualityTitle.
  ///
  /// In bn, this message translates to:
  /// **'বায়ুর গুণমান'**
  String get airQualityTitle;

  /// No description provided for @fetchingData.
  ///
  /// In bn, this message translates to:
  /// **'তথ্য আনা হচ্ছে…'**
  String get fetchingData;

  /// No description provided for @failedToFetchTryAgain.
  ///
  /// In bn, this message translates to:
  /// **'তথ্য আনা যায়নি। আবার চেষ্টা করুন।'**
  String get failedToFetchTryAgain;

  /// No description provided for @airGood.
  ///
  /// In bn, this message translates to:
  /// **'ভালো'**
  String get airGood;

  /// No description provided for @airModerate.
  ///
  /// In bn, this message translates to:
  /// **'মাঝারি'**
  String get airModerate;

  /// No description provided for @airUnhealthySensitive.
  ///
  /// In bn, this message translates to:
  /// **'সংবেদনশীলদের জন্য ক্ষতিকর'**
  String get airUnhealthySensitive;

  /// No description provided for @airUnhealthy.
  ///
  /// In bn, this message translates to:
  /// **'ক্ষতিকর'**
  String get airUnhealthy;

  /// No description provided for @airVeryUnhealthy.
  ///
  /// In bn, this message translates to:
  /// **'অত্যন্ত ক্ষতিকর'**
  String get airVeryUnhealthy;

  /// No description provided for @marineTitle.
  ///
  /// In bn, this message translates to:
  /// **'সমুদ্রের উত্তালতা'**
  String get marineTitle;

  /// No description provided for @maxWave.
  ///
  /// In bn, this message translates to:
  /// **'সর্বোচ্চ তরঙ্গ'**
  String get maxWave;

  /// No description provided for @meter.
  ///
  /// In bn, this message translates to:
  /// **'মিটার'**
  String get meter;

  /// No description provided for @meterShort.
  ///
  /// In bn, this message translates to:
  /// **'মি'**
  String get meterShort;

  /// No description provided for @waveCalm.
  ///
  /// In bn, this message translates to:
  /// **'শান্ত'**
  String get waveCalm;

  /// No description provided for @waveModerate.
  ///
  /// In bn, this message translates to:
  /// **'মাঝারি'**
  String get waveModerate;

  /// No description provided for @waveRough.
  ///
  /// In bn, this message translates to:
  /// **'অস্থির'**
  String get waveRough;

  /// No description provided for @waveVeryRough.
  ///
  /// In bn, this message translates to:
  /// **'অত্যন্ত অস্থির'**
  String get waveVeryRough;

  /// No description provided for @locCoxsBazar.
  ///
  /// In bn, this message translates to:
  /// **'কক্সবাজার'**
  String get locCoxsBazar;

  /// No description provided for @locChattogram.
  ///
  /// In bn, this message translates to:
  /// **'চট্টগ্রাম'**
  String get locChattogram;

  /// No description provided for @locBhola.
  ///
  /// In bn, this message translates to:
  /// **'ভোলা'**
  String get locBhola;

  /// No description provided for @locPatuakhali.
  ///
  /// In bn, this message translates to:
  /// **'পটুয়াখালী'**
  String get locPatuakhali;

  /// No description provided for @locSundarbans.
  ///
  /// In bn, this message translates to:
  /// **'সুন্দরবন'**
  String get locSundarbans;

  /// No description provided for @locTeknaf.
  ///
  /// In bn, this message translates to:
  /// **'টেকনাফ'**
  String get locTeknaf;

  /// No description provided for @dayMon.
  ///
  /// In bn, this message translates to:
  /// **'সোম'**
  String get dayMon;

  /// No description provided for @dayTue.
  ///
  /// In bn, this message translates to:
  /// **'মঙ্গল'**
  String get dayTue;

  /// No description provided for @dayWed.
  ///
  /// In bn, this message translates to:
  /// **'বুধ'**
  String get dayWed;

  /// No description provided for @dayThu.
  ///
  /// In bn, this message translates to:
  /// **'বৃহ'**
  String get dayThu;

  /// No description provided for @dayFri.
  ///
  /// In bn, this message translates to:
  /// **'শুক্র'**
  String get dayFri;

  /// No description provided for @daySat.
  ///
  /// In bn, this message translates to:
  /// **'শনি'**
  String get daySat;

  /// No description provided for @daySun.
  ///
  /// In bn, this message translates to:
  /// **'রবি'**
  String get daySun;

  /// No description provided for @splashTagline1.
  ///
  /// In bn, this message translates to:
  /// **'সঙ্গী — Food · Rescue · Community'**
  String get splashTagline1;

  /// No description provided for @splashTagline2.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি সঙ্গী'**
  String get splashTagline2;

  /// No description provided for @meshIncomingCall.
  ///
  /// In bn, this message translates to:
  /// **'ইনকামিং কল...'**
  String get meshIncomingCall;

  /// No description provided for @meshCalling.
  ///
  /// In bn, this message translates to:
  /// **'কল করা হচ্ছে...'**
  String get meshCalling;

  /// No description provided for @meshRejectCall.
  ///
  /// In bn, this message translates to:
  /// **'প্রত্যাখ্যান'**
  String get meshRejectCall;

  /// No description provided for @meshAcceptCall.
  ///
  /// In bn, this message translates to:
  /// **'গ্রহণ'**
  String get meshAcceptCall;

  /// No description provided for @meshMute.
  ///
  /// In bn, this message translates to:
  /// **'মিউট'**
  String get meshMute;

  /// No description provided for @meshMuted.
  ///
  /// In bn, this message translates to:
  /// **'মিউটেড'**
  String get meshMuted;

  /// No description provided for @meshEndCall.
  ///
  /// In bn, this message translates to:
  /// **'শেষ করুন'**
  String get meshEndCall;

  /// No description provided for @meshSpeaker.
  ///
  /// In bn, this message translates to:
  /// **'স্পিকার'**
  String get meshSpeaker;

  /// No description provided for @meshEarpiece.
  ///
  /// In bn, this message translates to:
  /// **'ইয়ারপিস'**
  String get meshEarpiece;

  /// No description provided for @triageTitle.
  ///
  /// In bn, this message translates to:
  /// **'ট্রায়াজ উইজার্ড'**
  String get triageTitle;

  /// No description provided for @triageRestart.
  ///
  /// In bn, this message translates to:
  /// **'পুনরায় শুরু'**
  String get triageRestart;

  /// No description provided for @triageQuestion.
  ///
  /// In bn, this message translates to:
  /// **'প্রশ্ন {num} / {total}'**
  String triageQuestion(String num, String total);

  /// No description provided for @triageYes.
  ///
  /// In bn, this message translates to:
  /// **'হ্যাঁ'**
  String get triageYes;

  /// No description provided for @triageNo.
  ///
  /// In bn, this message translates to:
  /// **'না'**
  String get triageNo;

  /// No description provided for @triageViewCard.
  ///
  /// In bn, this message translates to:
  /// **'কার্ড দেখুন'**
  String get triageViewCard;

  /// No description provided for @triageCall999.
  ///
  /// In bn, this message translates to:
  /// **'৯৯৯ কল করুন'**
  String get triageCall999;

  /// No description provided for @triageCalling999.
  ///
  /// In bn, this message translates to:
  /// **'৯৯৯ কল করুন — ফোন অ্যাপে ডায়াল করুন'**
  String get triageCalling999;

  /// No description provided for @shelterTitle.
  ///
  /// In bn, this message translates to:
  /// **'নিকটস্থ আশ্রয়কেন্দ্র'**
  String get shelterTitle;

  /// No description provided for @shelterSearchTooltip.
  ///
  /// In bn, this message translates to:
  /// **'আশ্রয় খুঁজুন'**
  String get shelterSearchTooltip;

  /// No description provided for @shelterClearRoute.
  ///
  /// In bn, this message translates to:
  /// **'রুট মুছুন'**
  String get shelterClearRoute;

  /// No description provided for @shelterOfflineBanner.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন — ক্যাশ টাইলস দেখাচ্ছে'**
  String get shelterOfflineBanner;

  /// No description provided for @shelterMapView.
  ///
  /// In bn, this message translates to:
  /// **'মানচিত্র'**
  String get shelterMapView;

  /// No description provided for @shelterListView.
  ///
  /// In bn, this message translates to:
  /// **'তালিকা'**
  String get shelterListView;

  /// No description provided for @shelterZoomIn.
  ///
  /// In bn, this message translates to:
  /// **'জুম ইন'**
  String get shelterZoomIn;

  /// No description provided for @shelterZoomOut.
  ///
  /// In bn, this message translates to:
  /// **'জুম আউট'**
  String get shelterZoomOut;

  /// No description provided for @shelterDistLabel.
  ///
  /// In bn, this message translates to:
  /// **'দূরত্ব'**
  String get shelterDistLabel;

  /// No description provided for @shelterCapacityLabel.
  ///
  /// In bn, this message translates to:
  /// **'ধারণক্ষমতা'**
  String get shelterCapacityLabel;

  /// No description provided for @shelterPeopleUnit.
  ///
  /// In bn, this message translates to:
  /// **'জন'**
  String get shelterPeopleUnit;

  /// No description provided for @shelterSource.
  ///
  /// In bn, this message translates to:
  /// **'উৎস'**
  String get shelterSource;

  /// No description provided for @shelterApproved.
  ///
  /// In bn, this message translates to:
  /// **'অনুমোদিত'**
  String get shelterApproved;

  /// No description provided for @shelterAddress.
  ///
  /// In bn, this message translates to:
  /// **'ঠিকানা'**
  String get shelterAddress;

  /// No description provided for @shelterLandmark.
  ///
  /// In bn, this message translates to:
  /// **'ল্যান্ডমার্ক'**
  String get shelterLandmark;

  /// No description provided for @shelterDesc.
  ///
  /// In bn, this message translates to:
  /// **'বিবরণ'**
  String get shelterDesc;

  /// No description provided for @shelterCapacityCount.
  ///
  /// In bn, this message translates to:
  /// **'ধারণক্ষমতা: {count} জন'**
  String shelterCapacityCount(String count);

  /// No description provided for @shelterFindingRoute.
  ///
  /// In bn, this message translates to:
  /// **'রুট খুঁজছি...'**
  String get shelterFindingRoute;

  /// No description provided for @shelterDetails.
  ///
  /// In bn, this message translates to:
  /// **'বিস্তারিত'**
  String get shelterDetails;

  /// No description provided for @shelterNoData.
  ///
  /// In bn, this message translates to:
  /// **'কোনো আশ্রয়কেন্দ্রের তথ্য নেই'**
  String get shelterNoData;

  /// No description provided for @shelterKm.
  ///
  /// In bn, this message translates to:
  /// **'কিমি'**
  String get shelterKm;

  /// No description provided for @shelterSearchHint.
  ///
  /// In bn, this message translates to:
  /// **'আশ্রয়কেন্দ্র খুঁজুন...'**
  String get shelterSearchHint;

  /// No description provided for @shelterSelectDistrict.
  ///
  /// In bn, this message translates to:
  /// **'জেলা নির্বাচন করুন'**
  String get shelterSelectDistrict;

  /// No description provided for @shelterAllDistricts.
  ///
  /// In bn, this message translates to:
  /// **'সব জেলা'**
  String get shelterAllDistricts;

  /// No description provided for @shelterMyLocation.
  ///
  /// In bn, this message translates to:
  /// **'আমার অবস্থান'**
  String get shelterMyLocation;

  /// No description provided for @shelterLocationUnavailable.
  ///
  /// In bn, this message translates to:
  /// **'অবস্থান পাওয়া যায়নি। জিপিএস চালু করুন।'**
  String get shelterLocationUnavailable;

  /// No description provided for @shelterSearchEmpty.
  ///
  /// In bn, this message translates to:
  /// **'কোনো আশ্রয়কেন্দ্র পাওয়া যায়নি'**
  String get shelterSearchEmpty;

  /// No description provided for @shelterNearest3.
  ///
  /// In bn, this message translates to:
  /// **'নিকটতম ৩টি'**
  String get shelterNearest3;

  /// No description provided for @chatReadAloud.
  ///
  /// In bn, this message translates to:
  /// **'পড়ুন'**
  String get chatReadAloud;

  /// No description provided for @chatPathCloud.
  ///
  /// In bn, this message translates to:
  /// **'ক্লাউড'**
  String get chatPathCloud;

  /// No description provided for @chatPathDevice.
  ///
  /// In bn, this message translates to:
  /// **'ডিভাইস'**
  String get chatPathDevice;

  /// No description provided for @chatPathCorpus.
  ///
  /// In bn, this message translates to:
  /// **'কোরপাস'**
  String get chatPathCorpus;

  /// No description provided for @chatPathCanned.
  ///
  /// In bn, this message translates to:
  /// **'৯৯৯'**
  String get chatPathCanned;

  /// No description provided for @meshDeleteChatHistory.
  ///
  /// In bn, this message translates to:
  /// **'চ্যাট ইতিহাস মুছুন?'**
  String get meshDeleteChatHistory;

  /// No description provided for @meshDeleteChatBody.
  ///
  /// In bn, this message translates to:
  /// **'\"{peer}\" এর সাথে সব মেসেজ মুছে ফেলা হবে। এই কাজ পূর্বাবস্থায় ফেরানো যাবে না।'**
  String meshDeleteChatBody(String peer);

  /// No description provided for @meshDeleteChatDone.
  ///
  /// In bn, this message translates to:
  /// **'চ্যাট ইতিহাস মুছে ফেলা হয়েছে'**
  String get meshDeleteChatDone;

  /// No description provided for @meshDeleteChatButton.
  ///
  /// In bn, this message translates to:
  /// **'মুছুন'**
  String get meshDeleteChatButton;

  /// No description provided for @meshSendMessageFailed.
  ///
  /// In bn, this message translates to:
  /// **'মেসেজ পাঠানো যায়নি — পিয়ার সংযুক্ত আছে কিনা দেখুন'**
  String get meshSendMessageFailed;

  /// No description provided for @meshSendMediaFailed.
  ///
  /// In bn, this message translates to:
  /// **'মিডিয়া পাঠানো যায়নি — পিয়ার সংযুক্ত আছে কিনা দেখুন'**
  String get meshSendMediaFailed;

  /// No description provided for @meshCallTooltip.
  ///
  /// In bn, this message translates to:
  /// **'ভয়েস কল'**
  String get meshCallTooltip;

  /// No description provided for @meshDeleteChatMenu.
  ///
  /// In bn, this message translates to:
  /// **'চ্যাট ইতিহাস মুছুন'**
  String get meshDeleteChatMenu;

  /// No description provided for @meshEmptyChat.
  ///
  /// In bn, this message translates to:
  /// **'কোনো মেসেজ নেই\n\"{peer}\" এর সাথে কথা বলুন'**
  String meshEmptyChat(String peer);

  /// No description provided for @meshInputHint.
  ///
  /// In bn, this message translates to:
  /// **'মেসেজ লিখুন...'**
  String get meshInputHint;

  /// No description provided for @meshHopCount.
  ///
  /// In bn, this message translates to:
  /// **'↻ {count} হপ'**
  String meshHopCount(String count);

  /// No description provided for @meshSendImage.
  ///
  /// In bn, this message translates to:
  /// **'ছবি পাঠান'**
  String get meshSendImage;

  /// No description provided for @meshSendVideo.
  ///
  /// In bn, this message translates to:
  /// **'ভিডিও পাঠান'**
  String get meshSendVideo;

  /// No description provided for @meshImageMissing.
  ///
  /// In bn, this message translates to:
  /// **'ছবি পাওয়া যায়নি'**
  String get meshImageMissing;

  /// No description provided for @meshImageLoadError.
  ///
  /// In bn, this message translates to:
  /// **'ছবি লোড হয়নি'**
  String get meshImageLoadError;

  /// No description provided for @meshVideoMissing.
  ///
  /// In bn, this message translates to:
  /// **'ভিডিও পাওয়া যায়নি'**
  String get meshVideoMissing;

  /// No description provided for @meshVideoBadge.
  ///
  /// In bn, this message translates to:
  /// **'ভিডিও'**
  String get meshVideoBadge;

  /// No description provided for @meshVideoLoadError.
  ///
  /// In bn, this message translates to:
  /// **'ভিডিও লোড হয়নি'**
  String get meshVideoLoadError;

  /// No description provided for @meshRescanTooltip.
  ///
  /// In bn, this message translates to:
  /// **'পুনরায় স্ক্যান করুন'**
  String get meshRescanTooltip;

  /// No description provided for @meshRescanning.
  ///
  /// In bn, this message translates to:
  /// **'আবার স্ক্যান করা হচ্ছে...'**
  String get meshRescanning;

  /// No description provided for @meshConnectingStatus.
  ///
  /// In bn, this message translates to:
  /// **'সংযোগ করা হচ্ছে...'**
  String get meshConnectingStatus;

  /// No description provided for @meshConnectFailed.
  ///
  /// In bn, this message translates to:
  /// **'সংযোগ ব্যর্থ হয়েছে'**
  String get meshConnectFailed;

  /// No description provided for @meshOfflineContact.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন'**
  String get meshOfflineContact;

  /// No description provided for @emergencyCloseTooltip.
  ///
  /// In bn, this message translates to:
  /// **'বাতিল'**
  String get emergencyCloseTooltip;

  /// No description provided for @emergencyCallTitle.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি কল'**
  String get emergencyCallTitle;

  /// No description provided for @emergencyCallNumber.
  ///
  /// In bn, this message translates to:
  /// **'৯৯৯'**
  String get emergencyCallNumber;

  /// No description provided for @emergencySlideInstruction.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি সেবায় কল করতে ডানে স্লাইড করুন'**
  String get emergencySlideInstruction;

  /// No description provided for @emergencySendSos.
  ///
  /// In bn, this message translates to:
  /// **'পরিবর্তে SOS পাঠান'**
  String get emergencySendSos;

  /// No description provided for @emergencySlideRelease.
  ///
  /// In bn, this message translates to:
  /// **'ছেড়ে দিন'**
  String get emergencySlideRelease;

  /// No description provided for @emergencySlideHint.
  ///
  /// In bn, this message translates to:
  /// **'ডানে স্লাইড করুন'**
  String get emergencySlideHint;

  /// No description provided for @emergencyCallButton.
  ///
  /// In bn, this message translates to:
  /// **'কল করুন'**
  String get emergencyCallButton;

  /// No description provided for @emergencyDefaultUser.
  ///
  /// In bn, this message translates to:
  /// **'ব্যবহারকারী'**
  String get emergencyDefaultUser;

  /// No description provided for @emergencyDefaultPhone.
  ///
  /// In bn, this message translates to:
  /// **'অজানা'**
  String get emergencyDefaultPhone;

  /// No description provided for @emergencyGpsDenied.
  ///
  /// In bn, this message translates to:
  /// **'GPS অনুমতি দেওয়া হয়নি'**
  String get emergencyGpsDenied;

  /// No description provided for @emergencyGpsNotFound.
  ///
  /// In bn, this message translates to:
  /// **'GPS পাওয়া যায়নি (স্যাটেলাইট সিগন্যাল নেই?)'**
  String get emergencyGpsNotFound;

  /// No description provided for @emergencySosFailed.
  ///
  /// In bn, this message translates to:
  /// **'SOS পাঠানো যায়নি — স্মস অ্যাপ খুঁজে পাওয়া যায়নি'**
  String get emergencySosFailed;

  /// No description provided for @emergencyCallFallback.
  ///
  /// In bn, this message translates to:
  /// **'কে কল করুন বা ৯৯৯।'**
  String get emergencyCallFallback;

  /// No description provided for @sosReportTitle.
  ///
  /// In bn, this message translates to:
  /// **'SOS রিপোর্ট'**
  String get sosReportTitle;

  /// No description provided for @sosDescribeHeading.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি অবস্থা বর্ণনা করুন'**
  String get sosDescribeHeading;

  /// No description provided for @sosDescribeHint.
  ///
  /// In bn, this message translates to:
  /// **'কী হয়েছে, কোথায়, কে আহত...'**
  String get sosDescribeHint;

  /// No description provided for @sosAiTooltip.
  ///
  /// In bn, this message translates to:
  /// **'AI দিয়ে গঠন করুন'**
  String get sosAiTooltip;

  /// No description provided for @sosStructuredHeading.
  ///
  /// In bn, this message translates to:
  /// **'গঠিত রিপোর্ট'**
  String get sosStructuredHeading;

  /// No description provided for @sosFieldLocation.
  ///
  /// In bn, this message translates to:
  /// **'স্থান (Location)'**
  String get sosFieldLocation;

  /// No description provided for @sosFieldLocationHint.
  ///
  /// In bn, this message translates to:
  /// **'এলাকা/ঠিকানা'**
  String get sosFieldLocationHint;

  /// No description provided for @sosFieldHazard.
  ///
  /// In bn, this message translates to:
  /// **'ধরন (Hazard)'**
  String get sosFieldHazard;

  /// No description provided for @sosFieldHazardHint.
  ///
  /// In bn, this message translates to:
  /// **'বন্যা/অগ্নিকাণ্ড/সাপ/...'**
  String get sosFieldHazardHint;

  /// No description provided for @sosFieldInjured.
  ///
  /// In bn, this message translates to:
  /// **'আহতের সংখ্যা'**
  String get sosFieldInjured;

  /// No description provided for @sosFieldInjuredHint.
  ///
  /// In bn, this message translates to:
  /// **'০'**
  String get sosFieldInjuredHint;

  /// No description provided for @sosFieldInjury.
  ///
  /// In bn, this message translates to:
  /// **'আঘাতের বিবরণ'**
  String get sosFieldInjury;

  /// No description provided for @sosFieldInjuryHint.
  ///
  /// In bn, this message translates to:
  /// **'কী ধরনের আঘাত'**
  String get sosFieldInjuryHint;

  /// No description provided for @sosFieldUrgent.
  ///
  /// In bn, this message translates to:
  /// **'তাৎক্ষণিক প্রয়োজন'**
  String get sosFieldUrgent;

  /// No description provided for @sosFieldUrgentHint.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাম্বুলেন্স/উদ্ধার/চিকিৎসা'**
  String get sosFieldUrgentHint;

  /// No description provided for @sosFieldAccess.
  ///
  /// In bn, this message translates to:
  /// **'প্রবেশপথ তথ্য'**
  String get sosFieldAccess;

  /// No description provided for @sosFieldAccessHint.
  ///
  /// In bn, this message translates to:
  /// **'রাস্তা/ল্যান্ডমার্ক/বাধা'**
  String get sosFieldAccessHint;

  /// No description provided for @sosSmsPreview.
  ///
  /// In bn, this message translates to:
  /// **'SMS প্রিভিউ'**
  String get sosSmsPreview;

  /// No description provided for @sosCall999Button.
  ///
  /// In bn, this message translates to:
  /// **'৯৯৯ কল করুন'**
  String get sosCall999Button;

  /// No description provided for @sosEmptyInputError.
  ///
  /// In bn, this message translates to:
  /// **'আগে অবস্থা বর্ণনা লিখুন।'**
  String get sosEmptyInputError;

  /// No description provided for @sosModelNotReady.
  ///
  /// In bn, this message translates to:
  /// **'মডেল লোড করা নেই — নিজে পূরণ করুন।'**
  String get sosModelNotReady;

  /// No description provided for @sosAiFailed.
  ///
  /// In bn, this message translates to:
  /// **'AI গঠন করতে পারেনি — নিজে পূরণ করুন।'**
  String get sosAiFailed;

  /// No description provided for @sosAiSuccess.
  ///
  /// In bn, this message translates to:
  /// **'AI দিয়ে গঠন সম্পন্ন — যাচাই করুন।'**
  String get sosAiSuccess;

  /// No description provided for @hazardsAllAlerts.
  ///
  /// In bn, this message translates to:
  /// **'সকল সতর্কতা'**
  String get hazardsAllAlerts;

  /// No description provided for @quickCardsTitle.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি সহায়তা কার্ড'**
  String get quickCardsTitle;

  /// No description provided for @quickCardsSearchHint.
  ///
  /// In bn, this message translates to:
  /// **'খুঁজুন: অরএস, সাপের কামড়, বন্যা...'**
  String get quickCardsSearchHint;

  /// No description provided for @adminLogoutTitle.
  ///
  /// In bn, this message translates to:
  /// **'লগআউট করবেন?'**
  String get adminLogoutTitle;

  /// No description provided for @adminLogoutBody.
  ///
  /// In bn, this message translates to:
  /// **'আপনি কি অ্যাডমিন প্যানেল থেকে বের হতে চান?'**
  String get adminLogoutBody;

  /// No description provided for @adminLogoutButton.
  ///
  /// In bn, this message translates to:
  /// **'লগআউট'**
  String get adminLogoutButton;

  /// No description provided for @adminTileOpen.
  ///
  /// In bn, this message translates to:
  /// **'বিস্তারিত'**
  String get adminTileOpen;

  /// No description provided for @adminPanelTitle.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাডমিন প্যানেল'**
  String get adminPanelTitle;

  /// No description provided for @adminTabDashboard.
  ///
  /// In bn, this message translates to:
  /// **'ড্যাশবোর্ড'**
  String get adminTabDashboard;

  /// No description provided for @adminTabUsers.
  ///
  /// In bn, this message translates to:
  /// **'ব্যবহারকারী'**
  String get adminTabUsers;

  /// No description provided for @adminTabCampaigns.
  ///
  /// In bn, this message translates to:
  /// **'অভিযান অনুরোধ'**
  String get adminTabCampaigns;

  /// No description provided for @adminTabBroadcast.
  ///
  /// In bn, this message translates to:
  /// **'বার্তা ব্রডকাস্ট'**
  String get adminTabBroadcast;

  /// No description provided for @adminStatUsers.
  ///
  /// In bn, this message translates to:
  /// **'মোট ব্যবহারকারী'**
  String get adminStatUsers;

  /// No description provided for @adminStatOffline.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন সেশন'**
  String get adminStatOffline;

  /// No description provided for @adminStatMesh.
  ///
  /// In bn, this message translates to:
  /// **'মেশ পিয়ার'**
  String get adminStatMesh;

  /// No description provided for @adminNoDevices.
  ///
  /// In bn, this message translates to:
  /// **'কোনো সংযুক্ত ডিভাইস নেই'**
  String get adminNoDevices;

  /// No description provided for @adminUnknownDevice.
  ///
  /// In bn, this message translates to:
  /// **'অজ্ঞাত ডিভাইস'**
  String get adminUnknownDevice;

  /// No description provided for @adminDeviceOnline.
  ///
  /// In bn, this message translates to:
  /// **'অনলাইন'**
  String get adminDeviceOnline;

  /// No description provided for @adminDeviceOffline.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন'**
  String get adminDeviceOffline;

  /// No description provided for @adminDeviceNearby.
  ///
  /// In bn, this message translates to:
  /// **'কাছাকাছি'**
  String get adminDeviceNearby;

  /// No description provided for @adminDeviceAdmin.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাডমিন'**
  String get adminDeviceAdmin;

  /// No description provided for @adminDeviceNeverSeen.
  ///
  /// In bn, this message translates to:
  /// **'কখনো যুক্ত হয়নি'**
  String get adminDeviceNeverSeen;

  /// No description provided for @adminNoCampaigns.
  ///
  /// In bn, this message translates to:
  /// **'কোনো অভিযান অনুরোধ নেই'**
  String get adminNoCampaigns;

  /// No description provided for @adminDetailUser.
  ///
  /// In bn, this message translates to:
  /// **'ব্যবহারকারী'**
  String get adminDetailUser;

  /// No description provided for @adminDetailPhone.
  ///
  /// In bn, this message translates to:
  /// **'ফোন'**
  String get adminDetailPhone;

  /// No description provided for @adminDetailAddress.
  ///
  /// In bn, this message translates to:
  /// **'ঠিকানা'**
  String get adminDetailAddress;

  /// No description provided for @adminDetailLandmark.
  ///
  /// In bn, this message translates to:
  /// **'ল্যান্ডমার্ক'**
  String get adminDetailLandmark;

  /// No description provided for @adminDetailCoords.
  ///
  /// In bn, this message translates to:
  /// **'স্থানাঙ্ক'**
  String get adminDetailCoords;

  /// No description provided for @adminDetailTime.
  ///
  /// In bn, this message translates to:
  /// **'সময়'**
  String get adminDetailTime;

  /// No description provided for @adminDetailDesc.
  ///
  /// In bn, this message translates to:
  /// **'বিবরণ'**
  String get adminDetailDesc;

  /// No description provided for @adminDetailNotes.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাডমিন নোট'**
  String get adminDetailNotes;

  /// No description provided for @adminRejectLabel.
  ///
  /// In bn, this message translates to:
  /// **'প্রত্যাখ্যাত'**
  String get adminRejectLabel;

  /// No description provided for @adminApproveLabel.
  ///
  /// In bn, this message translates to:
  /// **'অনুমোদন'**
  String get adminApproveLabel;

  /// No description provided for @adminApproveSuccess.
  ///
  /// In bn, this message translates to:
  /// **'{type} অনুমোদিত — মানচিত্রে যোগ করা হয়েছে'**
  String adminApproveSuccess(String type);

  /// No description provided for @adminCloseButton.
  ///
  /// In bn, this message translates to:
  /// **'বন্ধ করুন'**
  String get adminCloseButton;

  /// No description provided for @adminProximityNotified.
  ///
  /// In bn, this message translates to:
  /// **'নিকটস্থ ব্যবহারকারীদের বিজ্ঞপ্তি পাঠানো হয়েছে'**
  String get adminProximityNotified;

  /// No description provided for @adminNotesHint.
  ///
  /// In bn, this message translates to:
  /// **'নোট লিখুন...'**
  String get adminNotesHint;

  /// No description provided for @adminBroadcastSuccess.
  ///
  /// In bn, this message translates to:
  /// **'বার্তা পাঠানো হয়েছে'**
  String get adminBroadcastSuccess;

  /// No description provided for @adminBroadcastSection.
  ///
  /// In bn, this message translates to:
  /// **'গ্লোবাল ব্রডকাস্ট'**
  String get adminBroadcastSection;

  /// No description provided for @adminBroadcastSubtitle.
  ///
  /// In bn, this message translates to:
  /// **'সব ব্যবহারকারীকে একটি বার্তা পাঠান'**
  String get adminBroadcastSubtitle;

  /// No description provided for @adminBroadcastHint.
  ///
  /// In bn, this message translates to:
  /// **'বার্তা লিখুন…'**
  String get adminBroadcastHint;

  /// No description provided for @adminBroadcastButton.
  ///
  /// In bn, this message translates to:
  /// **'বার্তা পাঠান'**
  String get adminBroadcastButton;

  /// No description provided for @adminLoginError.
  ///
  /// In bn, this message translates to:
  /// **'ভুল ব্যবহারকারীর নাম অথবা পাসওয়ার্ড।'**
  String get adminLoginError;

  /// No description provided for @adminLoginTitle.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাডমিন লগইন'**
  String get adminLoginTitle;

  /// No description provided for @adminLoginHeading.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাডমিন প্যানেল প্রবেশাধিকার'**
  String get adminLoginHeading;

  /// No description provided for @adminLoginSubtitle.
  ///
  /// In bn, this message translates to:
  /// **'অনুগ্রহ করে আপনার সঠিক পরিচয় পত্র প্রদান করুন।'**
  String get adminLoginSubtitle;

  /// No description provided for @adminUsernameLabel.
  ///
  /// In bn, this message translates to:
  /// **'ব্যবহারকারীর নাম'**
  String get adminUsernameLabel;

  /// No description provided for @adminUsernameValidator.
  ///
  /// In bn, this message translates to:
  /// **'ব্যবহারকারীর নাম লিখুন'**
  String get adminUsernameValidator;

  /// No description provided for @adminPasswordLabel.
  ///
  /// In bn, this message translates to:
  /// **'পাসওয়ার্ড'**
  String get adminPasswordLabel;

  /// No description provided for @adminPasswordValidator.
  ///
  /// In bn, this message translates to:
  /// **'পাসওয়ার্ড লিখুন'**
  String get adminPasswordValidator;

  /// No description provided for @adminLoginButton.
  ///
  /// In bn, this message translates to:
  /// **'প্রবেশ করুন'**
  String get adminLoginButton;

  /// No description provided for @mapPickerTitle.
  ///
  /// In bn, this message translates to:
  /// **'মানচিত্রে অবস্থান নির্বাচন'**
  String get mapPickerTitle;

  /// No description provided for @mapPickerSearchHint.
  ///
  /// In bn, this message translates to:
  /// **'এলাকা খুঁজুন (যেমন: ঢাকা, চট্টগ্রাম)'**
  String get mapPickerSearchHint;

  /// No description provided for @mapPickerZoomIn.
  ///
  /// In bn, this message translates to:
  /// **'জুম ইন'**
  String get mapPickerZoomIn;

  /// No description provided for @mapPickerZoomOut.
  ///
  /// In bn, this message translates to:
  /// **'জুম আউট'**
  String get mapPickerZoomOut;

  /// No description provided for @mapPickerMyLocation.
  ///
  /// In bn, this message translates to:
  /// **'আমার অবস্থান'**
  String get mapPickerMyLocation;

  /// No description provided for @mapPickerInstruction.
  ///
  /// In bn, this message translates to:
  /// **'মানচিত্রে যেকোনো স্থানে ট্যাপ করে পিন দিন'**
  String get mapPickerInstruction;

  /// No description provided for @mapPickerConfirm.
  ///
  /// In bn, this message translates to:
  /// **'অবস্থান নিশ্চিত করুন'**
  String get mapPickerConfirm;

  /// No description provided for @profileGenderLabel.
  ///
  /// In bn, this message translates to:
  /// **'লিঙ্গ'**
  String get profileGenderLabel;

  /// No description provided for @profileGenderMale.
  ///
  /// In bn, this message translates to:
  /// **'পুরুষ'**
  String get profileGenderMale;

  /// No description provided for @profileGenderFemale.
  ///
  /// In bn, this message translates to:
  /// **'মহিলা'**
  String get profileGenderFemale;

  /// No description provided for @profileHealthConditions.
  ///
  /// In bn, this message translates to:
  /// **'স্বাস্থ্যগত অবস্থা'**
  String get profileHealthConditions;

  /// No description provided for @profilePregnant.
  ///
  /// In bn, this message translates to:
  /// **'গর্ভবতী'**
  String get profilePregnant;

  /// No description provided for @profileDisabled.
  ///
  /// In bn, this message translates to:
  /// **'প্রতিবন্ধী'**
  String get profileDisabled;

  /// No description provided for @profileElderly.
  ///
  /// In bn, this message translates to:
  /// **'বয়স্ক'**
  String get profileElderly;

  /// No description provided for @profileChildrenPresent.
  ///
  /// In bn, this message translates to:
  /// **'শিশু আছে'**
  String get profileChildrenPresent;

  /// No description provided for @profileDisasterProne.
  ///
  /// In bn, this message translates to:
  /// **'দুর্যোগ-প্রবণ এলাকা'**
  String get profileDisasterProne;

  /// No description provided for @profileSaveSuccess.
  ///
  /// In bn, this message translates to:
  /// **'প্রোফাইল সংরক্ষিত হয়েছে'**
  String get profileSaveSuccess;

  /// No description provided for @profileDefaultName.
  ///
  /// In bn, this message translates to:
  /// **'ব্যবহারকারী'**
  String get profileDefaultName;

  /// No description provided for @profileNoLocation.
  ///
  /// In bn, this message translates to:
  /// **'অবস্থান নেই'**
  String get profileNoLocation;

  /// No description provided for @profileLocationLoading.
  ///
  /// In bn, this message translates to:
  /// **'অবস্থান লোড হচ্ছে...'**
  String get profileLocationLoading;

  /// No description provided for @profileTitle.
  ///
  /// In bn, this message translates to:
  /// **'প্রোফাইল'**
  String get profileTitle;

  /// No description provided for @profileGallery.
  ///
  /// In bn, this message translates to:
  /// **'গ্যালারি'**
  String get profileGallery;

  /// No description provided for @profileCamera.
  ///
  /// In bn, this message translates to:
  /// **'ক্যামেরা'**
  String get profileCamera;

  /// No description provided for @profileDeletePhotoTitle.
  ///
  /// In bn, this message translates to:
  /// **'ছবি মুছুন?'**
  String get profileDeletePhotoTitle;

  /// No description provided for @profileDeletePhotoBody.
  ///
  /// In bn, this message translates to:
  /// **'প্রোফাইল থেকে ছবি সরিয়ে ফেলবে।'**
  String get profileDeletePhotoBody;

  /// No description provided for @profileRemovePhoto.
  ///
  /// In bn, this message translates to:
  /// **'ছবি মুছুন'**
  String get profileRemovePhoto;

  /// No description provided for @profileDistrict.
  ///
  /// In bn, this message translates to:
  /// **'জেলা'**
  String get profileDistrict;

  /// No description provided for @profileDistrictHint.
  ///
  /// In bn, this message translates to:
  /// **'বিভাগ ও জেলা নির্বাচন করুন'**
  String get profileDistrictHint;

  /// No description provided for @profileEnterName.
  ///
  /// In bn, this message translates to:
  /// **'নাম লিখুন'**
  String get profileEnterName;

  /// No description provided for @modelStatusNotDownloaded.
  ///
  /// In bn, this message translates to:
  /// **'ডাউনলোড প্রয়োজন'**
  String get modelStatusNotDownloaded;

  /// No description provided for @modelStatusDownloading.
  ///
  /// In bn, this message translates to:
  /// **'ডাউনলোড হচ্ছে {progress}'**
  String modelStatusDownloading(String progress);

  /// No description provided for @modelStatusReady.
  ///
  /// In bn, this message translates to:
  /// **'প্রস্তুত'**
  String get modelStatusReady;

  /// No description provided for @modelStatusLoading.
  ///
  /// In bn, this message translates to:
  /// **'প্রস্তুত হচ্ছে...'**
  String get modelStatusLoading;

  /// No description provided for @modelStatusFailed.
  ///
  /// In bn, this message translates to:
  /// **'ব্যর্থ'**
  String get modelStatusFailed;

  /// No description provided for @modelE2bSize.
  ///
  /// In bn, this message translates to:
  /// **'~২.৫ GB'**
  String get modelE2bSize;

  /// No description provided for @modelE2bDesc.
  ///
  /// In bn, this message translates to:
  /// **'হালকা ও দ্রুত। সব ডিভাইসে কাজ করবে।'**
  String get modelE2bDesc;

  /// No description provided for @modelE4bSize.
  ///
  /// In bn, this message translates to:
  /// **'~৩.৫ GB'**
  String get modelE4bSize;

  /// No description provided for @modelE4bDesc.
  ///
  /// In bn, this message translates to:
  /// **'ভালো মানের উত্তর। ৬GB+ র‍্যাম প্রয়োজন।'**
  String get modelE4bDesc;

  /// No description provided for @model12bSize.
  ///
  /// In bn, this message translates to:
  /// **'~৭-১০ GB'**
  String get model12bSize;

  /// No description provided for @model12bDesc.
  ///
  /// In bn, this message translates to:
  /// **'সেরা মানের উত্তর। ১২GB+ র‍্যাম প্রয়োজন।'**
  String get model12bDesc;

  /// No description provided for @modelLightLabel.
  ///
  /// In bn, this message translates to:
  /// **'হালকা'**
  String get modelLightLabel;

  /// No description provided for @modelPowerfulLabel.
  ///
  /// In bn, this message translates to:
  /// **'শক্তিশালী'**
  String get modelPowerfulLabel;

  /// No description provided for @modelInfoTooltip.
  ///
  /// In bn, this message translates to:
  /// **'মডেল সম্পর্কে জানুন'**
  String get modelInfoTooltip;

  /// No description provided for @modelInfoDialogTitle.
  ///
  /// In bn, this message translates to:
  /// **'AI মডেল সম্পর্কে'**
  String get modelInfoDialogTitle;

  /// No description provided for @modelInfoVariant.
  ///
  /// In bn, this message translates to:
  /// **'মডেল'**
  String get modelInfoVariant;

  /// No description provided for @modelInfoParams.
  ///
  /// In bn, this message translates to:
  /// **'প্যারামিটার'**
  String get modelInfoParams;

  /// No description provided for @modelInfoSize.
  ///
  /// In bn, this message translates to:
  /// **'সাইজ'**
  String get modelInfoSize;

  /// No description provided for @modelInfoRam.
  ///
  /// In bn, this message translates to:
  /// **'র‍্যাম ব্যবহার'**
  String get modelInfoRam;

  /// No description provided for @hazardCyclone.
  ///
  /// In bn, this message translates to:
  /// **'ঘূর্ণিঝড়'**
  String get hazardCyclone;

  /// No description provided for @hazardFlood.
  ///
  /// In bn, this message translates to:
  /// **'বন্যা'**
  String get hazardFlood;

  /// No description provided for @hazardEarthquake.
  ///
  /// In bn, this message translates to:
  /// **'ভূমিকম্প'**
  String get hazardEarthquake;

  /// No description provided for @hazardWildfire.
  ///
  /// In bn, this message translates to:
  /// **'দাবানল'**
  String get hazardWildfire;

  /// No description provided for @hazardVolcano.
  ///
  /// In bn, this message translates to:
  /// **'আগ্নেয়গিরি'**
  String get hazardVolcano;

  /// No description provided for @hazardLandslide.
  ///
  /// In bn, this message translates to:
  /// **'ভূমিধস'**
  String get hazardLandslide;

  /// No description provided for @hazardExtremeHeat.
  ///
  /// In bn, this message translates to:
  /// **'তীব্র তাপ'**
  String get hazardExtremeHeat;

  /// No description provided for @hazardDrought.
  ///
  /// In bn, this message translates to:
  /// **'খরা'**
  String get hazardDrought;

  /// No description provided for @hazardSeaIce.
  ///
  /// In bn, this message translates to:
  /// **'সমুদ্রের বরফ'**
  String get hazardSeaIce;

  /// No description provided for @hazardManmade.
  ///
  /// In bn, this message translates to:
  /// **'মানবসৃষ্ট'**
  String get hazardManmade;

  /// No description provided for @hazardOther.
  ///
  /// In bn, this message translates to:
  /// **'অন্যান্য'**
  String get hazardOther;

  /// No description provided for @severityGreen.
  ///
  /// In bn, this message translates to:
  /// **'সবুজ'**
  String get severityGreen;

  /// No description provided for @severityOrange.
  ///
  /// In bn, this message translates to:
  /// **'কমলা'**
  String get severityOrange;

  /// No description provided for @severityRed.
  ///
  /// In bn, this message translates to:
  /// **'লাল'**
  String get severityRed;

  /// No description provided for @severityUnknown.
  ///
  /// In bn, this message translates to:
  /// **'অজানা'**
  String get severityUnknown;

  /// No description provided for @earthquakeLight.
  ///
  /// In bn, this message translates to:
  /// **'হালকা'**
  String get earthquakeLight;

  /// No description provided for @earthquakeModerate.
  ///
  /// In bn, this message translates to:
  /// **'মাঝারি'**
  String get earthquakeModerate;

  /// No description provided for @earthquakeStrong.
  ///
  /// In bn, this message translates to:
  /// **'শক্তিশালী'**
  String get earthquakeStrong;

  /// No description provided for @urgencyCritical.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি'**
  String get urgencyCritical;

  /// No description provided for @urgencyUrgent.
  ///
  /// In bn, this message translates to:
  /// **'তাগিদপূর্ণ'**
  String get urgencyUrgent;

  /// No description provided for @urgencyNormal.
  ///
  /// In bn, this message translates to:
  /// **'সাধারণ'**
  String get urgencyNormal;

  /// No description provided for @contactPolice.
  ///
  /// In bn, this message translates to:
  /// **'পুলিশ'**
  String get contactPolice;

  /// No description provided for @contactFire.
  ///
  /// In bn, this message translates to:
  /// **'ফায়ার'**
  String get contactFire;

  /// No description provided for @contactAmbulance.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাম্বুলেন্স'**
  String get contactAmbulance;

  /// No description provided for @contactDisaster.
  ///
  /// In bn, this message translates to:
  /// **'দুর্যোগ'**
  String get contactDisaster;

  /// No description provided for @contactRedCrescent.
  ///
  /// In bn, this message translates to:
  /// **'রেড ক্রিসেন্ট'**
  String get contactRedCrescent;

  /// No description provided for @contactHealth.
  ///
  /// In bn, this message translates to:
  /// **'স্বাস্থ্য'**
  String get contactHealth;

  /// No description provided for @contactOther.
  ///
  /// In bn, this message translates to:
  /// **'অন্যান্য'**
  String get contactOther;

  /// No description provided for @campaignTypeFoodDonation.
  ///
  /// In bn, this message translates to:
  /// **'খাদ্য দান'**
  String get campaignTypeFoodDonation;

  /// No description provided for @campaignTypeRescue.
  ///
  /// In bn, this message translates to:
  /// **'উদ্ধার আপারেশন'**
  String get campaignTypeRescue;

  /// No description provided for @campaignTypeMedical.
  ///
  /// In bn, this message translates to:
  /// **'চিকিৎসা শিবির'**
  String get campaignTypeMedical;

  /// No description provided for @campaignTypeShelter.
  ///
  /// In bn, this message translates to:
  /// **'আশ্রয় সহায়তা'**
  String get campaignTypeShelter;

  /// No description provided for @campaignTypeClothing.
  ///
  /// In bn, this message translates to:
  /// **'পোশাক দান'**
  String get campaignTypeClothing;

  /// No description provided for @campaignTypeWater.
  ///
  /// In bn, this message translates to:
  /// **'পানি সরবরাহ'**
  String get campaignTypeWater;

  /// No description provided for @campaignStatusPending.
  ///
  /// In bn, this message translates to:
  /// **'অপেক্ষমান'**
  String get campaignStatusPending;

  /// No description provided for @campaignStatusApproved.
  ///
  /// In bn, this message translates to:
  /// **'অনুমোদিত'**
  String get campaignStatusApproved;

  /// No description provided for @campaignStatusRejected.
  ///
  /// In bn, this message translates to:
  /// **'প্রত্যাখ্যান'**
  String get campaignStatusRejected;

  /// No description provided for @chatSend.
  ///
  /// In bn, this message translates to:
  /// **'পাঠান'**
  String get chatSend;

  /// No description provided for @adminDashboardTitle.
  ///
  /// In bn, this message translates to:
  /// **'সিস্টেম সারসংক্ষেপ'**
  String get adminDashboardTitle;

  /// No description provided for @adminDashboardSubtitle.
  ///
  /// In bn, this message translates to:
  /// **'মেশ পিয়ার এবং অভিযানের রিয়েল-টাইম অবস্থা'**
  String get adminDashboardSubtitle;

  /// No description provided for @adminQuickActions.
  ///
  /// In bn, this message translates to:
  /// **'দ্রুত অ্যাকশন'**
  String get adminQuickActions;

  /// No description provided for @adminReviewCampaigns.
  ///
  /// In bn, this message translates to:
  /// **'অভিযান পর্যালোচনা'**
  String get adminReviewCampaigns;

  /// No description provided for @adminApprove.
  ///
  /// In bn, this message translates to:
  /// **'অনুমোদন'**
  String get adminApprove;

  /// No description provided for @adminApproved.
  ///
  /// In bn, this message translates to:
  /// **'অনুমোদিত'**
  String get adminApproved;

  /// No description provided for @adminBroadcastSend.
  ///
  /// In bn, this message translates to:
  /// **'পাঠান'**
  String get adminBroadcastSend;

  /// No description provided for @adminPageBackTooltip.
  ///
  /// In bn, this message translates to:
  /// **'পিছনে'**
  String get adminPageBackTooltip;

  /// No description provided for @safetyStatusTitle.
  ///
  /// In bn, this message translates to:
  /// **'আমার অবস্থা'**
  String get safetyStatusTitle;

  /// No description provided for @safetyStatusDesc.
  ///
  /// In bn, this message translates to:
  /// **'আপনার বর্তমান অবস্থা জানান। বন্ধুবান্ধব ও জরুরি পরিষেবাকে অবহিত করুন।'**
  String get safetyStatusDesc;

  /// No description provided for @safetySafeButton.
  ///
  /// In bn, this message translates to:
  /// **'আমি নিরাপদ'**
  String get safetySafeButton;

  /// No description provided for @safetyDangerButton.
  ///
  /// In bn, this message translates to:
  /// **'আমি বিপদে আছি'**
  String get safetyDangerButton;

  /// No description provided for @safetyStatusSent.
  ///
  /// In bn, this message translates to:
  /// **'নিরাপদ বার্তা পাঠানো হয়েছে'**
  String get safetyStatusSent;

  /// No description provided for @dangerAlertSent.
  ///
  /// In bn, this message translates to:
  /// **'বিপদ সংকেত পাঠানো হয়েছে — সাহায্য আসছে'**
  String get dangerAlertSent;

  /// No description provided for @safetyStatusNone.
  ///
  /// In bn, this message translates to:
  /// **'কোনো অবস্থা জানানো হয়নি'**
  String get safetyStatusNone;

  /// No description provided for @safetyCurrentSafe.
  ///
  /// In bn, this message translates to:
  /// **'বর্তমান অবস্থা: নিরাপদ'**
  String get safetyCurrentSafe;

  /// No description provided for @safetyCurrentDanger.
  ///
  /// In bn, this message translates to:
  /// **'বর্তমান অবস্থা'**
  String get safetyCurrentDanger;

  /// No description provided for @dangerTypePickerTitle.
  ///
  /// In bn, this message translates to:
  /// **'কোন ধরনের বিপদে আছেন?'**
  String get dangerTypePickerTitle;

  /// No description provided for @dangerTypePickerSubtitle.
  ///
  /// In bn, this message translates to:
  /// **'আপনার অবস্থা নির্বাচন করুন'**
  String get dangerTypePickerSubtitle;

  /// No description provided for @adminSafetyTotal.
  ///
  /// In bn, this message translates to:
  /// **'মোট ব্যবহারকারী'**
  String get adminSafetyTotal;

  /// No description provided for @adminSafetySafe.
  ///
  /// In bn, this message translates to:
  /// **'নিরাপদ'**
  String get adminSafetySafe;

  /// No description provided for @adminSafetyDanger.
  ///
  /// In bn, this message translates to:
  /// **'বিপদে'**
  String get adminSafetyDanger;

  /// No description provided for @adminDangerListTitle.
  ///
  /// In bn, this message translates to:
  /// **'বিপদে থাকা ব্যবহারকারী'**
  String get adminDangerListTitle;

  /// No description provided for @adminDangerListEmpty.
  ///
  /// In bn, this message translates to:
  /// **'কেউ বিপদে নেই'**
  String get adminDangerListEmpty;

  /// No description provided for @adminDangerOpenMap.
  ///
  /// In bn, this message translates to:
  /// **'মানচিত্রে দেখুন'**
  String get adminDangerOpenMap;

  /// No description provided for @triageQConscious.
  ///
  /// In bn, this message translates to:
  /// **'ব্যক্তি কি সচেতন?'**
  String get triageQConscious;

  /// No description provided for @triageQBreathing.
  ///
  /// In bn, this message translates to:
  /// **'শ্বাস নিচ্ছে?'**
  String get triageQBreathing;

  /// No description provided for @triageQBleeding.
  ///
  /// In bn, this message translates to:
  /// **'গুরুতর রক্তপাত হচ্ছে?'**
  String get triageQBleeding;

  /// No description provided for @triageQWater.
  ///
  /// In bn, this message translates to:
  /// **'পানিতে ছিল বা ডুবেছে?'**
  String get triageQWater;

  /// No description provided for @triageQSnakebite.
  ///
  /// In bn, this message translates to:
  /// **'সাপে কামড়েছে?'**
  String get triageQSnakebite;

  /// No description provided for @triageQBurn.
  ///
  /// In bn, this message translates to:
  /// **'গুরুতর পোড়া?'**
  String get triageQBurn;

  /// No description provided for @triageQChoking.
  ///
  /// In bn, this message translates to:
  /// **'কথা বলতে বা কাশি দিতে পারছে?'**
  String get triageQChoking;

  /// No description provided for @triageNotify999.
  ///
  /// In bn, this message translates to:
  /// **'৯৯৯ কে জানান'**
  String get triageNotify999;

  /// No description provided for @triageDoNow.
  ///
  /// In bn, this message translates to:
  /// **'এখনই যা করবেন'**
  String get triageDoNow;

  /// No description provided for @triageCardNotFound.
  ///
  /// In bn, this message translates to:
  /// **'কার্ড পাওয়া যায়নি'**
  String get triageCardNotFound;

  /// No description provided for @triageRouteCpr.
  ///
  /// In bn, this message translates to:
  /// **'সিপিআর শুরু করুন'**
  String get triageRouteCpr;

  /// No description provided for @triageRouteBleeding.
  ///
  /// In bn, this message translates to:
  /// **'রক্তপাত বন্ধ করুন'**
  String get triageRouteBleeding;

  /// No description provided for @triageRouteDrowning.
  ///
  /// In bn, this message translates to:
  /// **'ডুবে যাওয়া — নিষ্কাশন ও সিপিআর'**
  String get triageRouteDrowning;

  /// No description provided for @triageRouteSnakebite.
  ///
  /// In bn, this message translates to:
  /// **'সাপে কামড় — চিকিৎসা সহায়তা নিন'**
  String get triageRouteSnakebite;

  /// No description provided for @triageRouteRecovery.
  ///
  /// In bn, this message translates to:
  /// **'রিকভারি পজিশনে রাখুন'**
  String get triageRouteRecovery;

  /// No description provided for @triageRouteBurn.
  ///
  /// In bn, this message translates to:
  /// **'গুরুতর পোড়া — ঠাণ্ডা পানি দিন'**
  String get triageRouteBurn;

  /// No description provided for @triageRouteChoking.
  ///
  /// In bn, this message translates to:
  /// **'শ্বাসরোধ — পিঠে ও পেটে চাপ দিন'**
  String get triageRouteChoking;

  /// No description provided for @triageRouteEscalation.
  ///
  /// In bn, this message translates to:
  /// **'জরুরি সহায়তা প্রয়োজন'**
  String get triageRouteEscalation;

  /// No description provided for @triageStepCpr.
  ///
  /// In bn, this message translates to:
  /// **'বুকে ১১০ বার/মিনিট হারে চাপ দিন। ৩০:২ অনুপাত।'**
  String get triageStepCpr;

  /// No description provided for @triageStepBleeding.
  ///
  /// In bn, this message translates to:
  /// **'চাপ দিয়ে রক্তপাত বন্ধ করুন। পরিষ্কার কাপড় দিয়ে চাপ।'**
  String get triageStepBleeding;

  /// No description provided for @triageStepDrowning.
  ///
  /// In bn, this message translates to:
  /// **'শ্বাস নিচ্ছে কিনা দেখুন। প্রয়োজনে সিপিআর।'**
  String get triageStepDrowning;

  /// No description provided for @triageStepSnakebite.
  ///
  /// In bn, this message translates to:
  /// **'শান্ত রাখুন, কাটা বা চুষবেন না। দ্রুত হাসপাতালে।'**
  String get triageStepSnakebite;

  /// No description provided for @triageStepRecovery.
  ///
  /// In bn, this message translates to:
  /// **'পাশ ফিরিয়ে শুইয়ে দিন। শ্বাস পরীক্ষা করুন।'**
  String get triageStepRecovery;

  /// No description provided for @triageStepBurn.
  ///
  /// In bn, this message translates to:
  /// **'কুসুম-গরম পানি ২০ মিনিট চলমান রাখুন।'**
  String get triageStepBurn;

  /// No description provided for @triageStepChoking.
  ///
  /// In bn, this message translates to:
  /// **'পিঠে ৫ বার চাপ, তারপর পেটে ৫ বার হিথলিক।'**
  String get triageStepChoking;

  /// No description provided for @triageStepEscalation.
  ///
  /// In bn, this message translates to:
  /// **'৯৯৯ কল করুন বা পরিবার/প্রতিবেশীদের সাহায্য নিন।'**
  String get triageStepEscalation;

  /// No description provided for @triageStateOngoing.
  ///
  /// In bn, this message translates to:
  /// **'চলমান'**
  String get triageStateOngoing;

  /// No description provided for @triageStateUnknown.
  ///
  /// In bn, this message translates to:
  /// **'অজানা'**
  String get triageStateUnknown;

  /// No description provided for @triageSummaryPrefix.
  ///
  /// In bn, this message translates to:
  /// **'ট্রায়াজ:'**
  String get triageSummaryPrefix;

  /// No description provided for @triageSummaryTime.
  ///
  /// In bn, this message translates to:
  /// **'সময়:'**
  String get triageSummaryTime;

  /// No description provided for @triageSummaryQuestions.
  ///
  /// In bn, this message translates to:
  /// **'প্রশ্ন:'**
  String get triageSummaryQuestions;

  /// No description provided for @triageSummaryYes.
  ///
  /// In bn, this message translates to:
  /// **'হ্যাঁ'**
  String get triageSummaryYes;

  /// No description provided for @triageSummaryNo.
  ///
  /// In bn, this message translates to:
  /// **'না'**
  String get triageSummaryNo;

  /// No description provided for @triageSummaryStatus.
  ///
  /// In bn, this message translates to:
  /// **'অবস্থা:'**
  String get triageSummaryStatus;

  /// No description provided for @triageRouteNameCpr.
  ///
  /// In bn, this message translates to:
  /// **'সিপিআর'**
  String get triageRouteNameCpr;

  /// No description provided for @triageRouteNameBleeding.
  ///
  /// In bn, this message translates to:
  /// **'রক্তপাত'**
  String get triageRouteNameBleeding;

  /// No description provided for @triageRouteNameDrowning.
  ///
  /// In bn, this message translates to:
  /// **'ডুবে যাওয়া'**
  String get triageRouteNameDrowning;

  /// No description provided for @triageRouteNameSnakebite.
  ///
  /// In bn, this message translates to:
  /// **'সাপে কামড়'**
  String get triageRouteNameSnakebite;

  /// No description provided for @triageRouteNameRecovery.
  ///
  /// In bn, this message translates to:
  /// **'রিকভারি পজিশন'**
  String get triageRouteNameRecovery;

  /// No description provided for @triageRouteNameBurn.
  ///
  /// In bn, this message translates to:
  /// **'গুরুতর পোড়া'**
  String get triageRouteNameBurn;

  /// No description provided for @triageRouteNameChoking.
  ///
  /// In bn, this message translates to:
  /// **'শ্বাসরোধ'**
  String get triageRouteNameChoking;

  /// No description provided for @triageRouteNameEscalation.
  ///
  /// In bn, this message translates to:
  /// **'সাধারণ জরুরি'**
  String get triageRouteNameEscalation;

  /// No description provided for @triageSummarySos.
  ///
  /// In bn, this message translates to:
  /// **'ট্রায়াজ: {route}\nসময়: {time}\nপ্রশ্ন: {count} (হ্যাঁ {yes} / না {no})'**
  String triageSummarySos(
    String route,
    String time,
    int count,
    int yes,
    int no,
  );

  /// No description provided for @triageShareableSos.
  ///
  /// In bn, this message translates to:
  /// **'ট্রায়াজ: {route}\nসময়: {time}\nপ্রশ্ন: {count} (হ্যাঁ {yes} / না {no})'**
  String triageShareableSos(
    String route,
    String time,
    int count,
    int yes,
    int no,
  );

  /// No description provided for @modelRamLabel.
  ///
  /// In bn, this message translates to:
  /// **'আপনার RAM: {ram}'**
  String modelRamLabel(String ram);

  /// No description provided for @modelRamLow.
  ///
  /// In bn, this message translates to:
  /// **'৪GB বা কম'**
  String get modelRamLow;

  /// No description provided for @modelRamMid.
  ///
  /// In bn, this message translates to:
  /// **'৬-৮GB'**
  String get modelRamMid;

  /// No description provided for @modelRamHigh.
  ///
  /// In bn, this message translates to:
  /// **'১২GB+'**
  String get modelRamHigh;

  /// No description provided for @modelTierLight.
  ///
  /// In bn, this message translates to:
  /// **'হালকা'**
  String get modelTierLight;

  /// No description provided for @modelTierMedium.
  ///
  /// In bn, this message translates to:
  /// **'মাঝারি'**
  String get modelTierMedium;

  /// No description provided for @modelTierPowerful.
  ///
  /// In bn, this message translates to:
  /// **'শক্তিশালী'**
  String get modelTierPowerful;

  /// No description provided for @modelStorageUsed.
  ///
  /// In bn, this message translates to:
  /// **'ডাউনলোড করা: {size}'**
  String modelStorageUsed(String size);

  /// No description provided for @modelBadgeExpected.
  ///
  /// In bn, this message translates to:
  /// **'✅ প্রত্যাশিত'**
  String get modelBadgeExpected;

  /// No description provided for @modelBadgeAdvanced.
  ///
  /// In bn, this message translates to:
  /// **'⚠️ উন্নত'**
  String get modelBadgeAdvanced;

  /// No description provided for @modelBadgeHeavy.
  ///
  /// In bn, this message translates to:
  /// **'⚠️ ভারী'**
  String get modelBadgeHeavy;

  /// No description provided for @modelRetry.
  ///
  /// In bn, this message translates to:
  /// **'আবার চেষ্টা করুন'**
  String get modelRetry;

  /// No description provided for @modelDownload.
  ///
  /// In bn, this message translates to:
  /// **'ডাউনলোড'**
  String get modelDownload;

  /// No description provided for @modelActivate.
  ///
  /// In bn, this message translates to:
  /// **'সক্রিয় করুন'**
  String get modelActivate;

  /// No description provided for @modelActiveStatus.
  ///
  /// In bn, this message translates to:
  /// **'মডেল সক্রিয় আছে'**
  String get modelActiveStatus;

  /// No description provided for @modelDelete.
  ///
  /// In bn, this message translates to:
  /// **'মুছুন'**
  String get modelDelete;

  /// No description provided for @modelDownloadStarted.
  ///
  /// In bn, this message translates to:
  /// **'{label} ডাউনলোড শুরু হয়েছে — পটভূমিতে চলবে।'**
  String modelDownloadStarted(String label);

  /// No description provided for @modelDeleteTitle.
  ///
  /// In bn, this message translates to:
  /// **'মডেল মুছে ফেলবেন?'**
  String get modelDeleteTitle;

  /// No description provided for @modelDeleteBody.
  ///
  /// In bn, this message translates to:
  /// **'{label} ({size}) মুছে যাবে।'**
  String modelDeleteBody(String label, String size);

  /// No description provided for @modelCancel.
  ///
  /// In bn, this message translates to:
  /// **'বাতিল'**
  String get modelCancel;

  /// No description provided for @modelDeleted.
  ///
  /// In bn, this message translates to:
  /// **'মডেল মুছে ফেলা হয়েছে'**
  String get modelDeleted;

  /// No description provided for @homeAiTools.
  ///
  /// In bn, this message translates to:
  /// **'AI টুলস'**
  String get homeAiTools;

  /// No description provided for @homeToolPlan.
  ///
  /// In bn, this message translates to:
  /// **'পরিকল্পনা'**
  String get homeToolPlan;

  /// No description provided for @homeToolKit.
  ///
  /// In bn, this message translates to:
  /// **'কিট'**
  String get homeToolKit;

  /// No description provided for @homeToolRisk.
  ///
  /// In bn, this message translates to:
  /// **'ঝুঁকি'**
  String get homeToolRisk;

  /// No description provided for @homeToolDamageScan.
  ///
  /// In bn, this message translates to:
  /// **'ড্যামেজ স্ক্যান'**
  String get homeToolDamageScan;

  /// No description provided for @homeToolSummary.
  ///
  /// In bn, this message translates to:
  /// **'সারাংশ'**
  String get homeToolSummary;

  /// No description provided for @homeTipTitle.
  ///
  /// In bn, this message translates to:
  /// **'আজকের পরামর্শ'**
  String get homeTipTitle;

  /// No description provided for @hazardsCardHeader.
  ///
  /// In bn, this message translates to:
  /// **'সতর্কতা'**
  String get hazardsCardHeader;

  /// No description provided for @hazardsLoading.
  ///
  /// In bn, this message translates to:
  /// **'তথ্য আনা হচ্ছে…'**
  String get hazardsLoading;

  /// No description provided for @hazardsLoadError.
  ///
  /// In bn, this message translates to:
  /// **'তথ্য আনা যায়নি। আবার চেষ্টা করুন।'**
  String get hazardsLoadError;

  /// No description provided for @hazardsNoAlerts.
  ///
  /// In bn, this message translates to:
  /// **'এই মুহূর্তে কোনো ঝুঁকি নেই'**
  String get hazardsNoAlerts;

  /// No description provided for @hazardsNearbyBadge.
  ///
  /// In bn, this message translates to:
  /// **'সীমান্তের ওপারে'**
  String get hazardsNearbyBadge;

  /// No description provided for @hazardsShowMore.
  ///
  /// In bn, this message translates to:
  /// **'আরও {count}টি দেখুন'**
  String hazardsShowMore(int count);

  /// No description provided for @shelterAiRiskAssessment.
  ///
  /// In bn, this message translates to:
  /// **'AI ঝুঁকি মূল্যায়ন'**
  String get shelterAiRiskAssessment;

  /// No description provided for @shelterGpsPermissionDenied.
  ///
  /// In bn, this message translates to:
  /// **'GPS অনুমতি দেওয়া হয়নি'**
  String get shelterGpsPermissionDenied;

  /// No description provided for @shelterGpsServiceDisabled.
  ///
  /// In bn, this message translates to:
  /// **'ডিভাইসের লোকেশন সার্ভিস বন্ধ আছে — চালু করুন'**
  String get shelterGpsServiceDisabled;

  /// No description provided for @shelterGpsNotFound.
  ///
  /// In bn, this message translates to:
  /// **'GPS পাওয়া যায়নি'**
  String get shelterGpsNotFound;

  /// No description provided for @shelterGpsUnavailable.
  ///
  /// In bn, this message translates to:
  /// **'সমগ্র বাংলাদেশ দেখানো হচ্ছে — GPS থেকে দূরত্ব নির্ণয় করা যাবে না'**
  String get shelterGpsUnavailable;

  /// No description provided for @shelterOfflineTiles.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন — মানচিত্রের টাইলস লোড হবে না, তবে আশ্রয়কেন্দ্রের অবস্থান দেখা যাচ্ছে'**
  String get shelterOfflineTiles;

  /// No description provided for @shelterNoResults.
  ///
  /// In bn, this message translates to:
  /// **'কোনো আশ্রয়কেন্দ্র পাওয়া যায়নি'**
  String get shelterNoResults;

  /// No description provided for @shelterUnitKm.
  ///
  /// In bn, this message translates to:
  /// **'কিমি'**
  String get shelterUnitKm;

  /// No description provided for @shelterUnitPeople.
  ///
  /// In bn, this message translates to:
  /// **'জন'**
  String get shelterUnitPeople;

  /// No description provided for @shelterNoSearchResults.
  ///
  /// In bn, this message translates to:
  /// **'কোনো ফলাফল পাওয়া যায়নি'**
  String get shelterNoSearchResults;

  /// No description provided for @shelterTryDifferentWords.
  ///
  /// In bn, this message translates to:
  /// **'অন্য শব্দ দিয়ে চেষ্টা করুন'**
  String get shelterTryDifferentWords;

  /// No description provided for @weatherClear.
  ///
  /// In bn, this message translates to:
  /// **'পরিষ্কার'**
  String get weatherClear;

  /// No description provided for @weatherPartlyCloudy.
  ///
  /// In bn, this message translates to:
  /// **'হালকা মেঘলা'**
  String get weatherPartlyCloudy;

  /// No description provided for @weatherCloudy.
  ///
  /// In bn, this message translates to:
  /// **'মেঘাচ্ছন্ন'**
  String get weatherCloudy;

  /// No description provided for @weatherFog.
  ///
  /// In bn, this message translates to:
  /// **'কুয়াশা'**
  String get weatherFog;

  /// No description provided for @weatherDrizzle.
  ///
  /// In bn, this message translates to:
  /// **'গুঁড়ি গুঁড়ি বৃষ্টি'**
  String get weatherDrizzle;

  /// No description provided for @weatherRain.
  ///
  /// In bn, this message translates to:
  /// **'বৃষ্টি'**
  String get weatherRain;

  /// No description provided for @weatherHeavyRain.
  ///
  /// In bn, this message translates to:
  /// **'ভারী বৃষ্টি'**
  String get weatherHeavyRain;

  /// No description provided for @weatherSnow.
  ///
  /// In bn, this message translates to:
  /// **'তুষারপাত'**
  String get weatherSnow;

  /// No description provided for @weatherShowers.
  ///
  /// In bn, this message translates to:
  /// **'বৃষ্টির ঝাপটা'**
  String get weatherShowers;

  /// No description provided for @weatherHeavyShowers.
  ///
  /// In bn, this message translates to:
  /// **'ভারী বর্ষণ'**
  String get weatherHeavyShowers;

  /// No description provided for @weatherStormy.
  ///
  /// In bn, this message translates to:
  /// **'ঝড়ো হাওয়া'**
  String get weatherStormy;

  /// No description provided for @weatherThunderstorm.
  ///
  /// In bn, this message translates to:
  /// **'বজ্রসহ ঝড়'**
  String get weatherThunderstorm;

  /// No description provided for @weatherUnknown.
  ///
  /// In bn, this message translates to:
  /// **'অজানা'**
  String get weatherUnknown;

  /// No description provided for @chatSuggestionOrs.
  ///
  /// In bn, this message translates to:
  /// **'ORS কীভাবে বানাবো?'**
  String get chatSuggestionOrs;

  /// No description provided for @chatSuggestionShelter.
  ///
  /// In bn, this message translates to:
  /// **'নিকটস্থ আশ্রয়কেন্দ্র'**
  String get chatSuggestionShelter;

  /// No description provided for @chatSuggestionSnakebite.
  ///
  /// In bn, this message translates to:
  /// **'সাপে কামড়ালে কী করবো?'**
  String get chatSuggestionSnakebite;

  /// No description provided for @chatSuggestionRumorSnakebite.
  ///
  /// In bn, this message translates to:
  /// **'গুজব: সাপে কামড়ালে কেটে ফেলা ঠিক?'**
  String get chatSuggestionRumorSnakebite;

  /// No description provided for @cardDetailBack.
  ///
  /// In bn, this message translates to:
  /// **'ফিরে যান'**
  String get cardDetailBack;

  /// No description provided for @cardDetailNoSteps.
  ///
  /// In bn, this message translates to:
  /// **'এই কার্ডের জন্য কোনো পদক্ষেপ নেই'**
  String get cardDetailNoSteps;

  /// No description provided for @cardDetailNotFound.
  ///
  /// In bn, this message translates to:
  /// **'কার্ড পাওয়া যায়নি'**
  String get cardDetailNotFound;

  /// No description provided for @emergencyDirDhaka.
  ///
  /// In bn, this message translates to:
  /// **'ঢাকা'**
  String get emergencyDirDhaka;

  /// No description provided for @emergencyDirChattogram.
  ///
  /// In bn, this message translates to:
  /// **'চট্টগ্রাম'**
  String get emergencyDirChattogram;

  /// No description provided for @emergencyDirRajshahi.
  ///
  /// In bn, this message translates to:
  /// **'রাজশাহী'**
  String get emergencyDirRajshahi;

  /// No description provided for @emergencyDirKhulna.
  ///
  /// In bn, this message translates to:
  /// **'খুলনা'**
  String get emergencyDirKhulna;

  /// No description provided for @emergencyDirBarishal.
  ///
  /// In bn, this message translates to:
  /// **'বরিশাল'**
  String get emergencyDirBarishal;

  /// No description provided for @emergencyDirSylhet.
  ///
  /// In bn, this message translates to:
  /// **'সিলেট'**
  String get emergencyDirSylhet;

  /// No description provided for @emergencyDirRangpur.
  ///
  /// In bn, this message translates to:
  /// **'রংপুর'**
  String get emergencyDirRangpur;

  /// No description provided for @emergencyDirMymensingh.
  ///
  /// In bn, this message translates to:
  /// **'ময়মনসিংহ'**
  String get emergencyDirMymensingh;

  /// No description provided for @nationalContactPolice.
  ///
  /// In bn, this message translates to:
  /// **'পুলিশ'**
  String get nationalContactPolice;

  /// No description provided for @nationalContactFireService.
  ///
  /// In bn, this message translates to:
  /// **'ফায়ার সার্ভিস'**
  String get nationalContactFireService;

  /// No description provided for @nationalContactAmbulance.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাম্বুলেন্স'**
  String get nationalContactAmbulance;

  /// No description provided for @nationalContactDisasterMgmt.
  ///
  /// In bn, this message translates to:
  /// **'দুর্যোগ ব্যবস্থাপনা'**
  String get nationalContactDisasterMgmt;

  /// No description provided for @nationalContactRedCrescent.
  ///
  /// In bn, this message translates to:
  /// **'রেড ক্রিসেন্ট'**
  String get nationalContactRedCrescent;

  /// No description provided for @nationalContactHealthHotline.
  ///
  /// In bn, this message translates to:
  /// **'স্বাস্থ্য হটলাইন'**
  String get nationalContactHealthHotline;

  /// No description provided for @safetyDangerFlood.
  ///
  /// In bn, this message translates to:
  /// **'বন্যা'**
  String get safetyDangerFlood;

  /// No description provided for @safetyDangerFire.
  ///
  /// In bn, this message translates to:
  /// **'আগুন'**
  String get safetyDangerFire;

  /// No description provided for @safetyDangerEarthquake.
  ///
  /// In bn, this message translates to:
  /// **'ভূমিকম্প'**
  String get safetyDangerEarthquake;

  /// No description provided for @safetyDangerCyclone.
  ///
  /// In bn, this message translates to:
  /// **'ঘূর্ণিঝড়'**
  String get safetyDangerCyclone;

  /// No description provided for @safetyDangerLandslide.
  ///
  /// In bn, this message translates to:
  /// **'ভূমিধস'**
  String get safetyDangerLandslide;

  /// No description provided for @safetyDangerTrapped.
  ///
  /// In bn, this message translates to:
  /// **'আটকা পড়েছি'**
  String get safetyDangerTrapped;

  /// No description provided for @safetyDangerMedical.
  ///
  /// In bn, this message translates to:
  /// **'চিকিৎসা জরুরি'**
  String get safetyDangerMedical;

  /// No description provided for @safetyDangerViolence.
  ///
  /// In bn, this message translates to:
  /// **'সহিংসতা / অস্থিরতা'**
  String get safetyDangerViolence;

  /// No description provided for @safetyDangerOther.
  ///
  /// In bn, this message translates to:
  /// **'অন্যান্য'**
  String get safetyDangerOther;

  /// No description provided for @damageTitle.
  ///
  /// In bn, this message translates to:
  /// **'AI ড্যামেজ স্ক্যান'**
  String get damageTitle;

  /// No description provided for @damagePhotoError.
  ///
  /// In bn, this message translates to:
  /// **'ছবি নেওয়া যায়নি: {error}'**
  String damagePhotoError(String error);

  /// No description provided for @damageInternetRequired.
  ///
  /// In bn, this message translates to:
  /// **'ড্যামেজ স্ক্যানের জন্য ইন্টারনেট প্রয়োজন।'**
  String get damageInternetRequired;

  /// No description provided for @damageApiKeyRequired.
  ///
  /// In bn, this message translates to:
  /// **'AI ড্যামেজ স্ক্যানের জন্য GEMINI_API_KEY প্রয়োজন।'**
  String get damageApiKeyRequired;

  /// No description provided for @damageAnalyzeError.
  ///
  /// In bn, this message translates to:
  /// **'বিশ্লেষণ করা যায়নি: {error}'**
  String damageAnalyzeError(String error);

  /// No description provided for @damageAiAnalyzing.
  ///
  /// In bn, this message translates to:
  /// **'AI ছবি বিশ্লেষণ করছে…'**
  String get damageAiAnalyzing;

  /// No description provided for @damageIntroBody.
  ///
  /// In bn, this message translates to:
  /// **'একটি ক্ষয়ক্ষতির ছবি তুলুন বা গ্যালারি থেকে নিন।\nAI ছবি দেখে ক্ষয়ক্ষতির ধরন ও তীব্রতা বলবে।'**
  String get damageIntroBody;

  /// No description provided for @damageCamera.
  ///
  /// In bn, this message translates to:
  /// **'ক্যামেরা'**
  String get damageCamera;

  /// No description provided for @damageGallery.
  ///
  /// In bn, this message translates to:
  /// **'গ্যালারি'**
  String get damageGallery;

  /// No description provided for @damageFeatureInfo.
  ///
  /// In bn, this message translates to:
  /// **'এই ফিচারের জন্য ইন্টারনেট ও GEMINI_API_KEY প্রয়োজন।'**
  String get damageFeatureInfo;

  /// No description provided for @damageTypeLabel.
  ///
  /// In bn, this message translates to:
  /// **'ক্ষয়ক্ষতির ধরন'**
  String get damageTypeLabel;

  /// No description provided for @damageDescLabel.
  ///
  /// In bn, this message translates to:
  /// **'বিবরণ'**
  String get damageDescLabel;

  /// No description provided for @damageRecommendLabel.
  ///
  /// In bn, this message translates to:
  /// **'সুপারিশ'**
  String get damageRecommendLabel;

  /// No description provided for @damageScanAnother.
  ///
  /// In bn, this message translates to:
  /// **'আরেকটি ছবি স্ক্যান করুন'**
  String get damageScanAnother;

  /// No description provided for @damageTryAgain.
  ///
  /// In bn, this message translates to:
  /// **'আবার চেষ্টা করুন'**
  String get damageTryAgain;

  /// No description provided for @damageTypeFlood.
  ///
  /// In bn, this message translates to:
  /// **'বন্যা'**
  String get damageTypeFlood;

  /// No description provided for @damageTypeFire.
  ///
  /// In bn, this message translates to:
  /// **'আগুন'**
  String get damageTypeFire;

  /// No description provided for @damageTypeBuildingCollapse.
  ///
  /// In bn, this message translates to:
  /// **'ধসে পড়া ভবন'**
  String get damageTypeBuildingCollapse;

  /// No description provided for @damageTypeFallenTree.
  ///
  /// In bn, this message translates to:
  /// **'পড়ে যাওয়া গাছ'**
  String get damageTypeFallenTree;

  /// No description provided for @damageTypeBlockedRoad.
  ///
  /// In bn, this message translates to:
  /// **'অবরুদ্ধ রাস্তা'**
  String get damageTypeBlockedRoad;

  /// No description provided for @damageTypeElectricalHazard.
  ///
  /// In bn, this message translates to:
  /// **'বৈদ্যুতিক বিপদ'**
  String get damageTypeElectricalHazard;

  /// No description provided for @damageTypeSmoke.
  ///
  /// In bn, this message translates to:
  /// **'ধোঁয়া'**
  String get damageTypeSmoke;

  /// No description provided for @damageTypeOther.
  ///
  /// In bn, this message translates to:
  /// **'অন্যান্য'**
  String get damageTypeOther;

  /// No description provided for @damageTypeUnknown.
  ///
  /// In bn, this message translates to:
  /// **'অজানা'**
  String get damageTypeUnknown;

  /// No description provided for @damageSeverityLow.
  ///
  /// In bn, this message translates to:
  /// **'নিম্ন'**
  String get damageSeverityLow;

  /// No description provided for @damageSeverityMedium.
  ///
  /// In bn, this message translates to:
  /// **'মাঝারি'**
  String get damageSeverityMedium;

  /// No description provided for @damageSeverityHigh.
  ///
  /// In bn, this message translates to:
  /// **'উচ্চ'**
  String get damageSeverityHigh;

  /// No description provided for @damageSeverityVeryHigh.
  ///
  /// In bn, this message translates to:
  /// **'অত্যন্ত উচ্চ'**
  String get damageSeverityVeryHigh;

  /// No description provided for @damageSeverityUnknown.
  ///
  /// In bn, this message translates to:
  /// **'অজানা'**
  String get damageSeverityUnknown;

  /// No description provided for @damageDefaultRecommendation.
  ///
  /// In bn, this message translates to:
  /// **'অতিরিক্ত তথ্যের জন্য আশ্রয় ট্যাব ব্যবহার করুন।'**
  String get damageDefaultRecommendation;

  /// No description provided for @damageParseFailure.
  ///
  /// In bn, this message translates to:
  /// **'ছবি বিশ্লেষণ করা যায়নি।'**
  String get damageParseFailure;

  /// No description provided for @plannerTitle.
  ///
  /// In bn, this message translates to:
  /// **'AI দুর্যোগ পরিকল্পনা'**
  String get plannerTitle;

  /// No description provided for @plannerFamilyInfo.
  ///
  /// In bn, this message translates to:
  /// **'পরিবারের তথ্য'**
  String get plannerFamilyInfo;

  /// No description provided for @plannerTotalMembers.
  ///
  /// In bn, this message translates to:
  /// **'মোট সদস্য'**
  String get plannerTotalMembers;

  /// No description provided for @plannerChildren.
  ///
  /// In bn, this message translates to:
  /// **'শিশু'**
  String get plannerChildren;

  /// No description provided for @plannerElderly.
  ///
  /// In bn, this message translates to:
  /// **'প্রবীণ'**
  String get plannerElderly;

  /// No description provided for @plannerHomeType.
  ///
  /// In bn, this message translates to:
  /// **'ঘরের ধরন'**
  String get plannerHomeType;

  /// No description provided for @plannerFloorNumber.
  ///
  /// In bn, this message translates to:
  /// **'তলা নম্বর'**
  String get plannerFloorNumber;

  /// No description provided for @plannerMedicalConditions.
  ///
  /// In bn, this message translates to:
  /// **'চিকিৎসা অবস্থা (কমা দিয়ে আলাদা করুন)'**
  String get plannerMedicalConditions;

  /// No description provided for @plannerMedicalHint.
  ///
  /// In bn, this message translates to:
  /// **'যেমন: ডায়াবেটিস, হাঁপানি'**
  String get plannerMedicalHint;

  /// No description provided for @plannerOther.
  ///
  /// In bn, this message translates to:
  /// **'অন্যান্য'**
  String get plannerOther;

  /// No description provided for @plannerHasPets.
  ///
  /// In bn, this message translates to:
  /// **'পোষা প্রাণী আছে'**
  String get plannerHasPets;

  /// No description provided for @plannerNearbyRiver.
  ///
  /// In bn, this message translates to:
  /// **'নিকটবর্তী নদী'**
  String get plannerNearbyRiver;

  /// No description provided for @plannerNearCoast.
  ///
  /// In bn, this message translates to:
  /// **'সমুদ্রতীরের কাছে'**
  String get plannerNearCoast;

  /// No description provided for @plannerGenerate.
  ///
  /// In bn, this message translates to:
  /// **'পরিকল্পনা তৈরি করুন'**
  String get plannerGenerate;

  /// No description provided for @plannerAiPlan.
  ///
  /// In bn, this message translates to:
  /// **'AI পরিকল্পনা'**
  String get plannerAiPlan;

  /// No description provided for @plannerNewPlan.
  ///
  /// In bn, this message translates to:
  /// **'নতুন পরিকল্পনা'**
  String get plannerNewPlan;

  /// No description provided for @plannerDone.
  ///
  /// In bn, this message translates to:
  /// **'সম্পন্ন'**
  String get plannerDone;

  /// No description provided for @plannerHomeTinShed.
  ///
  /// In bn, this message translates to:
  /// **'টিনের ঘর'**
  String get plannerHomeTinShed;

  /// No description provided for @plannerHomePucca.
  ///
  /// In bn, this message translates to:
  /// **'পাকা বাড়ি'**
  String get plannerHomePucca;

  /// No description provided for @plannerHomeFlat.
  ///
  /// In bn, this message translates to:
  /// **'ফ্ল্যাট'**
  String get plannerHomeFlat;

  /// No description provided for @plannerHomeUnknown.
  ///
  /// In bn, this message translates to:
  /// **'অজানা'**
  String get plannerHomeUnknown;

  /// No description provided for @riskTitle.
  ///
  /// In bn, this message translates to:
  /// **'AI ঝুঁকি মূল্যায়ন'**
  String get riskTitle;

  /// No description provided for @riskHomeType.
  ///
  /// In bn, this message translates to:
  /// **'ঘরের ধরন'**
  String get riskHomeType;

  /// No description provided for @riskFloodHistory.
  ///
  /// In bn, this message translates to:
  /// **'পূর্ববর্তী বন্যার ইতিহাস'**
  String get riskFloodHistory;

  /// No description provided for @riskElevation.
  ///
  /// In bn, this message translates to:
  /// **'এলাকার উচ্চতা'**
  String get riskElevation;

  /// No description provided for @riskOther.
  ///
  /// In bn, this message translates to:
  /// **'অন্যান্য'**
  String get riskOther;

  /// No description provided for @riskNearbyRiver.
  ///
  /// In bn, this message translates to:
  /// **'নিকটবর্তী নদী'**
  String get riskNearbyRiver;

  /// No description provided for @riskNearCoast.
  ///
  /// In bn, this message translates to:
  /// **'সমুদ্রতীরের কাছে'**
  String get riskNearCoast;

  /// No description provided for @riskHasElderly.
  ///
  /// In bn, this message translates to:
  /// **'পরিবারে প্রবীণ আছে'**
  String get riskHasElderly;

  /// No description provided for @riskHasChildren.
  ///
  /// In bn, this message translates to:
  /// **'পরিবারে শিশু আছে'**
  String get riskHasChildren;

  /// No description provided for @riskAssessButton.
  ///
  /// In bn, this message translates to:
  /// **'ঝুঁকি মূল্যায়ন করুন'**
  String get riskAssessButton;

  /// No description provided for @riskScoreDenominator.
  ///
  /// In bn, this message translates to:
  /// **'/ ১০'**
  String get riskScoreDenominator;

  /// No description provided for @riskLevelHigh.
  ///
  /// In bn, this message translates to:
  /// **'উচ্চ ঝুঁকি'**
  String get riskLevelHigh;

  /// No description provided for @riskLevelMedium.
  ///
  /// In bn, this message translates to:
  /// **'মাঝারি ঝুঁকি'**
  String get riskLevelMedium;

  /// No description provided for @riskLevelLow.
  ///
  /// In bn, this message translates to:
  /// **'কম ঝুঁকি'**
  String get riskLevelLow;

  /// No description provided for @riskScoreLabel.
  ///
  /// In bn, this message translates to:
  /// **'ঝুঁকি স্কোর'**
  String get riskScoreLabel;

  /// No description provided for @riskRetry.
  ///
  /// In bn, this message translates to:
  /// **'পুনরায়'**
  String get riskRetry;

  /// No description provided for @riskDone.
  ///
  /// In bn, this message translates to:
  /// **'সম্পন্ন'**
  String get riskDone;

  /// No description provided for @riskTimeJustNow.
  ///
  /// In bn, this message translates to:
  /// **'এইমাত্র'**
  String get riskTimeJustNow;

  /// No description provided for @riskTimeMinutesAgo.
  ///
  /// In bn, this message translates to:
  /// **'{count} মিনিট আগে'**
  String riskTimeMinutesAgo(int count);

  /// No description provided for @riskTimeHoursAgo.
  ///
  /// In bn, this message translates to:
  /// **'{count} ঘণ্টা আগে'**
  String riskTimeHoursAgo(int count);

  /// No description provided for @riskTimeDaysAgo.
  ///
  /// In bn, this message translates to:
  /// **'{count} দিন আগে'**
  String riskTimeDaysAgo(int count);

  /// No description provided for @kitTitle.
  ///
  /// In bn, this message translates to:
  /// **'AI জরুরি কিট'**
  String get kitTitle;

  /// No description provided for @kitGenerateButton.
  ///
  /// In bn, this message translates to:
  /// **'কিট তৈরি করুন'**
  String get kitGenerateButton;

  /// No description provided for @kitAiKit.
  ///
  /// In bn, this message translates to:
  /// **'AI কিট'**
  String get kitAiKit;

  /// No description provided for @kitRetry.
  ///
  /// In bn, this message translates to:
  /// **'পুনরায়'**
  String get kitRetry;

  /// No description provided for @kitDone.
  ///
  /// In bn, this message translates to:
  /// **'সম্পন্ন'**
  String get kitDone;

  /// No description provided for @kitEditFamily.
  ///
  /// In bn, this message translates to:
  /// **'সম্পাদনা'**
  String get kitEditFamily;

  /// No description provided for @kitMoreOptions.
  ///
  /// In bn, this message translates to:
  /// **'আরও অপশন'**
  String get kitMoreOptions;

  /// No description provided for @kitSummaryMembers.
  ///
  /// In bn, this message translates to:
  /// **'{size} জন'**
  String kitSummaryMembers(int size);

  /// No description provided for @kitSummaryChildren.
  ///
  /// In bn, this message translates to:
  /// **'{count} শিশু'**
  String kitSummaryChildren(int count);

  /// No description provided for @kitSummaryElderly.
  ///
  /// In bn, this message translates to:
  /// **'{count} প্রবীণ'**
  String kitSummaryElderly(int count);

  /// No description provided for @kitFamilySizeHint.
  ///
  /// In bn, this message translates to:
  /// **'আপনার পরিবারে কতজন আছেন?'**
  String get kitFamilySizeHint;

  /// No description provided for @familyHomeTypeTinShed.
  ///
  /// In bn, this message translates to:
  /// **'টিনের ঘর'**
  String get familyHomeTypeTinShed;

  /// No description provided for @familyHomeTypePucca.
  ///
  /// In bn, this message translates to:
  /// **'পাকা বাড়ি'**
  String get familyHomeTypePucca;

  /// No description provided for @familyHomeTypeFlat.
  ///
  /// In bn, this message translates to:
  /// **'ফ্ল্যাট'**
  String get familyHomeTypeFlat;

  /// No description provided for @familyHomeTypeUnknown.
  ///
  /// In bn, this message translates to:
  /// **'অজানা'**
  String get familyHomeTypeUnknown;

  /// No description provided for @adminTimeJustNow.
  ///
  /// In bn, this message translates to:
  /// **'এইমাত্র'**
  String get adminTimeJustNow;

  /// No description provided for @adminTimeMinutesAgo.
  ///
  /// In bn, this message translates to:
  /// **'{count} মিনিট আগে'**
  String adminTimeMinutesAgo(int count);

  /// No description provided for @adminTimeHoursAgo.
  ///
  /// In bn, this message translates to:
  /// **'{count} ঘণ্টা আগে'**
  String adminTimeHoursAgo(int count);

  /// No description provided for @adminTimeDaysAgo.
  ///
  /// In bn, this message translates to:
  /// **'{count} দিন আগে'**
  String adminTimeDaysAgo(int count);

  /// No description provided for @adminWriteMessage.
  ///
  /// In bn, this message translates to:
  /// **'বার্তা লিখুন…'**
  String get adminWriteMessage;

  /// No description provided for @adminDetailsLink.
  ///
  /// In bn, this message translates to:
  /// **'বিস্তারিত'**
  String get adminDetailsLink;

  /// No description provided for @adminSystemSummary.
  ///
  /// In bn, this message translates to:
  /// **'সিস্টেম সারসংক্ষেপ'**
  String get adminSystemSummary;

  /// No description provided for @onboardingYourName.
  ///
  /// In bn, this message translates to:
  /// **'আপনার নাম'**
  String get onboardingYourName;

  /// No description provided for @onboardingNameDesc.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন মেসেজিং এবং জরুরি যোগাযোগের জন্য আপনার নাম সেট করতে পারেন। এটি ঐচ্ছিক।'**
  String get onboardingNameDesc;

  /// No description provided for @onboardingNameLabel.
  ///
  /// In bn, this message translates to:
  /// **'নাম'**
  String get onboardingNameLabel;

  /// No description provided for @onboardingNameHint.
  ///
  /// In bn, this message translates to:
  /// **'আপনার নাম লিখুন'**
  String get onboardingNameHint;

  /// No description provided for @chatNoAnswer.
  ///
  /// In bn, this message translates to:
  /// **'আমার কাছে এই প্রশ্নের উত্তর নেই। ৯৯৯ এ কল করুন।'**
  String get chatNoAnswer;

  /// No description provided for @cloudAiNoAnswer.
  ///
  /// In bn, this message translates to:
  /// **'কোনো উত্তর পাওয়া যায়নি।'**
  String get cloudAiNoAnswer;

  /// No description provided for @settingsDefaultUsername.
  ///
  /// In bn, this message translates to:
  /// **'ব্যবহারকারী'**
  String get settingsDefaultUsername;

  /// No description provided for @cardAiButton.
  ///
  /// In bn, this message translates to:
  /// **'এআই-তে জিজ্ঞাসা করুন'**
  String get cardAiButton;

  /// No description provided for @situationTitle.
  ///
  /// In bn, this message translates to:
  /// **'AI পরিস্থিতি সারাংশ'**
  String get situationTitle;

  /// Intro line on the AI situation summary screen
  ///
  /// In bn, this message translates to:
  /// **'{count} টি সাম্প্রতিক প্রতিবেদনের ভিত্তিতে পরিস্থিতির সারাংশ তৈরি করুন।'**
  String situationIntro(String count);

  /// No description provided for @situationGenerate.
  ///
  /// In bn, this message translates to:
  /// **'সারাংশ তৈরি করুন'**
  String get situationGenerate;

  /// No description provided for @situationResultHeading.
  ///
  /// In bn, this message translates to:
  /// **'AI সারাংশ'**
  String get situationResultHeading;

  /// No description provided for @situationRetry.
  ///
  /// In bn, this message translates to:
  /// **'পুনরায়'**
  String get situationRetry;

  /// No description provided for @situationDone.
  ///
  /// In bn, this message translates to:
  /// **'সম্পন্ন'**
  String get situationDone;

  /// No description provided for @modelInfoParamsE2b.
  ///
  /// In bn, this message translates to:
  /// **'২ বিলিয়ন'**
  String get modelInfoParamsE2b;

  /// No description provided for @modelInfoParamsE4b.
  ///
  /// In bn, this message translates to:
  /// **'৪ বিলিয়ন'**
  String get modelInfoParamsE4b;

  /// No description provided for @modelInfoRamE2b.
  ///
  /// In bn, this message translates to:
  /// **'~২.৫ GB'**
  String get modelInfoRamE2b;

  /// No description provided for @modelInfoRamE4b.
  ///
  /// In bn, this message translates to:
  /// **'~৫ GB'**
  String get modelInfoRamE4b;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
