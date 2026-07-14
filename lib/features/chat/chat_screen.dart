import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../app/main_shell.dart';
import '../../core/haptics.dart';
import '../../core/model_manager.dart';
import '../../knowledge/kb_loader.dart';
import '../../rag/keyword_retriever.dart';
import '../../rag/types.dart';
import '../audio/sound_service.dart';
import '../emergency/emergency_sheet.dart';
import '../voice/stt_service.dart';
import '../voice/tts_service.dart';
import 'chat_input.dart';
import 'chat_repository.dart';
import 'chat_store.dart';
import 'message_bubble.dart';
import '../cloud_ai/cloud_ai_service.dart';

/// Chat screen — voice-first Bangla emergency assistant.
///
/// Uses keyword-based RAG retrieval (always offline) to find relevant
/// corpus chunks, then generates an answer via on-device Gemma (preferred,
/// fully offline) or Cloud AI (when online). Falls back to the matched
/// chunk text if no model is available.
///
/// Messages are persisted via [ChatStore] and survive app restarts.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Msg> _messages = [];
  final _tts = TtsService();
  final _stt = SttService();
  final _sound = SoundService.instance;
  final _store = ChatStore();
  final _inputKey = GlobalKey<ChatInputState>();
  ChatRepository? _repo;
  bool _busy = false;
  bool _listening = false;
  String? _sttProviderName;
  bool _autoRead = true;
  bool _voiceInputEnabled = true;
  String? _lastQuery;

  @override
  void initState() {
    super.initState();
    _sound.init();
    _loadPrefsAndBootstrap();
  }

  @override
  void dispose() {
    _stt.dispose();
    super.dispose();
  }

  Future<void> _loadPrefsAndBootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _autoRead = prefs.getBool('pref_auto_read') ?? true;
    _voiceInputEnabled = prefs.getBool('pref_voice_input') ?? true;

    final saved = await _store.load();
    final restored = saved.reversed
        .map((m) => _Msg(m.text, m.isUser))
        .toList();

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

    String? providerName;
    try {
      await _stt.init();
      providerName = _stt.activeProviderName;
    } catch (e) {
      debugPrint('STT init error: $e');
    }

    if (mounted) {
      setState(() {
        _messages.addAll(restored);
        _repo = ChatRepository(
          kb: kb ?? _emptyKb(),
          modelManager: modelManager,
          cloudAi: cloudAi,
        );
        _sttProviderName = providerName;
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
    _lastQuery = q;
    setState(() {
      _busy = true;
      _messages.insert(0, _Msg(q, true));
      _messages.insert(0, _Msg('ভাবছি...', false, isThinking: true));
    });
    await _tryGenerate();
  }

  Future<void> _retry() async {
    if (_lastQuery == null || _busy) return;
    setState(() {
      _busy = true;
      _messages.insert(0, _Msg('ভাবছি...', false, isThinking: true));
    });
    await _tryGenerate();
  }

  Future<void> _tryGenerate() async {
    try {
      final answer = await _repo!.ask(_lastQuery!, onFallback: () {
        if (mounted) {
          setState(() => _messages[0] =
              _Msg('AI প্রস্তুত হচ্ছে...', false, isThinking: true));
        }
      });
      if (!mounted) return;
      setState(() => _messages[0] = _Msg(answer, false, animate: true));
      HapticService.success();
      _sound.chime();
      if (_autoRead) _tts.speak(answer);
      _persist();
    } catch (e) {
      debugPrint('ChatScreen _tryGenerate error: $e');
      if (!mounted) return;
      setState(() {
        _messages[0] = _Msg(
          'ত্রুটি হয়েছে। অনুগ্রহ করে ৯৯৯ এ কল করুন।',
          false,
          isError: true,
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _persist() {
    final storeMsgs = _messages.reversed
        .map((m) => ChatMessage(text: m.text, isUser: m.isUser))
        .toList();
    _store.save(storeMsgs);
  }

  Future<void> _onMicPressed() async {
    if (!_voiceInputEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সেটিংসে ভয়েস ইনপুট চালু করুন')),
      );
      return;
    }
    if (_listening) {
      HapticService.warn();
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    HapticService.lightTap();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI সহায়ক'),
            if (_sttProviderName != null)
              Builder(builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Text(
                  _stt.isOfflineCapable ? 'অফলাইন ভয়েস' : 'অনলাইন ভয়েস',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _stt.isOfflineCapable
                        ? (isDark
                            ? ShongjogTheme.successBright
                            : ShongjogTheme.success)
                        : ShongjogTheme.bodySecondary(context),
                  ),
                );
              }),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'জরুরি কল',
            icon: Icon(Icons.call, color: Theme.of(context).colorScheme.error),
            onPressed: () => EmergencySheet.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_repo == null && _messages.isEmpty) _loadingState(),
          Expanded(
            child: _messages.isEmpty && _repo != null
                ? _emptyState()
                : _repo == null
                    ? const SizedBox.shrink()
                    : _messageList(),
          ),
          ChatInput(
            key: _inputKey,
            onSubmit: _onSubmit,
            onMicPressed: _onMicPressed,
            isListening: _listening,
            voiceInputEnabled: _voiceInputEnabled,
          ),
        ],
      ),
    );
  }

  Widget _loadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'তথ্য প্রস্তুত হচ্ছে...',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
        if (m.isError) {
          return _errorBubble(m);
        }
        return MessageBubble(
          text: m.text,
          isUser: m.isUser,
          animate: m.animate,
          onSpeak: m.isUser || m.isThinking ? null : () => _tts.speak(m.text),
        );
      },
    );
  }

  Widget _errorBubble(_Msg m) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m.text,
                    style: TextStyle(
                      fontSize: ShongjogTheme.bodyFloor,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('আবার চেষ্টা করুন'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => EmergencySheet.show(context),
                  icon: Icon(Icons.call,
                      size: 18, color: Theme.of(context).colorScheme.error),
                  label: Text('৯৯৯ কল',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              ],
            ),
          ],
        ),
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ShongjogTheme.ocean.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _listening ? Icons.mic : Icons.mic_none,
                size: 36,
                color: _listening
                    ? ShongjogTheme.alert
                    : ShongjogTheme.ocean,
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
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => MainShell.goToTab(context, 2),
                icon: const Icon(Icons.style_outlined, size: 18),
                label: const Text('দ্রুত নির্দেশিকা কার্ড দেখুন'),
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
  final bool isThinking;
  final bool isError;
  final bool animate;
  _Msg(this.text, this.isUser,
      {this.isThinking = false, this.isError = false, this.animate = false});
}
