import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AiPhoneControllerApp());

class AiPhoneControllerApp extends StatelessWidget {
  const AiPhoneControllerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AI Phone Controller',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF090D16),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8795FF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const AssistantPage(),
      );
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
  static const _native = MethodChannel('com.example.aiphonecontroller/accessibility');
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [
    const ChatMessage(
      'Hi! I can currently open a small set of apps after you confirm. '
      'This starter works without an internet connection for those commands.',
      fromUser: false,
    ),
  ];
  bool _busy = false;

  static const _apps = <String, String>{
    'chrome': 'com.android.chrome',
    'youtube': 'com.google.android.youtube',
    'settings': 'com.android.settings',
    'maps': 'com.google.android.apps.maps',
    'calculator': 'com.google.android.calculator',
  };

  void _add(String text, {required bool fromUser}) {
    setState(() => _messages.add(ChatMessage(text, fromUser: fromUser)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    _add(text, fromUser: true);

    final normalized = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();
    String? appName;
    if (normalized == 'read screen' || normalized == 'show screen') {\n      await _readScreen();\n      return;\n    }\n    if (normalized == 'back' || normalized == 'go back') {\n      await _goBack();\n      return;\n    }\n    if (normalized.startsWith('open ')) {
      final requested = normalized.substring(5).trim();
      if (_apps.containsKey(requested)) appName = requested;
    }

    final selectedApp = appName;
    if (selectedApp != null) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm app launch'),
          content: Text('Open ${selectedApp[0].toUpperCase()}${selectedApp.substring(1)} on this phone?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Open')),
          ],
        ),
      );
      if (approved != true || !mounted) {
        if (mounted) _add('Cancelled. No app was opened.', fromUser: false);
        return;
      }
      await _launch(selectedApp);
      return;
    }

    if (normalized == 'help' || normalized == 'what can you do') {
      _add(
        'Try: open Chrome, open YouTube, open Settings, open Maps, open Calculator, read screen, or back. '
        'I ask before launching. More advanced AI and UI automation are not installed yet.',
        fromUser: false,
      );
    } else {
      _add(
        'I do not understand that command yet. Try “help” or “open Chrome”. '
        'The offline language model has not been integrated yet.',
        fromUser: false,
      );
    }
  }

  Future<void> _launch(String app) async {
    setState(() => _busy = true);
    try {
      final opened = await _native.invokeMethod<bool>(
        'launchApp',
        <String, String>{'packageName': _apps[app]!},
      );
      _add(opened == true ? 'Opening ${app[0].toUpperCase()}${app.substring(1)}.' :
        'That app is not installed or Android could not open it.', fromUser: false);
    } on PlatformException catch (e) {
      _add('Android error: ${e.message ?? 'Unable to launch app'}.', fromUser: false);
    } on MissingPluginException {
      _add('Android bridge is unavailable. Run this on an Android build.', fromUser: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readScreen() async {
    try {
      final elements = await _native.invokeListMethod<dynamic>('readVisibleElements');
      if (!mounted) return;
      if (elements == null || elements.isEmpty) {
        _add('No accessible elements found. Open another app and ensure its controls are exposed to Android Accessibility.', fromUser: false);
        return;
      }
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Visible screen elements'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: elements.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = Map<String, dynamic>.from(elements[index] as Map);
                final label = (item['label'] ?? 'Element').toString();
                final clickable = item['clickable'] == true;
                final editable = item['editable'] == true;
                return ListTile(
                  dense: true,
                  title: Text('${item['index']}. $label'),
                  subtitle: Text(clickable ? 'Tap target' : editable ? 'Text field' : 'Visible element'),
                  trailing: clickable ? const Icon(Icons.touch_app) : null,
                  onTap: clickable ? () async {
                    Navigator.pop(dialogContext);
                    final approved = await showDialog<bool>(
                      context: this.context,
                      builder: (confirmContext) => AlertDialog(
                        title: const Text('Confirm action'),
                        content: Text('Tap "$label"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(confirmContext, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(confirmContext, true), child: const Text('Tap')),
                        ],
                      ),
                    );
                    if (approved == true) {
                      try {
                        final ok = await _native.invokeMethod<bool>('clickElement', {'index': item['index']});
                        if (mounted) _add(ok == true ? 'Tapped "$label".' : 'Android could not tap "$label".', fromUser: false);
                      } on PlatformException catch (e) {
                        if (mounted) _add(e.message ?? 'Tap failed.', fromUser: false);
                      }
                    }
                  } : null,
                );
              },
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
        ),
      );
    } on PlatformException catch (e) {
      if (mounted) _add(e.message ?? 'Could not read the screen. Enable Accessibility first.', fromUser: false);
    } on MissingPluginException {
      if (mounted) _add('Screen reading is available in the Android app build.', fromUser: false);
    }
  }

  Future<void> _goBack() async {
    try {
      final ok = await _native.invokeMethod<bool>('goBack');
      if (mounted) _add(ok == true ? 'Went back.' : 'Android could not go back.', fromUser: false);
    } on PlatformException catch (e) {
      if (mounted) _add(e.message ?? 'Back action failed.', fromUser: false);
    }
  }

  Future<void> _serviceStatus() async {
    try {
      final status = await _native.invokeMethod<String>('getAccessibilityStatus');
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Accessibility service'),
          content: Text(status == 'enabled'
              ? 'Enabled. The current service only detects foreground app changes.'
              : 'Not enabled. The service is optional and currently only detects foreground app changes.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            if (status != 'enabled')
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _native.invokeMethod('openAccessibilitySettings');
                },
                child: const Text('Open Android settings'),
              ),
          ],
        ),
      );
    } on PlatformException catch (e) {
      if (mounted) _add(e.message ?? 'Could not check accessibility status.', fromUser: false);
    } on MissingPluginException {
      if (mounted) _add('Accessibility status is only available on Android.', fromUser: false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(children: [
            Icon(Icons.auto_awesome, color: Color(0xFF9AA8FF)),
            SizedBox(width: 10),
            Text('AI Phone Controller', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
          actions: [
            IconButton(
              tooltip: 'Accessibility settings',
              onPressed: _serviceStatus,
              icon: const Icon(Icons.accessibility_new),
            ),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                return Align(
                  alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: m.fromUser ? const Color(0xFF29345F) : const Color(0xFF171F30),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: .06)),
                    ),
                    child: Text(m.text, style: const TextStyle(fontSize: 15, height: 1.4)),
                  ),
                );
              },
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                for (final app in _apps.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ActionChip(
                      label: Text(app[0].toUpperCase() + app.substring(1)),
                      onPressed: _busy ? null : () => _send('open $app'),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Try “open Chrome” or “read screen”…',
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
                  onPressed: _busy ? null : () => _send(),
                  icon: const Icon(Icons.arrow_upward_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF7888F5),
                    foregroundColor: Colors.white,
                    fixedSize: const Size(50, 50),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      );
}
