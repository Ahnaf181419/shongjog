import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../app/theme.dart';
import 'district_data.dart';

/// Lightweight profile data holder for display outside the profile screen.
class UserProfileData {
  final String name;
  final String phone;
  final String? photoPath;
  final String? district;

  const UserProfileData({
    required this.name,
    this.phone = '',
    this.photoPath,
    this.district,
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
      district: prefs.getString('user_district'),
    );
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? '';
      _phoneController.text = prefs.getString('user_phone') ?? '';
      _photoPath = prefs.getString('user_photo_path');
      _district = prefs.getString('user_district');
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
      await prefs.setString('user_district', _district!);
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
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l10n.cancel),
                            ),
                            FilledButton(
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
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
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

    for (final entry in districtsByDivision.entries) {
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
