import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../audio/sound_service.dart';
import '../emergency/emergency_sheet.dart';
import '../voice/stt_service.dart';
import '../voice/tts_service.dart';
import 'chat_input.dart';
import 'message_bubble.dart';
import '../cloud_ai/cloud_ai_service.dart';

/// Chat screen — voice-first Bangla emergency assistant.
/// Reached from the hub. Uses Cloud AI (Gemini API with gemma-4-31b-it)
/// as primary, with a graceful error fallback message.
///
/// NOTE: The on-device RAG pipeline (KnowledgeBase + Embedder + ModelManager)
/// is not functional on Flutter Web because:
///   1. EmbedderImpl throws UnimplementedError (no embedder API in flutter_gemma)
///   2. flutter_gemma requires native ARM — unavailable on Web
///   3. KB assets (corpus.json, vectors.bin) are not bundled yet
///
/// For the hackathon demo, the chat goes directly to Cloud AI. On Android
/// builds with the model downloaded, the full RAG pipeline can be re-enabled.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Msg> _messages = [];
  final _tts = TtsService();
  final _stt = SttService();
  final _sound = SoundService();
  final _inputKey = GlobalKey<ChatInputState>();
  CloudAiService? _cloudAi;
  bool _busy = false;
  bool _listening = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _sound.init();
    
    // Initialize CloudAI synchronously without triggering a redundant setState
    // that corrupts the layout pipeline on Flutter Web.
    try {
      // Using your provided API key directly so it works out of the box
      // without needing --dart-define compiler arguments.
      const apiKey = String.fromEnvironment(
        'GEMINI_API_KEY',
        defaultValue: 'AQ.Ab8RN6I-fxGxIBHGuwbJljSNkaRxw8QfCx8waeaRkbJ7cpe_wg',
      );
      _cloudAi = CloudAiService(apiKey: apiKey);
      _ready = true;
    } catch (e) {
      debugPrint('ChatScreen bootstrap error: $e');
    }
  }

  Future<void> _onSubmit(String q) async {
    if (!_ready || _busy) return;
    setState(() {
      _busy = true;
      _messages.insert(0, _Msg(q, true));
      _messages.insert(0, _Msg('ভাবছি...', false));
    });
    try {
      String answer;
      final isOnline = await _cloudAi!.isOnline;
      if (isOnline) {
        try {
          answer = await _cloudAi!.generate(q);
        } catch (e) {
          debugPrint('Cloud AI error: $e');
          answer =
              'ক্লাউড AI এর সাথে সংযোগ করতে পারিনি। '
              'অনুগ্রহ করে ইন্টারনেট সংযোগ পরীক্ষা করুন বা ৯৯৯ এ কল করুন।';
        }
      } else {
        answer =
            'আপনি অফলাইনে আছেন। অনুগ্রহ করে ইন্টারনেটে সংযুক্ত হোন '
            'অথবা জরুরি সাহায্যের জন্য ৯৯৯ এ কল করুন।';
      }
      setState(() => _messages[0] = _Msg(answer, false));
      // Removed _sound.knock() and _tts.speak() so it stays quiet automatically.
      // Users can tap the 'পড়ুন' (Read) button on the message if they want to hear it.
    } catch (e) {
      debugPrint('ChatScreen _onSubmit error: $e');
      setState(() {
        _messages[0] =
            _Msg('ত্রুটি হয়েছে। অনুগ্রহ করে ৯৯৯ এ কল করুন।', false);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onMicPressed() async {
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    final transcript = await _stt.listen(localeId: 'bn_BD');
    if (!mounted) return;
    setState(() => _listening = false);
    if (transcript != null && transcript.trim().isNotEmpty) {
      _onSubmit(transcript.trim());
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('আবার চেষ্টা করুন')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI সহায়ক'),
        actions: [
          IconButton(
            tooltip: 'জরুরি কল',
            icon: const Icon(Icons.call, color: ShongjogTheme.alertRed),
            onPressed: () => EmergencySheet.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_ready && _messages.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          Expanded(
            child: _messages.isEmpty ? _emptyState() : _messageList(),
          ),
          ChatInput(
            key: _inputKey,
            onSubmit: _onSubmit,
            onMicPressed: _onMicPressed,
            isListening: _listening,
          ),
        ],
      ),
    );
  }

  Widget _messageList() {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m = _messages[i];
        return MessageBubble(
          text: m.text,
          isUser: m.isUser,
          onSpeak: m.isUser ? null : () => _tts.speak(m.text),
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ShongjogTheme.calmTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _listening ? Icons.mic : Icons.mic_none,
                size: 36,
                color: _listening
                    ? ShongjogTheme.alertRed
                    : ShongjogTheme.calmTeal,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _listening ? 'শুনছি...' : 'আপনার জরুরি প্রশ্ন বলুন বা লিখুন',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: ShongjogTheme.bodyLargeFloor,
                  fontWeight: FontWeight.w500),
            ),
            if (!_listening) ...[
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _suggestion('ORS কীভাবে বানাবো?'),
                  _suggestion('নিকটস্থ আশ্রয়কেন্দ্র'),
                  _suggestion('সাপে কামড়ালে কী করবো?'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _suggestion(String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _onSubmit(label),
    );
  }
}

class _Msg {
  final String text;
  final bool isUser;
  _Msg(this.text, this.isUser);
}
