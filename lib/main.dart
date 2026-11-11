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
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8795FF), brightness: Brightness.dark),
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
    const ChatMessage('Hello! I can open supported apps, inspect accessible screen controls, tap a selected control, enter text into a selected field, and go back. No screenshots are taken.', fromUser: false),
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
    if (!mounted) return;
    setState(() => _messages.add(ChatMessage(text, fromUser: fromUser)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    _add(text, fromUser: true);
    final normalized = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();

    if (normalized == 'read screen' || normalized == 'show screen') {
      await _readScreen();
      return;
    }
    if (normalized == 'back' || normalized == 'go back') {
      await _goBack();
      return;
    }
    if (normalized == 'help' || normalized == 'what can you do') {
      _add('Commands: open Chrome, open YouTube, open Settings, open Maps, open Calculator, read screen, back. In Read Screen, choose a visible control or editable field. Every tap and text entry asks for confirmation.', fromUser: false);
      return;
    }
    if (normalized.startsWith('open ')) {
      final app = normalized.substring(5).trim();
      if (_apps.containsKey(app)) {
        final approved = await _confirm('Open ${app[0].toUpperCase()}${app.substring(1)} on this phone?');
        if (approved) await _launch(app);
        else _add('Cancelled. No app was opened.', fromUser: false);
        return;
      }
    }
    _add('I do not understand that command yet. Try “help”. Offline AI language understanding is not integrated yet.', fromUser: false);
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm action'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm')),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _launch(String app) async {
    setState(() => _busy = true);
    try {
      final opened = await _native.invokeMethod<bool>('launchApp', <String, String>{'packageName': _apps[app]!});
      _add(opened == true ? 'Opening ${app[0].toUpperCase()}${app.substring(1)}.' : 'That app is not installed or Android could not open it.', fromUser: false);
    } on PlatformException catch (e) {
      _add('Android error: ${e.message ?? 'Unable to launch app'}.', fromUser: false);
    } on MissingPluginException {
      _add('Android bridge is unavailable. Run this on an Android build.', fromUser: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readScreen() async {
    setState(() => _busy = true);
    try {
      final elements = await _native.invokeListMethod<dynamic>('readVisibleElements');
      if (!mounted) return;
      if (elements == null || elements.isEmpty) {
        _add('No accessible screen elements found. Enable the Accessibility service and open an app with accessible controls.', fromUser: false);
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Visible elements (${elements.length})'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: elements.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (itemContext, index) {
                final item = Map<String, dynamic>.from(elements[index] as Map);
                final label = (item['label'] ?? 'Element').toString();
                final elementIndex = item['index'] as int;
                final clickable = item['clickable'] == true;
                final editable = item['editable'] == true;
                return ListTile(
                  dense: true,
                  title: Text('$elementIndex. $label', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(editable ? 'Editable field' : clickable ? 'Clickable control' : 'Visible text'),
                  trailing: editable ? const Icon(Icons.edit) : clickable ? const Icon(Icons.touch_app) : null,
                  onTap: editable
                      ? () async {
                          Navigator.pop(dialogContext);
                          await _editElement(elementIndex, label);
                        }
                      : clickable
                          ? () async {
                              Navigator.pop(dialogContext);
                              final approved = await _confirm('Tap “$label”?');
                              if (!approved) return;
                              try {
                                final ok = await _native.invokeMethod<bool>('clickElement', {'index': elementIndex});
                                _add(ok == true ? 'Tapped “$label”.' : 'Android could not tap that control. Refresh the screen list and try again.', fromUser: false);
                              } on PlatformException catch (e) {
                                _add(e.message ?? 'Tap failed.', fromUser: false);
                              }
                            }
                          : null,
                );
              },
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
        ),
      );
    } on PlatformException catch (e) {
      _add(e.message ?? 'Could not read the screen. Enable Accessibility first.', fromUser: false);
    } on MissingPluginException {
      _add('Screen reading is available in the Android app build.', fromUser: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editElement(int index, String label) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter text'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            TextField(controller: controller, autofocus: true, maxLength: 2000, decoration: const InputDecoration(hintText: 'Text for selected field')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    final approved = await _confirm('Enter the text you provided into “$label”?');
    if (!approved) return;
    try {
      final ok = await _native.invokeMethod<bool>('enterText', {'index': index, 'text': value});
      _add(ok == true ? 'Text entered into the selected field.' : 'Could not enter text. The screen may have changed; read screen again.', fromUser: false);
    } on PlatformException catch (e) {
      _add(e.message ?? 'Text entry failed.', fromUser: false);
    }
  }

  Future<void> _goBack() async {
    try {
      final ok = await _native.invokeMethod<bool>('goBack');
      _add(ok == true ? 'Went back.' : 'Back action unavailable. Enable Accessibility service first.', fromUser: false);
    } on PlatformException catch (e) {
      _add(e.message ?? 'Back action failed.', fromUser: false);
    }
  }

  Future<void> _serviceStatus() async {
    try {
      final status = await _native.invokeMethod<String>('getAccessibilityStatus');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Accessibility service'),
          content: Text(status == 'enabled'
              ? 'Enabled. The app can inspect accessible controls in the foreground window. Password fields are excluded.'
              : 'Not enabled. Turn on AI Phone Controller in Android Accessibility settings to read and interact with visible controls.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
            if (status != 'enabled')
              FilledButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _native.invokeMethod('openAccessibilitySettings');
                },
                child: const Text('Open settings'),
              ),
          ],
        ),
      );
    } on PlatformException catch (e) {
      _add(e.message ?? 'Could not check accessibility status.', fromUser: false);
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
            IconButton(tooltip: 'Accessibility settings', onPressed: _serviceStatus, icon: const Icon(Icons.accessibility_new)),
            IconButton(tooltip: 'Read screen', onPressed: _busy ? null : _readScreen, icon: const Icon(Icons.document_scanner_outlined)),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: message.fromUser ? const Color(0xFF29345F) : const Color(0xFF171F30),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: .06)),
                    ),
                    child: Text(message.text, style: const TextStyle(fontSize: 15, height: 1.4)),
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
                    child: ActionChip(label: Text(app[0].toUpperCase() + app.substring(1)), onPressed: _busy ? null : () => _send('open $app')),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _busy ? null : () => _send(),
                  icon: const Icon(Icons.arrow_upward_rounded),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF7888F5), foregroundColor: Colors.white, fixedSize: const Size(50, 50)),
                ),
              ]),
            ),
          ),
        ]),
      );
}
