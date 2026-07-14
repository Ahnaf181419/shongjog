import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../knowledge/kb_loader.dart';
import '../../rag/keyword_retriever.dart';
import '../../rag/types.dart';
import '../audio/sound_service.dart';
import '../emergency/emergency_sheet.dart';
import '../voice/stt_service.dart';
import '../voice/tts_service.dart';
import 'chat_input.dart';
import 'chat_repository.dart';
import 'message_bubble.dart';
import '../cloud_ai/cloud_ai_service.dart';

/// Chat screen — voice-first Bangla emergency assistant.
///
/// Uses keyword-based RAG retrieval (always offline) to find relevant
/// corpus chunks, then generates an answer via Cloud AI (when online)
/// or on-device Gemma (when offline). Falls back to the matched chunk
/// text if no model is available.
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
  ChatRepository? _repo;
  bool _busy = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _sound.init();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    KnowledgeBase? kb;
    try {
      kb = await KnowledgeBase.load();
    } catch (e) {
      debugPrint('KB load error: $e');
    }

    CloudAiService? cloudAi;
    try {
      const apiKey = String.fromEnvironment('GEMINI_API_KEY');
      if (apiKey.isNotEmpty) {
        cloudAi = CloudAiService(apiKey: apiKey);
      }
    } catch (e) {
      debugPrint('CloudAI init error: $e');
    }

    if (mounted) {
      setState(() {
        _repo = ChatRepository(kb: kb ?? _emptyKb(), cloudAi: cloudAi);
      });
    }
  }

  KnowledgeBase _emptyKb() {
    const fallbackChunk = Chunk(
      id: 'fallback',
      topic: 'general',
      source: 'Shongjog',
      text: 'জরুরি সাহায্যের জন্য ৯৯৯ এ কল করুন।',
      keywordsBn: ['জরুরি', 'সাহায্য', '999'],
    );
    return KnowledgeBase(
      chunks: const [fallbackChunk],
      keywordRetriever: const KeywordRetriever(chunks: [fallbackChunk]),
    );
  }

  Future<void> _onSubmit(String q) async {
    if (_repo == null || _busy) return;
    setState(() {
      _busy = true;
      _messages.insert(0, _Msg(q, true));
      _messages.insert(0, _Msg('ভাবছি...', false));
    });
    try {
      final answer = await _repo!.ask(q, onFallback: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('অফলাইন AI ব্যবহার করা হচ্ছে'),
            duration: Duration(seconds: 1),
          ),
        );
      });
      if (!mounted) return;
      setState(() => _messages[0] = _Msg(answer, false));
    } catch (e) {
      debugPrint('ChatScreen _onSubmit error: $e');
      if (!mounted) return;
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
          if (_repo == null && _messages.isEmpty)
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
