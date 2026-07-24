// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Shongjog';

  @override
  String get splashTitle => 'Shongjog';

  @override
  String get pageNotFound => 'Not Found';

  @override
  String get pageNotFoundDesc => 'This page could not be found.';

  @override
  String get navHome => 'Home';

  @override
  String get navAi => 'AI';

  @override
  String get navCards => 'Cards';

  @override
  String get navShelter => 'Shelter';

  @override
  String get onboardingWelcome => 'Welcome to Shongjog';

  @override
  String get onboardingDesc =>
      'Get offline help during floods, cyclones, or emergencies. Voice chat, quick guidance cards, and shelter info — everything at your fingertips.';

  @override
  String get onboardingPermRequired => 'Permissions Required';

  @override
  String get onboardingMic => 'Microphone';

  @override
  String get onboardingMicDesc => 'To ask questions by voice';

  @override
  String get onboardingGps => 'Location (GPS)';

  @override
  String get onboardingGpsDesc => 'To find nearby shelters';

  @override
  String get onboardingPhone => 'Phone & SMS';

  @override
  String get onboardingPhoneDesc => 'For emergency calls and SOS';

  @override
  String get onboardingPermHint => 'You can change these anytime from Settings';

  @override
  String get onboardingModelTitle => 'AI Model Download';

  @override
  String get onboardingModelDesc =>
      'Download the Gemma 4 E2B model (~1.5 GB) for a fully offline AI assistant.\n\nCloud AI works when online. Offline, you\'ll get quick answers from cards and the knowledge base without cloud AI.';

  @override
  String get onboardingModelHint =>
      'To download the model, go to Settings → AI Model.';

  @override
  String get skip => 'Skip';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get goToHome => 'Go to Home';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeDesc => 'Light, Dark, or follow System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageDesc => 'Change the app language';

  @override
  String get langBn => 'বাংলা';

  @override
  String get langEn => 'English';

  @override
  String get sectionVoice => 'Voice';

  @override
  String get autoRead => 'Auto-read';

  @override
  String get autoReadDesc => 'AI answers will be read aloud automatically';

  @override
  String get voiceInput => 'Voice Input';

  @override
  String get voiceInputDesc => 'Ask questions by speaking';

  @override
  String get soundHint => 'Sound Alert';

  @override
  String get soundHintDesc => 'A chime when AI answer is ready';

  @override
  String get prepTips => 'Preparation Tips';

  @override
  String get prepTipsDesc =>
      'Tip cards on the home screen based on chat history';

  @override
  String get sectionEmergency => 'Emergency';

  @override
  String get emergencyContacts => 'Emergency Contacts';

  @override
  String get emergencyContactsDesc =>
      'National numbers and your personal contacts';

  @override
  String get sectionCampaign => 'Campaign Request';

  @override
  String get campaignRequest => 'Request a Donation/Rescue Campaign';

  @override
  String get campaignRequestDesc => 'Shows on the map after admin approval';

  @override
  String get sectionAiModel => 'AI Model';

  @override
  String get sectionDiagnostics => 'Diagnostics';

  @override
  String get kbVersion => 'Knowledge Base Version';

  @override
  String get offlineAiFailed => 'Offline AI Failed to Start';

  @override
  String get offlineAiError => 'Offline AI Error';

  @override
  String get close => 'Close';

  @override
  String get sectionInfo => 'Info';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get clearCacheDesc => 'Delete chat history';

  @override
  String get aboutApp => 'About';

  @override
  String get aboutAppDesc => 'Credits, license, version';

  @override
  String get adminLogin => 'Admin Login';

  @override
  String get adminLoginDesc => 'Broadcast messages and management';

  @override
  String get clearCacheConfirmTitle => 'Clear Cache?';

  @override
  String get clearCacheConfirmDesc =>
      'All chat history will be deleted. This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get campaignDialogTitle => 'Submit Campaign Request';

  @override
  String get campaignTypeLabel => 'Campaign Type';

  @override
  String get campaignTypeValidator => 'Select a type';

  @override
  String get campaignLocationSelected => 'Location Selected';

  @override
  String get campaignLocationPrompt => 'Select location from the map';

  @override
  String get campaignLocationTap => 'Tap to pin on the map';

  @override
  String get campaignAddress => 'Address/Place';

  @override
  String get campaignAddressHint => 'e.g., Dhaka Medical College Hospital';

  @override
  String get campaignAddressValidator => 'Enter an address';

  @override
  String get campaignLandmark => 'Clear Address/Landmark';

  @override
  String get campaignLandmarkHint => 'e.g., beside the mosque, shop no. 12';

  @override
  String get campaignDescLabel => 'Description (optional)';

  @override
  String get campaignDescHint => 'Campaign goal, time, contact number, etc.';

  @override
  String get campaignLocationRequired => 'Select location from the map';

  @override
  String get campaignSubmitted => 'Campaign request submitted';

  @override
  String get campaignSubmit => 'Submit';

  @override
  String get profileSet => 'Set Profile';

  @override
  String get emergencyCall => 'Emergency Call';

  @override
  String get notificationsTooltip => 'Notifications';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get dataReady => 'Data Ready';

  @override
  String get emergencyCards => 'Emergency Cards';

  @override
  String emergencyCardsCount(Object count) {
    return '$count quick guidance cards';
  }

  @override
  String get nearbyShelter => 'Nearby Shelter';

  @override
  String get shelterFromGps => 'Shelters via GPS';

  @override
  String get emergencyNumbers => 'Emergency Numbers';

  @override
  String get emergencyDirectoryDesc =>
      'Offline directory — national & divisional hotlines';

  @override
  String get imSafe => 'I\'m Safe';

  @override
  String get imSafeDesc => 'Notify via mesh and SMS';

  @override
  String get triageWizard => 'Triage Wizard';

  @override
  String get firstAid => 'First Aid';

  @override
  String get todaysTip => 'Today\'s Tip';

  @override
  String get offlineMessage => 'Offline Message';

  @override
  String get offlineMessageDesc => 'Talk to nearby people via Wi-Fi';

  @override
  String modelDownloadProgress(Object progress) {
    return 'Model Download $progress';
  }

  @override
  String get modelDownloading => 'Running in background';

  @override
  String get modelReady => 'Model ready — offline AI is now active.';

  @override
  String get downloadFailed => 'Download failed — try again from Settings.';

  @override
  String get aboutTitle => 'Sources';

  @override
  String get aboutBrand => 'Shongjog';

  @override
  String get aboutTagline => 'Offline Emergency Help — in Bangla';

  @override
  String get aboutDescription =>
      'All guidance in Shongjog is collected and verified from the trusted sources below. The app never diagnoses or prescribes — it only provides general assistance.';

  @override
  String get aboutEmergencyNote =>
      'In emergencies, always call 999 or go to the nearest hospital.';

  @override
  String get contactsTitle => 'Emergency Contacts';

  @override
  String get panicHeroTitle => 'Emergency Call (999)';

  @override
  String get panicHeroSubtitle => 'Slide to confirm';

  @override
  String get nationalNumbers => 'National Emergency Numbers';

  @override
  String get myContacts => 'My Contacts';

  @override
  String get addCustomContact => 'Add your personal emergency contacts';

  @override
  String get addContact => 'Add';

  @override
  String get nameAndNumberRequired => 'Enter name and number';

  @override
  String get newContact => 'New Contact';

  @override
  String get nameLabel => 'Name';

  @override
  String get nameHint => 'e.g., Dr. Ahmed';

  @override
  String get phoneLabel => 'Phone Number';

  @override
  String get phoneHint => '01XXXXXXXXX';

  @override
  String get phonePrefix => '+88 ';

  @override
  String get categoryLabel => 'Category';

  @override
  String get save => 'Save';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get noNewMessages => 'No new messages';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(Object count) {
    return '$count minutes ago';
  }

  @override
  String hoursAgo(Object count) {
    return '$count hours ago';
  }

  @override
  String get allDivisions => 'All';

  @override
  String get noNumbersInDivision => 'No numbers found in this division';

  @override
  String get callTooltip => 'Call';

  @override
  String get safeBeaconTitle => 'I\'m Safe';

  @override
  String get safeBeaconDesc => 'Let your family and contacts know you\'re okay';

  @override
  String get safeBeaconButton => 'I\'m Safe';

  @override
  String lastSent(Object count) {
    return 'Last sent: $count';
  }

  @override
  String pendingWait(Object count) {
    return '$count pending — will send when connected';
  }

  @override
  String beaconSentPending(Object count) {
    return 'Beacon sent. $count pending.';
  }

  @override
  String smsSent(Object count) {
    return '$count SMS sent.';
  }

  @override
  String willNotifyOnReconnect(Object count) {
    return '$count will be notified when connected.';
  }

  @override
  String get chatTitle => 'AI Assistant';

  @override
  String get chatStatusCorpus => 'Offline (Knowledge Base)';

  @override
  String get chatStatusCloud => 'Cloud AI (Gemma 4)';

  @override
  String get chatStatusLocal => 'Offline AI (Gemma 4)';

  @override
  String get chatEmergencyCall => 'Emergency Call';

  @override
  String get chatLoading => 'Preparing data...';

  @override
  String get chatError => 'An error occurred. Please call 999.';

  @override
  String get chatThinking => 'Thinking...';

  @override
  String get chatListening => 'Listening...';

  @override
  String get chatEmptyPrompt => 'Ask or type your emergency question';

  @override
  String get chatRetry => 'Try again';

  @override
  String get chatCall999 => '999 Call';

  @override
  String get chatQuickCards => 'View quick guidance cards';

  @override
  String get chatVoiceInputDisabled => 'Enable voice input in Settings';

  @override
  String get chatTryAgain => 'Try again';

  @override
  String get chatMicPermission =>
      'Microphone permission denied. Tap to open Settings.';

  @override
  String get meshTitle => 'Offline Communication';

  @override
  String meshDeviceCount(Object count) {
    return '$count devices';
  }

  @override
  String get meshConnecting => 'Connecting via Wi-Fi...';

  @override
  String get meshSearching =>
      'Searching for nearby devices...\nKeep Wi-Fi on. If Shongjog\nusers are nearby, they\'ll appear here.';

  @override
  String get meshWifiOff => 'Wi-Fi is off — turn it on and try again';

  @override
  String get meshPermissions =>
      'Wi-Fi and permissions required — grant permissions in Settings';

  @override
  String get meshStartFailed => 'Could not start mesh — check if Wi-Fi is on';

  @override
  String get meshRecordingFailed =>
      'Could not start recording — grant microphone permission';

  @override
  String get meshBroadcastAll => 'Will broadcast to all';

  @override
  String get meshHint => 'Type a message...';

  @override
  String get meshNoDevice => 'No device connected — message not sent';

  @override
  String get meshConnected => 'Connected';

  @override
  String get meshReconnecting => 'Reconnecting...';

  @override
  String get meshDisconnected => 'Disconnected';

  @override
  String get weatherNoInternet => 'No internet connection';

  @override
  String get weatherNoLocation => 'No location — default Dhaka';

  @override
  String get weatherFetchError => 'Could not get weather data from server';

  @override
  String weatherTodayLabel(Object condition) {
    return 'Weather · Today · $condition';
  }

  @override
  String get weatherTapToView => 'Tap to view weather';

  @override
  String get weatherLoading => 'Weather — Loading';

  @override
  String get weatherFallbackLabel => '📍 Dhaka (default)';

  @override
  String get weatherLocationRetry => 'Retry location';
}
