import 'package:flutter/material.dart';
import '../../app/theme.dart';
import 'mesh_service.dart';

class MeshRadarScreen extends StatefulWidget {
  const MeshRadarScreen({super.key});

  @override
  State<MeshRadarScreen> createState() => _MeshRadarScreenState();
}

class _MeshRadarScreenState extends State<MeshRadarScreen> {
  late final MeshService _mesh;
  final List<MeshMessage> _messages = [];
  final _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mesh = MeshService(userName: 'User_${DateTime.now().millisecondsSinceEpoch % 1000}');
    _startMesh();
  }

  Future<void> _startMesh() async {
    await _mesh.start();
    _mesh.messages.listen((m) {
      if (mounted) {
        setState(() {
          _messages.add(m);
        });
      }
    });
  }

  @override
  void dispose() {
    _mesh.stop();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _mesh.sendMessage(text);
    setState(() {
      _messages.add(MeshMessage(senderId: 'Me', text: text));
    });
    _msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('অফলাইন যোগাযোগ রাডার'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: ShongjogTheme.calmTeal.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.radar, color: ShongjogTheme.calmTeal),
                const SizedBox(width: 8),
                StreamBuilder<List<String>>(
                  stream: _mesh.peers,
                  initialData: const [],
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    return Text('নিকটস্থ ডিভাইসের সংখ্যা: $count',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16));
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isMe = m.senderId == 'Me';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? ShongjogTheme.calmTeal : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        hintText: 'মেসেজ লিখুন...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                    color: Colors.white,
                    style: IconButton.styleFrom(backgroundColor: ShongjogTheme.calmTeal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
