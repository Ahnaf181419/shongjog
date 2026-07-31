import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/firebase_auth_service.dart';
import '../safe_beacon/safety_status_service.dart';
import 'campaign_request.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final user = _usernameController.text.trim();
    final pass = _passwordController.text;

    if (user == 'admin' && pass == 'admin123') {
      // Claim the admin role on this device's Firestore user doc so the
      // Firestore security rules let it read/write campaigns and
      // broadcasts. Never throws (see FirebaseAuthService.claimAdminRole)
      // — login proceeds locally even if this device is offline right now.
      await firebaseAuthService.claimAdminRole();
      // Now that this device holds the role, re-issue the Firestore queries
      // as an admin: the panel needs pending campaigns and the safety feed,
      // neither of which a non-admin subscription returns.
      campaignRequestService.refreshSubscription();
      safetyStatusService.refreshSubscription();
      if (!mounted) return;
      // Navigate to Admin Panel and remove Login screen from history
      Navigator.pushReplacementNamed(context, AppRoutes.adminPanel);
    } else {
      setState(() {
        _errorMessage = AppLocalizations.of(context).adminLoginError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminLoginTitle),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon in a tinted, rounded badge — not a bare floating
                  // icon — matching the same "icon badge" motif used
                  // throughout the panel/tiles once past this gate. It's
                  // the first thing an admin sees, so it's the first
                  // place the privileged-area identity should read as
                  // intentional rather than a stock Material default.
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: ShongjogTheme.iconBadge(context),
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 48,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.adminLoginHeading,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.adminLoginSubtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: ShongjogTheme.bodySecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: ShongjogTheme.alert.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                        border: Border.all(color: ShongjogTheme.alert),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: ShongjogTheme.alert,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _usernameController,
                    // No `border:` override — the app's own themed
                    // inputDecorationTheme (filled, tinted, rounded to
                    // match every other field in the app) was previously
                    // being overridden here with a bare, sharp-cornered,
                    // unfilled OutlineInputBorder(), making the login
                    // screen — the very first thing an admin sees — look
                    // like a different, more generic app.
                    decoration: InputDecoration(
                      labelText: l10n.adminUsernameLabel,
                      prefixIcon: const Icon(Icons.person_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return l10n.adminUsernameValidator;
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.adminPasswordLabel,
                      prefixIcon: const Icon(Icons.lock_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return l10n.adminPasswordValidator;
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _handleLogin,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                      ),
                    ),
                    child: Text(
                      l10n.adminLoginButton,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
