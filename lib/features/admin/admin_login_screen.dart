import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/firebase_auth_service.dart';
import '../safe_beacon/safety_status_service.dart';
import 'campaign_request.dart';

/// SHA-256 digests of the admin credentials.
///
/// The pair used to sit in this file as `user == 'admin' && pass ==
/// 'admin123'` — two plaintext string constants, recoverable from the
/// shipped `libapp.so` with `strings`, on a screen an operator types in
/// front of an audience.
///
/// Comparing digests is obfuscation, not authentication: the gate is still
/// client-asserted and a determined attacker can patch past it. That is
/// already documented as a known limit in `firestore.rules`, which is where
/// the real boundary lives. What this buys is that the working password is
/// no longer a readable literal, and that a deployment can set its own pair
/// at build time without editing source:
///
/// ```
/// flutter build apk \
///   --dart-define=ADMIN_USER_SHA256=<hex> \
///   --dart-define=ADMIN_PASS_SHA256=<hex>
/// ```
const String _kUserDigest = String.fromEnvironment(
  'ADMIN_USER_SHA256',
  defaultValue:
      '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918',
);
const String _kPassDigest = String.fromEnvironment(
  'ADMIN_PASS_SHA256',
  defaultValue:
      '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9',
);

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();

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
  bool _obscurePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // `claimAdminRole` is awaited, and the button used to stay live across
    // that await — a double tap fired two role claims and two
    // `pushReplacementNamed` calls.
    if (_busy) return;

    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final user = _usernameController.text.trim();
    final pass = _passwordController.text;

    if (_digest(user) == _kUserDigest && _digest(pass) == _kPassDigest) {
      setState(() => _busy = true);
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
    final tt = Theme.of(context).textTheme;
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
                    style: tt.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.adminLoginSubtitle,
                    style: tt.bodyMedium?.copyWith(
                      color: ShongjogTheme.bodySecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: ShongjogTheme.toneFill(
                                context, SemanticTone.danger)
                            .withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(ShongjogTheme.radiusSm),
                        border: Border.all(
                          color: ShongjogTheme.toneFill(
                              context, SemanticTone.danger),
                        ),
                      ),
                      // Paired with an icon, not colour alone (§6,
                      // "Colour-only signaling").
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 20,
                            color: ShongjogTheme.toneInk(
                                context, SemanticTone.danger),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _errorMessage!,
                              style: tt.bodyMedium?.copyWith(
                                color: ShongjogTheme.toneInk(
                                    context, SemanticTone.danger),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _usernameController,
                    enabled: !_busy,
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
                    enabled: !_busy,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: l10n.adminPasswordLabel,
                      prefixIcon: const Icon(Icons.lock_rounded),
                      // An admin types this on a projector-mirrored phone.
                      // Being able to check what was typed, once, beats
                      // three failed silent attempts on stage.
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? l10n.adminPasswordShow
                            : l10n.adminPasswordHide,
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
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
                    onPressed: _busy ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(ShongjogTheme.radiusSm),
                      ),
                    ),
                    child: _busy
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(l10n.adminSigningIn, style: tt.labelLarge),
                            ],
                          )
                        : Text(l10n.adminLoginButton, style: tt.labelLarge),
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
