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

  @override
  String get meshConnectionRequest => 'New Connection Request';

  @override
  String meshWantsToConnect(String name) {
    return '$name wants to connect with you.';
  }

  @override
  String get meshReject => 'Reject';

  @override
  String get meshAccept => 'Accept';

  @override
  String get airQualityTitle => 'Air Quality';

  @override
  String get fetchingData => 'Fetching data…';

  @override
  String get failedToFetchTryAgain => 'Failed to fetch. Try again.';

  @override
  String get airGood => 'Good';

  @override
  String get airModerate => 'Moderate';

  @override
  String get airUnhealthySensitive => 'Unhealthy for sensitive';

  @override
  String get airUnhealthy => 'Unhealthy';

  @override
  String get airVeryUnhealthy => 'Very Unhealthy';

  @override
  String get marineTitle => 'Marine Waves';

  @override
  String get maxWave => 'Max Wave';

  @override
  String get meter => 'm';

  @override
  String get meterShort => 'm';

  @override
  String get waveCalm => 'Calm';

  @override
  String get waveModerate => 'Moderate';

  @override
  String get waveRough => 'Rough';

  @override
  String get waveVeryRough => 'Very Rough';

  @override
  String get locCoxsBazar => 'Cox\'s Bazar';

  @override
  String get locChattogram => 'Chattogram';

  @override
  String get locBhola => 'Bhola';

  @override
  String get locPatuakhali => 'Patuakhali';

  @override
  String get locSundarbans => 'Sundarbans';

  @override
  String get locTeknaf => 'Teknaf';

  @override
  String get dayMon => 'Mon';

  @override
  String get dayTue => 'Tue';

  @override
  String get dayWed => 'Wed';

  @override
  String get dayThu => 'Thu';

  @override
  String get dayFri => 'Fri';

  @override
  String get daySat => 'Sat';

  @override
  String get daySun => 'Sun';

  @override
  String get splashTagline1 => 'Companion — Food · Rescue · Community';

  @override
  String get splashTagline2 => 'Emergency Companion';

  @override
  String get meshIncomingCall => 'Incoming call...';

  @override
  String get meshCalling => 'Calling...';

  @override
  String get meshRejectCall => 'Reject';

  @override
  String get meshAcceptCall => 'Accept';

  @override
  String get meshMute => 'Mute';

  @override
  String get meshMuted => 'Muted';

  @override
  String get meshEndCall => 'End Call';

  @override
  String get meshSpeaker => 'Speaker';

  @override
  String get meshEarpiece => 'Earpiece';

  @override
  String get triageTitle => 'Triage Wizard';

  @override
  String get triageRestart => 'Restart';

  @override
  String triageQuestion(String num, String total) {
    return 'Question $num / $total';
  }

  @override
  String get triageYes => 'Yes';

  @override
  String get triageNo => 'No';

  @override
  String get triageViewCard => 'View Card';

  @override
  String get triageCall999 => 'Call 999';

  @override
  String get triageCalling999 => 'Call 999 — Dialing in phone app';

  @override
  String get shelterTitle => 'Nearby Shelter';

  @override
  String get shelterSearchTooltip => 'Search Shelter';

  @override
  String get shelterClearRoute => 'Clear Route';

  @override
  String get shelterOfflineBanner => 'Offline — Showing cached tiles';

  @override
  String get shelterMapView => 'Map';

  @override
  String get shelterListView => 'List';

  @override
  String get shelterZoomIn => 'Zoom In';

  @override
  String get shelterZoomOut => 'Zoom Out';

  @override
  String get shelterDistLabel => 'Distance';

  @override
  String get shelterCapacityLabel => 'Capacity';

  @override
  String get shelterPeopleUnit => 'people';

  @override
  String get shelterSource => 'Source';

  @override
  String get shelterApproved => 'Approved';

  @override
  String get shelterAddress => 'Address';

  @override
  String get shelterLandmark => 'Landmark';

  @override
  String get shelterDesc => 'Description';

  @override
  String shelterCapacityCount(String count) {
    return 'Capacity: $count people';
  }

  @override
  String get shelterFindingRoute => 'Finding route...';

  @override
  String get shelterDetails => 'Details';

  @override
  String get shelterNoData => 'No shelter information';

  @override
  String get shelterKm => 'km';

  @override
  String get shelterSearchHint => 'Search shelters...';

  @override
  String get shelterSearchEmpty => 'No shelter found';

  @override
  String get shelterNearest3 => 'Nearest 3';

  @override
  String get chatReadAloud => 'Read';

  @override
  String get chatPathCloud => 'Cloud';

  @override
  String get chatPathDevice => 'Device';

  @override
  String get chatPathCorpus => 'Corpus';

  @override
  String get chatPathCanned => '999';

  @override
  String get meshDeleteChatHistory => 'Delete chat history?';

  @override
  String meshDeleteChatBody(String peer) {
    return 'All messages with \"$peer\" will be deleted. This cannot be undone.';
  }

  @override
  String get meshDeleteChatDone => 'Chat history deleted';

  @override
  String get meshDeleteChatButton => 'Delete';

  @override
  String get meshSendMessageFailed =>
      'Could not send message — check if peer is connected';

  @override
  String get meshSendMediaFailed =>
      'Could not send media — check if peer is connected';

  @override
  String get meshCallTooltip => 'Voice Call';

  @override
  String get meshDeleteChatMenu => 'Delete chat history';

  @override
  String meshEmptyChat(String peer) {
    return 'No messages yet\nStart chatting with \"$peer\"';
  }

  @override
  String get meshInputHint => 'Type a message...';

  @override
  String meshHopCount(String count) {
    return '↻ $count hops';
  }

  @override
  String get meshSendImage => 'Send Image';

  @override
  String get meshSendVideo => 'Send Video';

  @override
  String get meshImageMissing => 'Image not available';

  @override
  String get meshImageLoadError => 'Image failed to load';

  @override
  String get meshVideoMissing => 'Video not available';

  @override
  String get meshVideoBadge => 'Video';

  @override
  String get meshVideoLoadError => 'Video failed to load';

  @override
  String get meshRescanTooltip => 'Rescan';

  @override
  String get meshRescanning => 'Scanning again...';

  @override
  String get meshConnectingStatus => 'Connecting...';

  @override
  String get meshConnectFailed => 'Connection failed';

  @override
  String get meshOfflineContact => 'Offline';

  @override
  String get emergencyCloseTooltip => 'Cancel';

  @override
  String get emergencyCallTitle => 'Emergency Call';

  @override
  String get emergencyCallNumber => '999';

  @override
  String get emergencySlideInstruction =>
      'Slide right to call emergency services';

  @override
  String get emergencySendSos => 'Send SOS instead';

  @override
  String get emergencySlideRelease => 'Release';

  @override
  String get emergencySlideHint => 'Slide right';

  @override
  String get emergencyCallButton => 'Call';

  @override
  String get emergencyDefaultUser => 'User';

  @override
  String get emergencyDefaultPhone => 'Unknown';

  @override
  String get emergencyGpsDenied => 'GPS permission not granted';

  @override
  String get emergencyGpsNotFound => 'GPS not found (no satellite signal?)';

  @override
  String get emergencySosFailed => 'SOS not sent — messaging app not found';

  @override
  String get emergencyCallFallback => 'Call someone or 999.';

  @override
  String get sosReportTitle => 'SOS Report';

  @override
  String get sosDescribeHeading => 'Describe the emergency';

  @override
  String get sosDescribeHint => 'What happened, where, who is injured...';

  @override
  String get sosAiTooltip => 'Generate with AI';

  @override
  String get sosStructuredHeading => 'Structured Report';

  @override
  String get sosFieldLocation => 'Location';

  @override
  String get sosFieldLocationHint => 'Area/Address';

  @override
  String get sosFieldHazard => 'Hazard Type';

  @override
  String get sosFieldHazardHint => 'Flood/Fire/Snake/...';

  @override
  String get sosFieldInjured => 'Number of Injured';

  @override
  String get sosFieldInjuredHint => '0';

  @override
  String get sosFieldInjury => 'Injury Description';

  @override
  String get sosFieldInjuryHint => 'Type of injury';

  @override
  String get sosFieldUrgent => 'Immediate Needs';

  @override
  String get sosFieldUrgentHint => 'Ambulance/Rescue/Medical';

  @override
  String get sosFieldAccess => 'Access Info';

  @override
  String get sosFieldAccessHint => 'Road/Landmark/Obstacles';

  @override
  String get sosSmsPreview => 'SMS Preview';

  @override
  String get sosCall999Button => 'Call 999';

  @override
  String get sosEmptyInputError => 'Please describe the situation first.';

  @override
  String get sosModelNotReady => 'Model not loaded — fill in manually.';

  @override
  String get sosAiFailed => 'AI generation failed — fill in manually.';

  @override
  String get sosAiSuccess => 'AI generated — please review.';

  @override
  String get hazardsAllAlerts => 'All Alerts';

  @override
  String get quickCardsTitle => 'Emergency Aid Cards';

  @override
  String get quickCardsSearchHint => 'Search: first aid, snakebite, flood...';

  @override
  String get adminLogoutTitle => 'Log out?';

  @override
  String get adminLogoutBody => 'Do you want to leave the admin panel?';

  @override
  String get adminLogoutButton => 'Log out';

  @override
  String get adminPanelTitle => 'Admin Panel';

  @override
  String get adminTabDashboard => 'Dashboard';

  @override
  String get adminTabUsers => 'Users';

  @override
  String get adminTabCampaigns => 'Campaign Requests';

  @override
  String get adminTabBroadcast => 'Message Broadcast';

  @override
  String get adminStatUsers => 'Total Users';

  @override
  String get adminStatOffline => 'Offline Sessions';

  @override
  String get adminStatMesh => 'Mesh Peers';

  @override
  String get adminNoDevices => 'No connected devices';

  @override
  String get adminUnknownDevice => 'Unknown Device';

  @override
  String get adminNoCampaigns => 'No campaign requests';

  @override
  String get adminDetailUser => 'User';

  @override
  String get adminDetailPhone => 'Phone';

  @override
  String get adminDetailAddress => 'Address';

  @override
  String get adminDetailLandmark => 'Landmark';

  @override
  String get adminDetailCoords => 'Coordinates';

  @override
  String get adminDetailTime => 'Time';

  @override
  String get adminDetailDesc => 'Description';

  @override
  String get adminDetailNotes => 'Admin Notes';

  @override
  String get adminRejectLabel => 'Rejected';

  @override
  String get adminApproveLabel => 'Approve';

  @override
  String adminApproveSuccess(String type) {
    return '$type approved — added to map';
  }

  @override
  String get adminCloseButton => 'Close';

  @override
  String get adminProximityNotified => 'Nearby users have been notified';

  @override
  String get adminNotesHint => 'Write notes...';

  @override
  String get adminBroadcastSuccess => 'Message sent';

  @override
  String get adminBroadcastSection => 'Global Broadcast';

  @override
  String get adminBroadcastSubtitle => 'Send a message to all users';

  @override
  String get adminBroadcastHint => 'Type a message…';

  @override
  String get adminBroadcastButton => 'Send Message';

  @override
  String get adminLoginError => 'Wrong username or password.';

  @override
  String get adminLoginTitle => 'Admin Login';

  @override
  String get adminLoginHeading => 'Admin Panel Access';

  @override
  String get adminLoginSubtitle => 'Please provide your correct credentials.';

  @override
  String get adminUsernameLabel => 'Username';

  @override
  String get adminUsernameValidator => 'Enter username';

  @override
  String get adminPasswordLabel => 'Password';

  @override
  String get adminPasswordValidator => 'Enter password';

  @override
  String get adminLoginButton => 'Sign In';

  @override
  String get mapPickerTitle => 'Select Location on Map';

  @override
  String get mapPickerSearchHint => 'Search area (e.g., Dhaka, Chattogram)';

  @override
  String get mapPickerZoomIn => 'Zoom In';

  @override
  String get mapPickerZoomOut => 'Zoom Out';

  @override
  String get mapPickerMyLocation => 'My Location';

  @override
  String get mapPickerInstruction => 'Tap anywhere on the map to pin';

  @override
  String get mapPickerConfirm => 'Confirm Location';

  @override
  String get profileGenderLabel => 'Gender';

  @override
  String get profileGenderMale => 'Male';

  @override
  String get profileGenderFemale => 'Female';

  @override
  String get profileHealthConditions => 'Health Conditions';

  @override
  String get profilePregnant => 'Pregnant';

  @override
  String get profileDisabled => 'Disabled';

  @override
  String get profileElderly => 'Elderly';

  @override
  String get profileChildrenPresent => 'Children present';

  @override
  String get profileDisasterProne => 'Disaster-prone area';

  @override
  String get profileSaveSuccess => 'Profile saved';

  @override
  String get profileDefaultName => 'User';

  @override
  String get profileNoLocation => 'No location';

  @override
  String get profileLocationLoading => 'Loading location...';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileGallery => 'Gallery';

  @override
  String get profileCamera => 'Camera';

  @override
  String get profileDeletePhotoTitle => 'Delete photo?';

  @override
  String get profileDeletePhotoBody => 'Photo will be removed from profile.';

  @override
  String get profileRemovePhoto => 'Remove photo';

  @override
  String get profileDistrict => 'District';

  @override
  String get profileDistrictHint => 'Select division and district';

  @override
  String get profileEnterName => 'Enter name';

  @override
  String get modelStatusNotDownloaded => 'Download required';

  @override
  String modelStatusDownloading(String progress) {
    return 'Downloading $progress';
  }

  @override
  String get modelStatusReady => 'Ready';

  @override
  String get modelStatusLoading => 'Loading...';

  @override
  String get modelStatusFailed => 'Failed';

  @override
  String get modelE2bSize => '~2.5 GB';

  @override
  String get modelE2bDesc => 'Lightweight and fast. Works on all devices.';

  @override
  String get modelE4bSize => '~3.5 GB';

  @override
  String get modelE4bDesc => 'Higher quality answers. Requires 6GB+ RAM.';

  @override
  String get model12bSize => '~7-10 GB';

  @override
  String get model12bDesc => 'Best quality answers. Requires 12GB+ RAM.';

  @override
  String get hazardCyclone => 'Cyclone';

  @override
  String get hazardFlood => 'Flood';

  @override
  String get hazardEarthquake => 'Earthquake';

  @override
  String get hazardWildfire => 'Wildfire';

  @override
  String get hazardVolcano => 'Volcano';

  @override
  String get hazardLandslide => 'Landslide';

  @override
  String get hazardExtremeHeat => 'Extreme Heat';

  @override
  String get hazardDrought => 'Drought';

  @override
  String get hazardSeaIce => 'Sea Ice';

  @override
  String get hazardManmade => 'Manmade';

  @override
  String get hazardOther => 'Other';

  @override
  String get severityGreen => 'Green';

  @override
  String get severityOrange => 'Orange';

  @override
  String get severityRed => 'Red';

  @override
  String get severityUnknown => 'Unknown';

  @override
  String get earthquakeLight => 'Light';

  @override
  String get earthquakeModerate => 'Moderate';

  @override
  String get earthquakeStrong => 'Strong';

  @override
  String get urgencyCritical => 'Critical';

  @override
  String get urgencyUrgent => 'Urgent';

  @override
  String get urgencyNormal => 'Normal';

  @override
  String get contactPolice => 'Police';

  @override
  String get contactFire => 'Fire';

  @override
  String get contactAmbulance => 'Ambulance';

  @override
  String get contactDisaster => 'Disaster';

  @override
  String get contactRedCrescent => 'Red Crescent';

  @override
  String get contactHealth => 'Health';

  @override
  String get contactOther => 'Other';

  @override
  String get campaignTypeFoodDonation => 'Food Donation';

  @override
  String get campaignTypeRescue => 'Rescue Operation';

  @override
  String get campaignTypeMedical => 'Medical Camp';

  @override
  String get campaignTypeShelter => 'Shelter Support';

  @override
  String get campaignTypeClothing => 'Clothing Donation';

  @override
  String get campaignTypeWater => 'Water Supply';

  @override
  String get campaignStatusPending => 'Pending';

  @override
  String get campaignStatusApproved => 'Approved';

  @override
  String get campaignStatusRejected => 'Rejected';

  @override
  String get chatSend => 'Send';

  @override
  String get adminDashboardTitle => 'System Overview';

  @override
  String get adminDashboardSubtitle =>
      'Real-time state of mesh peers and campaigns';

  @override
  String get adminQuickActions => 'Quick Actions';

  @override
  String get adminReviewCampaigns => 'Review Campaigns';

  @override
  String get adminApprove => 'Approve';

  @override
  String get adminApproved => 'Approved';

  @override
  String get adminBroadcastSend => 'Send';

  @override
  String get adminPageBackTooltip => 'Back';

  @override
  String get safetyStatusTitle => 'My Status';

  @override
  String get safetyStatusDesc =>
      'Report your current status. Notify your contacts and emergency services.';

  @override
  String get safetySafeButton => 'I\'m Safe';

  @override
  String get safetyDangerButton => 'I\'m in Danger';

  @override
  String get safetyStatusSent => 'Safe status sent';

  @override
  String get dangerAlertSent => 'Danger alert sent — help is coming';

  @override
  String get safetyStatusNone => 'No status reported yet';

  @override
  String get safetyCurrentSafe => 'Current status: Safe';

  @override
  String get safetyCurrentDanger => 'Current status';

  @override
  String get dangerTypePickerTitle => 'What type of danger?';

  @override
  String get dangerTypePickerSubtitle => 'Select your situation';

  @override
  String get adminSafetyTotal => 'Total Users';

  @override
  String get adminSafetySafe => 'Safe';

  @override
  String get adminSafetyDanger => 'In Danger';

  @override
  String get adminDangerListTitle => 'Users in Danger';

  @override
  String get adminDangerListEmpty => 'No one in danger';

  @override
  String get adminDangerOpenMap => 'View on Map';
}
