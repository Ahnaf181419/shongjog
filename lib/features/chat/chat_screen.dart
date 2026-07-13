import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/model_manager.dart';
import '../../knowledge/kb_loader.dart';
import '../../rag/embedder.dart';
import 'chat_input.dart';
import 'chat_repository.dart';
import 'message_bubble.dart';
import '../voice/tts_service.dart';

/// Primary chat screen — voice-first Bangla emergency assistant.
///
/// Boots a ChatRepository (KB + embedder + model) in the background; the
/// "পড়ুন" TTS button on each assistant bubble reads the answer aloud
/// (docs/design.md §7.1). Low-confidence answers (empty retrieval) are
/// surfaced from ChatRepository's canned response.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Msg> _messages = [];
  final _tts = TtsService();
  final _model = ModelManager();
  final _inputKey = GlobalKey<ChatInputState>();
  ChatRepository? _repo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final kb = await KnowledgeBase.load();
      final emb = EmbedderImpl();
      _repo = ChatRepository(kb: kb, embedder: emb, modelManager: _model);
      if (mounted) setState(() {});
    } catch (e) {
      // KB or embedder init failure — surface to the user (design.md §13.13).
      if (mounted) {
        _messenger().showSnackBar(
            SnackBar(content: Text('শুরু করা যায়নি: $e')));
      }
    }
  }

  Future<void> _onSubmit(String q) async {
    if (_repo == null || _busy) return;
    setState(() {
      _busy = true;
      _messages.insert(0, _Msg(q, true));
      _messages.insert(0, _Msg('ভাবছি...', false));
    });
    try {
      final answer = await _repo!.ask(q);
      setState(() {
        _messages[0] = _Msg(answer, false);
      });
      await _tts.speak(answer);
    } catch (e) {
      setState(() {
        _messages[0] = _Msg('ত্রুটি হয়েছে। অনুগ্রহ করে 999 এ কল করুন।', false);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onMicPressed() {
    // Phase 4.1 wires Vosk STT here.
    _messenger().showSnackBar(
        const SnackBar(content: Text('ভয়েস ইনপুট শীঘ্রই আসছে')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('সংযোগ — জরুরি সহায়তা'),
        actions: [
          IconButton(
            tooltip: 'জরুরি কার্ড',
            icon: const Icon(Icons.style),
            onPressed: () => Navigator.pushNamed(context, '/cards'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_repo == null)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _emptyState()
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      return MessageBubble(
                        text: m.text,
                        isUser: m.isUser,
                        onSpeak: m.isUser
                            ? null
                            : () => _tts.speak(m.text),
                      );
                    },
                  ),
          ),
          ChatInput(
            key: _inputKey,
            onSubmit: _onSubmit,
            onMicPressed: _onMicPressed,
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, size: 64, color: ShongjogTheme.calmTeal),
            const SizedBox(height: 16),
            const Text(
              'আপনার জরুরি প্রশ্ন বলুন বা লিখুন',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: ShongjogTheme.bodyLargeFloor),
            ),
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

  ScaffoldMessengerState _messenger() => ScaffoldMessenger.of(context);
}

class _Msg {
  final String text;
  final bool isUser;
  _Msg(this.text, this.isUser);
}