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
  /// **'আমি নিরাপদ আছি'**
  String get imSafe;

  /// No description provided for @imSafeDesc.
  ///
  /// In bn, this message translates to:
  /// **'মেশ ও এসএমএস দিয়ে জানান'**
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
