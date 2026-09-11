import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// Late-bound [AppLocalizations] for code that doesn't have a direct
/// BuildContext (e.g. pure model logic). Set on app startup by `main.dart`.
class ShongjogL10n {
  static AppLocalizations? current;

  static AppLocalizations of(BuildContext context) =>
      AppLocalizations.of(context);
}
