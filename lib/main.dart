import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'command_parser.dart';

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
    const ChatMessage('AI Phone Controller ready. Try “open Chrome”, “read screen”, or a sequence such as “open Chrome then read screen then back”. Each action is confirmed separately.', fromUser: false),
  ];
  bool _busy = false;
  bool _workflowRunning = false;
  bool _cancelWorkflow = false;

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

  String _normalize(String value) => AutomationCommandParser.normalize(value);

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    _add(text, fromUser: true);
    final normalized = _normalize(text);
    setState(() => _busy = true);
    try {
      if (normalized == 'read screen' || normalized == 'show screen') {
        await _readScreen();
        return;
      }
      if (normalized == 'back' || normalized == 'go back') {
        await _goBack();
        return;
      }
      if (normalized == 'help' || normalized == 'what can you do') {
        _add('Single actions: open Chrome/YouTube/Settings/Maps/Calculator, read screen, back. Multi-step: join actions with “then”, for example “open Chrome then read screen then back”. You can also use “tap 4” or “enter 4 hello” after reading the current screen. Each step is confirmed. Maximum 8 steps per workflow.', fromUser: false);
        return;
      }
      final steps = _splitWorkflow(normalized);
      if (steps.length > 1) {
        await _runWorkflow(steps);
        return;
      }
      await _runStep(normalized);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<String> _splitWorkflow(String text) {
    return AutomationCommandParser.split(text);
  }

  Future<void> _runWorkflow(List<String> steps) async {
    if (steps.length > 8) {
      _add('This workflow has ${steps.length} steps. The limit is 8; split it into smaller workflows.', fromUser: false);
      return;
    }
    final supported = steps.every(_isSupportedStep);
    if (!supported) {
      _add('One step is not supported. Use help to see supported actions. Nothing was executed.', fromUser: false);
      return;
    }
    _cancelWorkflow = false;
    _workflowRunning = true;
    _add('Starting workflow with ${steps.length} steps. You will confirm each action separately.', fromUser: false);
    for (var i = 0; i < steps.length; i++) {
      if (_cancelWorkflow || !mounted) {
        _add('Workflow cancelled. Remaining steps were skipped.', fromUser: false);
        _workflowRunning = false;
        return;
      }
      _add('Step ${i + 1}/${steps.length}: ${steps[i]}', fromUser: false);
      final success = await _runStep(steps[i], workflow: true);
      if (!success) {
        _add('Workflow stopped at step ${i + 1}. Remaining steps were not run.', fromUser: false);
        _workflowRunning = false;
        return;
      }
    }
    _add('Workflow finished.', fromUser: false);
    _workflowRunning = false;
  }

  bool _isSupportedStep(String step) {
    if (step == 'read screen' || step == 'show screen' || step == 'back' || step == 'go back') return true;
    if (step.startsWith('open ') && _apps.containsKey(step.substring(5).trim())) return true;
    if (RegExp(r'^tap [0-9]+$').hasMatch(step)) return true;
    return RegExp(r'^enter [0-9]+ .+$').hasMatch(step);
  }

  Future<bool> _runStep(String command, {bool workflow = false}) async {
    if (command == 'read screen' || command == 'show screen') {
      await _readScreen();
      return true;
    }
    if (command == 'back' || command == 'go back') {
      return _goBack(confirm: true);
    }
    if (command.startsWith('open ')) {
      final app = command.substring(5).trim();
      if (!_apps.containsKey(app)) {
        _add('Unsupported app: $app. Allowed apps: ${_apps.keys.join(', ')}.', fromUser: false);
        return false;
      }
      final approved = await _confirm('Open ${app[0].toUpperCase()}${app.substring(1)}?');
      if (!approved) {
        _add('Step cancelled.', fromUser: false);
        return false;
      }
      return _launch(app);
    }
    final tapMatch = RegExp(r'^tap ([0-9]+)$').firstMatch(command);
    if (tapMatch != null) return _tapIndex(int.parse(tapMatch.group(1)!));
    final enterMatch = RegExp(r'^enter ([0-9]+) (.+)$').firstMatch(command);
    if (enterMatch != null) return _enterIndex(int.parse(enterMatch.group(1)!), enterMatch.group(2)!);
    _add('Unsupported command. Type “help”.', fromUser: false);
    return false;
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

  Future<bool> _launch(String app) async {
    try {
      final opened = await _native.invokeMethod<bool>('launchApp', <String, String>{'packageName': _apps[app]!});
      _add(opened == true ? 'Opened ${app[0].toUpperCase()}${app.substring(1)}.' : 'That app is not installed or Android could not open it.', fromUser: false);
      return opened == true;
    } on PlatformException catch (e) {
      _add('Android error: ${e.message ?? 'Unable to launch app'}.', fromUser: false);
      return false;
    } on MissingPluginException {
      _add('Android bridge is unavailable. Run this on an Android build.', fromUser: false);
      return false;
    }
  }

  Future<bool> _tapIndex(int index) async {
    final approved = await _confirm('Tap visible element number $index? Make sure it is the intended control.');
    if (!approved) return false;
    try {
      final ok = await _native.invokeMethod<bool>('clickElement', {'index': index});
      _add(ok == true ? 'Tapped element $index.' : 'Tap failed. Read screen again because the app may have changed.', fromUser: false);
      return ok == true;
    } on PlatformException catch (e) {
      _add(e.message ?? 'Tap failed.', fromUser: false);
      return false;
    }
  }

  Future<bool> _enterIndex(int index, String value) async {
    final approved = await _confirm('Enter the text you supplied into visible field $index?');
    if (!approved) return false;
    try {
      final ok = await _native.invokeMethod<bool>('enterText', {'index': index, 'text': value});
      _add(ok == true ? 'Text entered into field $index.' : 'Text entry failed. Read screen again.', fromUser: false);
      return ok == true;
    } on PlatformException catch (e) {
      _add(e.message ?? 'Text entry failed.', fromUser: false);
      return false;
    }
  }

  Future<void> _readScreen() async {
    try {
      final elements = await _native.invokeListMethod<dynamic>('readVisibleElements');
      if (!mounted) return;
      if (elements == null || elements.isEmpty) {
        _add('No accessible elements found. Enable the Accessibility service and open an app with accessible controls.', fromUser: false);
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
                  onTap: editable ? () async {
                    Navigator.pop(dialogContext);
                    final value = await _askText(label);
                    if (value != null) await _enterIndex(elementIndex, value);
                  } : clickable ? () async {
                    Navigator.pop(dialogContext);
                    await _tapIndex(elementIndex);
                  } : null,
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
    }
  }

  Future<String?> _askText(String label) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter text'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          TextField(controller: controller, autofocus: true, maxLength: 2000),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _goBack({bool confirm = true}) async {
    if (confirm && !await _confirm('Perform Android Back action?')) return false;
    try {
      final ok = await _native.invokeMethod<bool>('goBack');
      _add(ok == true ? 'Went back.' : 'Back action unavailable. Enable Accessibility service first.', fromUser: false);
      return ok == true;
    } on PlatformException catch (e) {
      _add(e.message ?? 'Back action failed.', fromUser: false);
      return false;
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
              ? 'Enabled. The app reads the accessible foreground UI only when requested. Password fields are excluded; no screenshots are captured.'
              : 'Not enabled. Turn on AI Phone Controller in Android Accessibility settings to read and interact with visible controls.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
            if (status != 'enabled') FilledButton(
              onPressed: () async { Navigator.pop(dialogContext); await _native.invokeMethod('openAccessibilitySettings'); },
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
            if (_workflowRunning) IconButton(tooltip: 'Cancel workflow', onPressed: () { _cancelWorkflow = true; _add('Workflow cancellation requested.', fromUser: false); }, icon: const Icon(Icons.stop_circle_outlined)),
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
                ActionChip(label: const Text('Read screen'), onPressed: _busy ? null : () => _send('read screen')),
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
                      hintText: 'Try “open Chrome then read screen”…',
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
