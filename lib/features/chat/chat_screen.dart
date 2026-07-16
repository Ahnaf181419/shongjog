import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../app/main_shell.dart';
import '../../core/api_key_store.dart';
import '../../core/connectivity_provider.dart';
import '../../core/haptics.dart';
import '../../core/model_manager.dart';
import '../../knowledge/kb_loader.dart';
import '../../rag/keyword_retriever.dart';
import '../../rag/types.dart';
import '../audio/sound_service.dart';
import '../cloud_ai/cloud_ai_service.dart';
import '../emergency/emergency_sheet.dart';
import '../voice/stt_service.dart';
import '../voice/tts_service.dart';
import 'chat_input.dart';
import 'chat_repository.dart';
import 'chat_store.dart';
import 'demo_seeder.dart';
import 'message_bubble.dart';

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

class _Msg {
  final String text;
  final bool isUser;
  final bool isThinking;
  final bool isError;
  bool animate;
  final GenerationPath? path;
  _Msg(this.text, this.isUser,
      {this.isThinking = false,
      this.isError = false,
      this.animate = false,
      this.path});
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
  bool _autoRead = true;
  bool _voiceInputEnabled = true;
  String? _lastQuery;
  GenerationPath? _lastPath;

  /// Cached result of `modelManager.isAnyOnDisk()` evaluated once at
  /// first app-bar build. Used so the chat-screen status chip can
  /// reflect "a model file is here, even if initialize() hasn't run
  /// yet" without triggering disk I/O on every rebuild.
  bool? _hasLocalModelOnDisk;

  @override
  void initState() {
    super.initState();
    _sound.init();
    _loadPrefsAndBootstrap();
    modelManager.addListener(_onModelManagerChanged);
  }

  @override
  void dispose() {
    modelManager.removeListener(_onModelManagerChanged);
    _stt.dispose();
    super.dispose();
  }

  /// Invalidate the on-disk cache when ModelManager's state changes
  /// (e.g. download completes, `isReady` flips). Without this the
  /// appbar would show stale "অফলাইন (তথ্যকোষ)" until the widget is
  /// rebuilt for some other reason.
  void _onModelManagerChanged() {
    _hasLocalModelOnDisk = null;
    if (mounted) setState(() {});
  }

  Future<void> _loadPrefsAndBootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _autoRead = prefs.getBool('pref_auto_read') ?? false;
    _voiceInputEnabled = prefs.getBool('pref_voice_input') ?? true;

    final saved = await _store.load();
    var restored = saved.reversed
        .map((m) => _Msg(m.text, m.isUser))
        .toList();

    // First-run demo pack: if no chat history exists AND we haven't
    // seeded before, prepend 3 pre-answered Q&As so the chat
    // never looks empty in a judge's hands. Idempotent via the
    // 'pref_demo_seeded_v1' flag.
    if (restored.isEmpty &&
        !(prefs.getBool('pref_demo_seeded_v1') ?? false)) {
      final seeds = DemoSeeder.seeds();
      final seeded = <_Msg>[];
      for (final s in seeds) {
        seeded.add(_Msg(s.question, true));
        seeded.add(_Msg(s.answer, false));
      }
      // Newest-first in memory, oldest-first on disk; reverse so the
      // user sees the first Q&A pair at the top of the list.
      restored = seeded.reversed.toList();
      // Persist so the seed survives app restarts.
      await _store.save(
        seeds
            .expand((s) => [
                  ChatMessage(text: s.question, isUser: true),
                  ChatMessage(text: s.answer, isUser: false),
                ])
            .toList(),
      );
      await prefs.setBool('pref_demo_seeded_v1', true);
    }

    KnowledgeBase? kb;
    try {
      kb = await KnowledgeBase.load();
    } catch (e) {
      debugPrint('KB load error: $e');
    }

    CloudAiService? cloudAi;
    try {
      // Try runtime API key first (from secure storage), then fall back to compile-time
      final keyStore = ApiKeyStore();
      var apiKey = await keyStore.getKey();
      if (apiKey == null || apiKey.isEmpty) {
        apiKey = const String.fromEnvironment('GEMINI_API_KEY');
      }
      if (apiKey.isNotEmpty) {
        cloudAi = CloudAiService(apiKey: apiKey);
      }
    } catch (e) {
      debugPrint('CloudAI init error: $e');
    }

    try {
      await _stt.init();
    } catch (e) {
      debugPrint('STT init error: $e');
    }

    if (mounted) {
      setState(() {
        _messages.addAll(restored);
        _repo = ChatRepository(
          kb: kb ?? _emptyKb(),
          model: modelManager,
          cloudAi: cloudAi,
        );
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
      // Build conversation history for cloud AI (prior turns only, oldest first).
      final history = <ChatTurn>[];
      for (var i = _messages.length - 1; i >= 2; i--) {
        final m = _messages[i];
        if (!m.isThinking) {
          history.add(ChatTurn(text: m.text, isUser: m.isUser));
        }
      }

      final answer = await _repo!.ask(
        _lastQuery!,
        history: history,
        onPath: (path) {
          _lastPath = path;
        },
      );
      if (!mounted) return;
      setState(() => _messages[0] = _Msg(answer, false,
          animate: true, path: _lastPath));
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

  /// Called when TypewriterText finishes its animation for message at [index].
  /// Sets animate=false so subsequent setState calls don't re-trigger it.
  void _markAnimated(int index) {
    if (index >= 0 && index < _messages.length && mounted) {
      setState(() => _messages[index].animate = false);
    }
  }

  /// True when a model file is on disk but `modelManager.isReady` has
  /// not yet flipped — i.e. between cold-boot and the first successful
  /// `initialize()`. Used by the app-bar status to show "অফলাইন এআই"
  /// even when the model hasn't been initialized yet.
  ///
  /// The disk check is cached after the first call because
  /// `isAnyOnDisk()` reads `File.length()` which we don't want running
  /// on every widget rebuild. The cache is invalidated when the
  /// model-manager fires `notifyListeners()` (see [_onModelChanged]).
  bool _hasLocalFileAwaitingInit() {
    final cached = _hasLocalModelOnDisk;
    if (cached != null) return cached;
    // Fire the async probe but return the optimistic default; the
    // second rebuild after `_onModelChanged` fires will show the real
    // result. We also early-return false when no widget is mounted
    // (defensive).
    if (!mounted) return false;
    () async {
      _hasLocalModelOnDisk = await modelManager.isAnyOnDisk();
      if (mounted) setState(() {});
    }();
    return false; // First frame: assume no until probed.
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
            Builder(builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final hasCloud = _repo?.cloudAi != null && connectivityProvider.isOnline;
              // Show "অফলাইন এআই" whenever the offline model is *available*,
              // not only after initialize() has run. Before this fix, the
              // appbar falsely showed "অফলাইন (তথ্যকোষ)" on a freshly-launched
              // app where autoSelectBestModel hadn't yet promoted the on-disk
              // variant — even though `isAnyOnDisk()` would say "yes, a model
              // is here, just give it a moment to cold-start". The user
              // assumed the offline model was broken.
              final hasLocal =
                  modelManager.isReady || _hasLocalFileAwaitingInit();

              String status = 'অফলাইন (তথ্যকোষ)';
              if (hasCloud) {
                status = 'ক্লাউড এআই (Gemma 4)';
              } else if (hasLocal) {
                status = 'অফলাইন এআই (Gemma 4)';
              }

              return Text(
                status,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: hasCloud || hasLocal
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
          key: ValueKey('${m.text.hashCode}_${m.isUser}_$i'),
          text: m.text,
          isUser: m.isUser,
          animate: m.animate,
          path: m.path,
          onSpeak: m.isUser || m.isThinking ? null : () => _tts.speak(m.text),
          onAnimateComplete: m.animate && !m.isUser
              ? () => _markAnimated(i)
              : null,
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
                  _suggestion('গুজব: সাপে কামড়ালে কেটে ফেলা ঠিক?'),
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
