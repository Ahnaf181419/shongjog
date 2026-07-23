import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/model_manager.dart';
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

  final ModelManager _model = modelManager;
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

  Future<void> _processWithAi() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('আগে অবস্থা বর্ণনা লিখুন।')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    if (!_model.isReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('মডেল লোড করা নেই — নিজে পূরণ করুন।'),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final prompt = _buildSosPrompt(input);
      final raw = await _model.generateStructured(
        prompt: prompt,
        tools: const [sosReportTool],
      );
      if (!mounted) return;
      if (raw == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI গঠন করতে পারেনি — নিজে পূরণ করুন।'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      final fields = _parseToolCallResponse(raw);
      if (fields != null) _applyExtractedFields(fields);
    } catch (e) {
      debugPrint('[SosComposer] AI extraction failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _buildSosPrompt(String input) {
    return '''তুমি একজন বাংলাদেশি জরুরি সহায়তা সহকারী। নিচের বর্ণনা থেকে একটি কাঠামোবদ্ধ SOS রিপোর্ট বের করো।
সবকিছু বাংলায় লেখো।

অবস্থা: $input''';
  }

  /// Extract the tool-call arguments from the raw SDK JSON. The format
  /// varies across SDK versions — we look for the first key that contains
  /// "submit_sos_report" or fall back to scanning for known field names.
  Map<String, dynamic>? _parseToolCallResponse(String raw) {
    try {
      final dynamic parsed = jsonDecode(raw);
      // Case 1: structured tool_calls array
      if (parsed is Map<String, dynamic>) {
        final calls = parsed['tool_calls'] as List?;
        if (calls != null && calls.isNotEmpty) {
          final first = calls.first as Map<String, dynamic>;
          final fn = first['function'] as Map<String, dynamic>?;
          if (fn != null && fn['arguments'] != null) {
            final args = fn['arguments'];
            if (args is String) return jsonDecode(args) as Map<String, dynamic>;
            if (args is Map<String, dynamic>) return args;
          }
        }
        // Case 2: flat map with field names directly
        if (parsed.containsKey('location') ||
            parsed.containsKey('hazard_type')) {
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('[SosComposer] JSON parse failed: $e');
    }
    return null;
  }

  void _applyExtractedFields(Map<String, dynamic> fields) {
    if (fields['location'] != null) {
      _locationController.text = fields['location'].toString();
    }
    if (fields['hazard_type'] != null) {
      _hazardController.text = fields['hazard_type'].toString();
    }
    if (fields['casualty_count'] != null) {
      _casualtyController.text = fields['casualty_count'].toString();
    }
    if (fields['injuries'] != null) {
      _injuriesController.text = fields['injuries'].toString();
    }
    final needs = fields['immediate_needs'];
    if (needs is List && needs.isNotEmpty) {
      _needsController.text = needs.join(', ');
    }
    if (fields['access_notes'] != null) {
      _accessController.text = fields['access_notes'].toString();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI দিয়ে গঠন সম্পন্ন — যাচাই করুন।'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _sendSos() {
    // Navigate to the dialer with the SMS body pre-filled.
    // Uses EmergencyActions.sendSos which opens the system SMS composer.
    Navigator.of(context).pop(_smsPreview);
  }
}
