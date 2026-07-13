import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/model_manager.dart';
import '../../knowledge/kb_loader.dart';
import '../../rag/embedder.dart';
import '../emergency/emergency_actions.dart';
import 'chat_input.dart';
import 'chat_repository.dart';
import 'message_bubble.dart';
import '../voice/tts_service.dart';

/// Chat screen — voice-first Bangla emergency assistant.
/// Reached from the hub. Boots ChatRepository in background.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Msg> _messages = [];
  final _tts = TtsService();
  final _model = ModelManager();
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
      _repo = ChatRepository(
          kb: kb, embedder: EmbedderImpl(), modelManager: _model);
      if (mounted) setState(() {});
    } catch (_) {
      // KB load fails in test/no-asset env; surface nothing — UI still works.
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
      setState(() => _messages[0] = _Msg(answer, false));
      await _tts.speak(answer);
    } catch (_) {
      setState(() {
        _messages[0] = _Msg('ত্রুটি হয়েছে। অনুগ্রহ করে ৯৯৯ এ কল করুন।', false);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onMicPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ভয়েস ইনপুট শীঘ্রই আসছে')));
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
            onPressed: () => EmergencyActions.dial(EmergencyActions.police),
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
          ChatInput(onSubmit: _onSubmit, onMicPressed: _onMicPressed),
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
              child: const Icon(Icons.mic_none,
                  size: 36, color: ShongjogTheme.calmTeal),
            ),
            const SizedBox(height: 20),
            const Text(
              'আপনার জরুরি প্রশ্ন বলুন বা লিখুন',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: ShongjogTheme.bodyLargeFloor,
                  fontWeight: FontWeight.w500),
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
}

class _Msg {
  final String text;
  final bool isUser;
  _Msg(this.text, this.isUser);
}