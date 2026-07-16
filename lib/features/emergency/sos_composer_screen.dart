import 'package:flutter/material.dart';

import 'sos_function_schema.dart';

/// SOS composer — takes panicked voice/text input, passes it through
/// Gemma's function-calling to produce a structured dispatch report,
/// and lets the user review + send as SMS to 999.
///
/// Note: the actual model call requires a device with the model loaded.
/// On this screen the user can manually edit all fields as a fallback.
class SosComposerScreen extends StatefulWidget {
  const SosComposerScreen({super.key});

  @override
  State<SosComposerScreen> createState() => _SosComposerScreenState();
}

class _SosComposerScreenState extends State<SosComposerScreen> {
  final _inputController = TextEditingController();
  final _locationController = TextEditingController();
  final _hazardController = TextEditingController();
  final _casualtyController = TextEditingController();
  final _injuriesController = TextEditingController();
  final _needsController = TextEditingController();
  final _accessController = TextEditingController();

  bool _isProcessing = false;

  @override
  void dispose() {
    _inputController.dispose();
    _locationController.dispose();
    _hazardController.dispose();
    _casualtyController.dispose();
    _injuriesController.dispose();
    _needsController.dispose();
    _accessController.dispose();
    super.dispose();
  }

  /// Build the SMS preview from the current field values.
  String get _smsPreview => buildSosSmsBody({
        'location': _locationController.text.isEmpty
            ? null
            : _locationController.text,
        'hazard_type':
            _hazardController.text.isEmpty ? null : _hazardController.text,
        'casualty_count': _casualtyController.text.isEmpty
            ? null
            : int.tryParse(_casualtyController.text),
        'injuries':
            _injuriesController.text.isEmpty ? null : _injuriesController.text,
        'immediate_needs':
            _needsController.text.isEmpty ? [] : [_needsController.text],
        'access_notes': _accessController.text.isEmpty
            ? null
            : _accessController.text,
      });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS রিপোর্ট'),
        backgroundColor: cs.errorContainer,
        foregroundColor: cs.onErrorContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Input section
          Text('জরুরি অবস্থা বর্ণনা করুন',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _inputController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'কী হয়েছে, কোথায়, কে আহত...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.auto_fix_high),
                tooltip: 'AI দিয়ে গঠন করুন',
                onPressed: _isProcessing ? null : _processWithAi,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Structured fields
          Text('গঠিত রিপোর্ট',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _field('স্থান (Location)', _locationController, 'এলাকা/ঠিকানা'),
          _field('ধরন (Hazard)', _hazardController, 'বন্যা/অগ্নিকাণ্ড/সাপ/...'),
          _field('আহতের সংখ্যা', _casualtyController, '০', keyboard: true),
          _field('আঘাতের বিবরণ', _injuriesController, 'কী ধরনের আঘাত'),
          _field('তাৎক্ষণিক প্রয়োজন', _needsController, 'অ্যাম্বুলেন্স/উদ্ধার/চিকিৎসা'),
          _field('প্রবেশপথ তথ্য', _accessController, 'রাস্তা/ল্যান্ডমার্ক/বাধা'),
          const SizedBox(height: 24),

          // SMS Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sms, size: 16, color: cs.primary),
                    const SizedBox(width: 4),
                    Text('SMS প্রিভিউ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _smsPreview,
                  style: TextStyle(
                      fontSize: 13, color: cs.onSurface, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _sendSos,
            icon: const Icon(Icons.call),
            label: const Text('৯৯৯ কল করুন'),
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, String hint,
      {bool keyboard = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  void _processWithAi() {
    // On-device model call to extract structured fields from the input.
    // Requires the model to be loaded — this is a placeholder for the
    // actual function-calling session. On a device without the model,
    // the user can manually fill the fields below.
    setState(() => _isProcessing = true);

    // TODO: Wire to modelManager.generateStructured() once the model
    // supports function calling on-device. For now, show a snackbar.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('মডেল লোড করা থাকলে AI গঠন করবে। এখন নিজে পূরণ করুন।'),
        duration: Duration(seconds: 2),
      ),
    );

    setState(() => _isProcessing = false);
  }

  void _sendSos() {
    // Navigate to the dialer with the SMS body pre-filled.
    // Uses EmergencyActions.sendSos which opens the system SMS composer.
    Navigator.of(context).pop(_smsPreview);
  }
}
