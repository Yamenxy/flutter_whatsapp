import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WhatsApp Chat UI',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        fontFamily: 'Segoe UI',
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _green = Color(0xFF128C4A);
  static const _bubbleGreen = Color(0xFF00A884);
  static const _bubbleDark = Color(0xFF263238);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _isTyping = false;
  bool _isRecording = false;
  DateTime? _recordStartTime;
  String? _currentRecordingPath;
  static const MethodChannel _channel = MethodChannel('whatsapp_chat_ui/recorder');
  bool _isPlaying = false;
  String? _playingPath;

  final List<Map<String, dynamic>> _messages = [
    {'text': 'what a Great Content Tp learn Flutter', 'sent': true},
    {
      'text': 'what a Great Content Tp learn Flutter',
      'sent': false,
      'isImage': true
    },
    {
      'text':
          "Hey! Have you ever thought about how random moments can sometimes turn into the best memories? It's like the universe loves to surprise us when we least expect it!",
      'sent': false
    },
    {'text': 'Hello !', 'sent': false},
    {'text': 'Hello !', 'sent': true},
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _isTyping = _controller.text.trim().isNotEmpty;
      });
    });
    // Listen for native playback completion callbacks
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'playbackComplete') {
        final path = call.arguments as String?;
        if (mounted && path != null) {
          setState(() {
            if (_playingPath == path) {
              _isPlaying = false;
              _playingPath = null;
            }
          });
        }
      }
      return null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.insert(0, {'text': text, 'sent': true});
      _controller.clear();
      _isTyping = false;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      // Ask platform to start recording
      try {
        final res = await _channel.invokeMethod<String>('startAudioRecord');
        if (res == 'started') {
          setState(() {
            _isRecording = true;
            _recordStartTime = DateTime.now();
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Recording...'),
            duration: Duration(milliseconds: 800),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Recorder start failed: $res'),
          ));
        }
      } on PlatformException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Recorder start error: ${e.message}'),
        ));
      }
      return;
    }

    // Stop platform recording
    try {
      final dynamic res = await _channel.invokeMethod('stopAudioRecord');
      setState(() {
        _isRecording = false;
        final start = _recordStartTime ?? DateTime.now();
        final duration = DateTime.now().difference(start);
        final secs = duration.inSeconds;
        final label = secs < 60 ? '${secs}s' : '${(secs / 60).toStringAsFixed(0)}m';
        _recordStartTime = null;
        String? path;
        int? size;
        if (res is Map) {
          path = res['path'] as String?;
          final s = res['size'];
          if (s is int) size = s; else if (s is double) size = s.toInt();
        } else if (res is String) {
          path = res;
        }

        final msg = {
          'text': 'Voice message • $label',
          'sent': true,
          'isAudio': true,
          'duration': secs,
        };
        if (path != null) msg['file'] = path;
        if (size != null) msg['size'] = size;
        _messages.insert(0, msg);
      });
      // show diagnostics about saved file
      try {
        final last = _messages.first;
        final p = last['file'] as String?;
        final s = last['size'];
        if (p != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Saved: $p (${s ?? 'unknown'} bytes)'),
            duration: const Duration(seconds: 2),
          ));
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Recording saved'),
        duration: Duration(milliseconds: 800),
      ));
    } on PlatformException catch (e) {
      setState(() {
        _isRecording = false;
        _recordStartTime = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Recorder stop error: ${e.message}'),
      ));
    }
  }

  Future<void> _togglePlay(String path) async {
    if (_isPlaying && _playingPath == path) {
      // stop
      try {
        await _channel.invokeMethod('stopAudio');
      } on PlatformException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stop error: ${e.message}')));
      }
      setState(() {
        _isPlaying = false;
        _playingPath = null;
      });
      return;
    }

    // start
    try {
      final res = await _channel.invokeMethod<String>('playAudio', {'path': path});
      if (res == 'playing') {
        setState(() {
          _isPlaying = true;
          _playingPath = path;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Play failed: $res')));
      }
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Play error: ${e.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(child: _buildMessages()),
            _buildInputArea(),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1.2),
            ),
            child: ClipOval(
              child: Image.asset(
                'images/profile_image.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  color: Colors.grey.shade800,
                  child: Center(
                    child: Text(
                      'JS',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'John Safwat',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.video_call, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.list, color: Colors.white),
            tooltip: 'Recordings',
            onPressed: _showRecordings,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Future<void> _showRecordings() async {
    try {
      final res = await _channel.invokeMethod('listRecordings');
      List recordings = [];
      if (res is List) recordings = res;

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Recordings'),
          content: SizedBox(
            width: double.maxFinite,
            child: recordings.isEmpty
                ? const Text('No recordings found')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: recordings.length,
                    itemBuilder: (c, i) {
                      final r = recordings[i] as Map;
                      final path = r['path'];
                      final size = r['size'];
                      final mod = r['modified'];
                      return ListTile(
                        title: Text(path.toString().split('/').last),
                        subtitle: Text('$size bytes \n${DateTime.fromMillisecondsSinceEpoch((mod as int))}'),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _togglePlay(path as String);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          ],
        ),
      );
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error listing recordings: ${e.message}')));
    }
  }

  Widget _buildMessages() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'images/background_pattern.png',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.55),
              colorBlendMode: BlendMode.dstATop,
              errorBuilder: (c, e, s) =>
                  Container(color: const Color(0xFF141414)),
            ),
          ),
          ListView.builder(
            controller: _scroll,
            reverse: true,
            padding: const EdgeInsets.only(bottom: 12, top: 14),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              if (msg['isImage'] == true) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Align(
                    alignment: msg['sent']
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: _imageBubble(title: msg['text']),
                  ),
                );
              }
              if (msg['isAudio'] == true) {
                // Determine audio file path if available
                final fileFromField = msg['file'] as String?;
                final textField = msg['text'] as String?;
                final path = fileFromField ?? ((textField != null && textField.contains('/')) ? textField : null);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Align(
                    alignment:
                        msg['sent'] ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        if (path != null) {
                          _togglePlay(path);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Audio file not available'),
                          ));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: msg['sent'] ? _bubbleDark : _bubbleGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (path != null && _isPlaying && _playingPath == path) ? Icons.stop : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              msg['text'] as String? ?? 'Voice message',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Align(
                  alignment: msg['sent']
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: _bubble(msg['text'], isSent: msg['sent']),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text, {required bool isSent, double maxWidth = 300}) {
    final bg = isSent ? _bubbleDark : _bubbleGreen;
    final radius = isSent
        ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(text,
          style:
              const TextStyle(color: Colors.white, fontSize: 14, height: 1.3)),
    );
  }

  Widget _imageBubble({required String title}) {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bubbleGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          Container(
            height: 130,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'images/Camera.png',
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => Center(
                    child: Icon(Icons.image,
                        size: 40, color: Colors.grey.shade400)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt_outlined,
                      color: Colors.white54, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white70),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Type a Message ...',
                        hintStyle:
                            TextStyle(color: Colors.white54, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const Icon(Icons.attachment_outlined,
                      color: Colors.white54, size: 20),
                  const SizedBox(width: 6),
                  // Single circular action button: send when typing, mic (record) when empty
                  GestureDetector(
                    onTap: () {
                      if (_isTyping) {
                        _sendMessage();
                      } else {
                        _toggleRecording();
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isTyping ? _green : (_isRecording ? Colors.redAccent : _bubbleGreen),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_isTyping ? Icons.send : (_isRecording ? Icons.stop : Icons.mic), color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Removed the second control for recording
        ],
      ),
    );
  }
}
