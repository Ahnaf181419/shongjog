/// Build the body of a pre-drafted SOS SMS. The message carries the user's
/// name, phone, and GPS coordinates as a clickable maps link, so responders
/// can locate them when voice calls fail (docs/prd.md §2, user story 6).
///
/// Sent via `sms:` URI on the cellular voice channel.
///
/// If GPS is unavailable (permission denied or no satellite fix), pass
/// [gpsWarning] so responders see an honest "GPS অনুপলব্ধ" marker instead of
/// being told to search for (0,0) in the Atlantic Ocean.
String sosSmsBody({
  required String name,
  required String phone,
  double? lat,
  double? lon,
  String? gpsWarning,
}) {
  final hasGps = lat != null && lon != null;
  final location = hasGps
      ? '$lat,$lon (https://maps.google.com/?q=$lat,$lon)'
      : (gpsWarning ?? 'GPS অনুপলব্ধ');
  return 'জরুরি সাহায্য দরকার। '
      'আমি $name। ফোন: $phone। '
      'অবস্থান: $location। '
      'অনুগ্রহ করে যোগাযোগ করুন।';
}