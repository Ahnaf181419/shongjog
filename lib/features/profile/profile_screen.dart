import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../app/theme.dart';
import 'district_data.dart';
import '../../core/locale_controller.dart';

/// Lightweight profile data holder for display outside the profile screen.
class UserProfileData {
  final String name;
  final String phone;
  final String? photoPath;

  /// Locale-independent canonical id for the saved district, or `null`
  /// when nothing is saved. Resolve via [displayDistrictName] for any
  /// given locale so consumers always get the right script.
  final String? districtId;

  const UserProfileData({
    required this.name,
    this.phone = '',
    this.photoPath,
    this.districtId,
  });

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty && File(photoPath!).existsSync();
  String get initial => name.isNotEmpty ? name[0] : '';

  static const empty = UserProfileData(name: '');

  static Future<UserProfileData> load() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfileData(
      name: prefs.getString('user_name') ?? '',
      phone: prefs.getString('user_phone') ?? '',
      photoPath: prefs.getString('user_photo_path'),
      districtId: prefs.getString('user_district'),
    );
  }

  /// Resolves [districtId] to a display name in the requested locale,
  /// or `null` if no district is saved.
  Future<String?> displayDistrictName(String localeCode) async {
    final id = districtId;
    if (id == null) return null;
    final bn = await loadDistricts('bn');
    final decoded = districtFromCanonicalId(bn, id);
    if (decoded != null) {
      return _displayFor(bn, decoded.division, decoded.district, localeCode);
    }
    // Legacy value — a localized district name persisted before the
    // canonical-id migration. Try matching by name in the bn block
    // (the SSOT).
    for (final divEntry in bn.entries) {
      if (divEntry.value.contains(id)) {
        return _displayFor(bn, divEntry.key, id, localeCode);
      }
    }
    return id;
  }

  Future<String> _displayFor(
      Map<String, List<String>> bn, String division, String district, String localeCode) async {
    final local = await loadDistricts(localeCode);
    final localDivs = local.keys.toList();
    final divIdx = bn.keys.toList().indexOf(division);
    if (divIdx < 0 || divIdx >= localDivs.length) return district;
    final divisionLocal = localDivs[divIdx];
    final districts = local[divisionLocal]!;
    final distIdx = bn[division]!.indexOf(district);
    if (distIdx < 0 || distIdx >= districts.length) return district;
    return districts[distIdx];
  }
}

/// User profile screen — edit name, phone, profile photo, and district.
///
/// Persists to SharedPreferences keys:
/// - `user_name` (read by emergency_sheet.dart and safe_beacon_screen.dart)
/// - `user_phone` (read by emergency_sheet.dart and safe_beacon_screen.dart)
/// - `user_photo_path` (path to app-docs/profile_photo.jpg)
/// - `user_district`
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _picker = ImagePicker();
  String? _photoPath;
  String? _district;
  bool _loading = true;
  Map<String, List<String>>? _districts;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    localeController.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    localeController.removeListener(_onLocaleChanged);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onLocaleChanged() {
    if (!mounted) return;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = localeController.languageCode;
    // Always load both bn and en blocks so we can resolve canonical
    // district ids to a locale-appropriate display name.
    final bn = await loadDistricts('bn');
    final local = await loadDistricts(localeCode);
    if (!mounted) return;
    // Resolve any saved canonical id to the current locale's display
    // name so the dropdown reflects the user's language.
    final savedId = prefs.getString('user_district');
    String? initialDistrict;
    if (savedId != null) {
      final decoded = districtFromCanonicalId(bn, savedId);
      if (decoded != null) {
        final divIdx = bn.keys.toList().indexOf(decoded.division);
        final distIdx = bn[decoded.division]!.indexOf(decoded.district);
        final localDivs = local.keys.toList();
        if (divIdx >= 0 && divIdx < localDivs.length) {
          final districts = local[localDivs[divIdx]]!;
          if (distIdx >= 0 && distIdx < districts.length) {
            initialDistrict = districts[distIdx];
          }
        }
      } else {
        // Legacy: saved value may be a localized district name; try to
        // find a match and migrate on the fly.
        for (final divEntry in bn.entries) {
          if (divEntry.value.contains(savedId)) {
            final divIdx = bn.keys.toList().indexOf(divEntry.key);
            final distIdx = divEntry.value.indexOf(savedId);
            final localDivs = local.keys.toList();
            if (divIdx >= 0 && divIdx < localDivs.length) {
              final districts = local[localDivs[divIdx]]!;
              if (distIdx >= 0 && distIdx < districts.length) {
                initialDistrict = districts[distIdx];
              }
            }
            break;
          }
        }
      }
    }
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? '';
      _phoneController.text = prefs.getString('user_phone') ?? '';
      _photoPath = prefs.getString('user_photo_path');
      _district = initialDistrict;
      _districts = local;
      _loading = false;
    });
  }

  Future<void> _pickPhoto() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(l10n.profileGallery),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: Text(l10n.profileCamera),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/profile_photo.jpg');
    await File(picked.path).copy(file.path);

    if (mounted) setState(() => _photoPath = file.path);
  }

  void _removePhoto() async {
    if (_photoPath != null && _photoPath!.isNotEmpty) {
      final file = File(_photoPath!);
      if (await file.exists()) await file.delete();
    }
    if (mounted) setState(() => _photoPath = null);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileEnterName)),
      );
      return;
    }

    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_phone', _phoneController.text.trim());
    await prefs.setString('user_photo_path', _photoPath ?? '');
    if (_district != null) {
      // Convert the localized display name back into a canonical id so
      // the saved value is locale-independent.
      final bn = await loadDistricts('bn');
      String? canonical;
      for (final divEntry in bn.entries) {
        final distIdx = divEntry.value.indexOf(_district!);
        if (distIdx >= 0) {
          final divIdx = bn.keys.toList().indexOf(divEntry.key);
          canonical = '__district_${divIdx}_$distIdx';
          break;
        }
      }
      if (canonical != null) {
        await prefs.setString('user_district', canonical);
      } else {
        // Fall back to the display string — won't switch with locale but
        // preserves the user's selection rather than dropping it.
        await prefs.setString('user_district', _district!);
      }
    } else {
      await prefs.remove('user_district');
    }

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileSaveSuccess)),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 12),
                // ── Avatar ──
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildAvatar(cs),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cs.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: cs.onPrimary,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Remove photo link ──
                if (_photoPath != null && _photoPath!.isNotEmpty && File(_photoPath!).existsSync())
                  Center(
                    child: TextButton(
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.profileDeletePhotoTitle),
                          content: Text(l10n.profileDeletePhotoBody),
                          actions: [
                            TextButton(
                              style: ShongjogTheme.dialogAction(),
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l10n.cancel),
                            ),
                            FilledButton(
                              style: ShongjogTheme.dialogAction(),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(l10n.delete),
                            ),
                          ],
                        ),
                      ).then((v) {
                        if (v == true) _removePhoto();
                      }),
                      child: Text(
                        l10n.profileRemovePhoto,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                // ── Name field ──
                TextField(
                  controller: _nameController,
                  maxLength: 50,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.nameLabel,
                    hintText: l10n.nameHint,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                // ── Phone field ──
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 14,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.phoneLabel,
                    hintText: l10n.phoneHint,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                // ── District dropdown ──
                DropdownButtonFormField<String>(
                  initialValue: _district,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.profileDistrict,
                    hintText: l10n.profileDistrictHint,
                  ),
                  items: _buildDistrictItems(),
                  onChanged: (v) => setState(() => _district = v),
                ),
                const SizedBox(height: 32),
                // ── Save button ──
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            // On cs.primary, which is light blue in dark mode.
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(l10n.save),
                ),
              ],
            ),
    );
  }

  Widget _buildAvatar(ColorScheme cs) {
    final hasPhoto = _photoPath != null && _photoPath!.isNotEmpty && File(_photoPath!).existsSync();
    final name = _nameController.text.trim();
    final initial = name.isNotEmpty ? name[0] : '';

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primary.withValues(alpha: 0.12),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.file(
                File(_photoPath!),
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              )
            : Center(
                child: initial.isNotEmpty
                    ? Text(
                        initial,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      )
                    : Icon(
                        Icons.person_rounded,
                        size: 48,
                        color: cs.primary.withValues(alpha: 0.6),
                      ),
              ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildDistrictItems() {
    final items = <DropdownMenuItem<String>>[];
    final divisions = _districts ?? (throw StateError('districts not loaded'));

    for (final entry in divisions.entries) {
      // Division header (disabled)
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          value: '__division_${entry.key}',
          child: Text(
            entry.key,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: ShongjogTheme.fontFamily,
              fontFamilyFallback: ShongjogTheme.fontFallback,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );

      // Districts under this division
      for (final district in entry.value) {
        items.add(
          DropdownMenuItem<String>(
            value: district,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(district),
            ),
          ),
        );
      }
    }

    return items;
  }
}
