/// Build the body of a pre-drafted SOS SMS. The message carries the user's
/// name, phone, and GPS coordinates as a clickable maps link, so responders
/// can locate them when voice calls fail (docs/prd.md §2, user story 6).
///
/// Sent via `sms:` URI on the cellular voice channel.
String sosSmsBody({
  required String name,
  required String phone,
  required double lat,
  required double lon,
}) {
  final maps = 'https://maps.google.com/?q=$lat,$lon';
  return 'জরুরি সাহায্য দরকার। '
      'আমি $name। ফোন: $phone। '
      'অবস্থান: $lat,$lon ($maps)। '
      'অনুগ্রহ করে যোগাযোগ করুন।';
}