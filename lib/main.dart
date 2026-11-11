import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AiPhoneControllerApp());

class AiPhoneControllerApp extends StatelessWidget {
  const AiPhoneControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Phone Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C8CFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AssistantPage(),
    );
  }
}

class ChatMessage {
  const ChatMessage(this.text, {required this.fromUser});
  final String text;
  final bool fromUser;
}

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  static const _platform = MethodChannel('com.example.aiphonecontroller/accessibility');
  final _controller = TextEditingController();
  final _messages = <ChatMessage>[
    const ChatMessage(
      'Hello! I am your on-device phone assistant. What would you like to do?',
      fromUser: false,
    ),
  ];
  bool _working = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _working) return;
    setState(() {
      _messages.add(ChatMessage(text, fromUser: true));
      _controller.clear();
      _working = true;
    });

    String reply;
    try {
      final status = await _platform.invokeMethod<String>('getAccessibilityStatus');
      reply = status == 'enabled'
          ? 'Accessibility service is connected. Action execution is not enabled yet; this starter currently checks service status only.'
          : 'Your command is noted. To enable supported UI interaction later, first turn on the app\'s Accessibility Service in Android Settings.';
    } on PlatformException catch (e) {
      reply = 'Android bridge error: ${e.message ?? 'unknown error'}';
    } on MissingPluginException {
      reply = 'Android bridge is not available yet. Run this app on Android after generating the Flutter platform files.';
    }

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(reply, fromUser: false));
      _working = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF9AA8FF)),
            SizedBox(width: 10),
            Text('AI Phone Controller', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Accessibility status',
            onPressed: _checkStatus,
            icon: const Icon(Icons.accessibility_new),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 310),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: message.fromUser
                          ? const Color(0xFF29345F)
                          : const Color(0xFF171F30),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Text(message.text, style: const TextStyle(fontSize: 15, height: 1.4)),
                  ),
                );
              },
            ),
          ),
          if (_working)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Message your assistant…',
                        filled: true,
                        fillColor: const Color(0xFF151D2B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _working ? null : _send,
                    icon: const Icon(Icons.arrow_upward_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF7888F5),
                      foregroundColor: Colors.white,
                      fixedSize: const Size(50, 50),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkStatus() async {
    try {
      final status = await _platform.invokeMethod<String>('getAccessibilityStatus');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'enabled'
            ? 'Accessibility service connected'
            : 'Accessibility service is not enabled')),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not read service status')),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run on Android after creating the platform scaffold')),
      );
    }
  }
}
