import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'commands.dart';
import 'core.dart';

enum Mode { idle, listening, thinking, building, speaking }

class BuiltApp {
  final String prompt, html, file;
  BuiltApp(this.prompt, this.html, this.file);
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final BuiltApp? builtApp;
  final bool isThinking;
  final String? error;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.builtApp,
    this.isThinking = false,
    this.error,
  });
}

const langNames = {'en_IN': 'English', 'en_US': 'English', 'hi_IN': 'हिन्दी', 'gu_IN': 'ગુજરાતી'};

class Assistant extends ChangeNotifier {
  final settings = Settings.load();
  final tts = FlutterTts();
  final promptCtl = TextEditingController();
  final promptFocus = FocusNode();
  final scrollCtl = ScrollController();
  final keyCtl = TextEditingController();
  final levelN = ValueNotifier<double>(0);
  final items = <BuiltApp>[];
  final messages = <ChatMessage>[];
  final log = <String>[];
  int current = -1, keys = 0;
  String status = '';
  bool statusErr = false, listening = false, busy = false, speaking = false, flash = false;
  bool wakeOnly = false, talk = true, autoJarvis = true;
  String langChoice = 'auto', autoLocale = 'en_IN';
  String _lastCapturedText = '';
  Timer? _wisprSyncTimer;
  Timer? _ollamaTimer;
  List<String> ollamaModels = [];
  bool ollamaOnline = false;
  bool ollamaChecking = false;
  Future<void> _queue = Future.value();

  Assistant() {
    promptCtl.addListener(_onPromptChanged);
    _startWisprSync();
    checkOllamaStatus();
    _ollamaTimer = Timer.periodic(const Duration(seconds: 8), (_) => checkOllamaStatus());
    messages.add(ChatMessage(
      id: 'welcome',
      text: '👋 Hi! I am Jarvis, your voice assistant powered by Wispr Flow.\nSpeak with Wispr Flow (hold CapsLock) or type below, and click Send / "Build it" to create apps & chat in real time.',
      isUser: false,
      timestamp: DateTime.now(),
    ));
    try {
      tts.setStartHandler(() { speaking = true; notifyListeners(); });
      tts.setCompletionHandler(() { speaking = false; notifyListeners(); });
      tts.setErrorHandler((_) { speaking = false; notifyListeners(); });
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollCtl.hasClients) {
        scrollCtl.animateTo(scrollCtl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> checkOllamaStatus({bool manual = false}) async {
    if (ollamaChecking) return;
    ollamaChecking = true;
    if (manual) notifyListeners();

    try {
      final models = await OllamaService.listModels(host: settings.ollamaHost);
      final wasOnline = ollamaOnline;
      ollamaOnline = models.isNotEmpty;
      ollamaModels = models;

      if (ollamaOnline) {
        if (settings.ollamaModel.isEmpty || !models.contains(settings.ollamaModel)) {
          settings.ollamaModel = models.first;
          settings.save();
        }
        // Auto-enable Ollama if user has no API keys added
        if (settings.apiKeys.isEmpty && !settings.useOllama) {
          settings.useOllama = true;
          settings.save();
          setStatus('🦙 Ollama auto-detected with ${models.length} model(s). Offline AI mode enabled!');
        } else if (manual) {
          setStatus('🦙 Ollama connected (${models.length} models: ${models.take(3).join(', ')}${models.length > 3 ? '...' : ''})');
        }
      } else {
        if (settings.useOllama && settings.apiKeys.isNotEmpty) {
          settings.useOllama = false;
          settings.save();
        }
        if (manual) {
          setStatus('Ollama is not running on ${settings.ollamaHost}. Start Ollama to use offline models.', err: true);
        }
      }
    } catch (_) {
      ollamaOnline = false;
    } finally {
      ollamaChecking = false;
      notifyListeners();
    }
  }

  void toggleOllama(bool enabled) {
    settings.useOllama = enabled;
    settings.save();
    if (enabled) {
      if (ollamaModels.isNotEmpty && settings.ollamaModel.isEmpty) {
        settings.ollamaModel = ollamaModels.first;
        settings.save();
      }
      setStatus('🦙 Local Ollama Mode ON (${settings.ollamaModel.isNotEmpty ? settings.ollamaModel : "llama3"}). Cloud API keys disabled.');
    } else {
      setStatus('Cloud API Key Mode ON (${settings.activeKey?.name ?? "No key"}). Local Ollama disabled.');
    }
    notifyListeners();
  }

  void setOllamaModel(String model) {
    settings.ollamaModel = model;
    settings.save();
    setStatus('Ollama model set to: $model');
    notifyListeners();
  }

  void _startWisprSync() {
    _wisprSyncTimer?.cancel();
    _wisprSyncTimer = Timer.periodic(const Duration(milliseconds: 150), (_) async {
      await checkAndApplyWisprFlowText();
    });
  }

  Future<void> onCapsLockReleased() async {
    for (int i = 0; i < 5; i++) {
      await Future.delayed(Duration(milliseconds: 100 + (i * 120)));
      await checkAndApplyWisprFlowText();
    }
  }

  Future<void> checkAndApplyWisprFlowText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = data?.text?.trim() ?? '';
      if (raw.isEmpty || raw == _lastCapturedText || raw.length < 2) return;

      // Filter out CMD commands, paths, URLs, and API keys
      final lower = raw.toLowerCase();
      if (lower.startsWith('set ') || lower.startsWith('cd ') || lower.startsWith('flutter ') ||
          lower.startsWith('xcopy ') || lower.startsWith('mkdir ') || lower.startsWith('dir ') ||
          lower.startsWith('powershell') || lower.startsWith('http://') || lower.startsWith('https://') ||
          lower.startsWith('sk-') || lower.startsWith('aq.') || raw.contains('&&') ||
          raw.contains('C:\\') || raw.contains('s:\\')) {
        return;
      }

      _lastCapturedText = raw;
      if (promptCtl.text.trim() != raw) {
        promptCtl.text = raw;
        promptCtl.selection = TextSelection.fromPosition(TextPosition(offset: raw.length));
        setStatus('🎤 Wispr Flow voice captured: "$raw"');
        notifyListeners();
        _wakeFlash();
      }
    } catch (_) {}
  }

  void _onPromptChanged() {
    if (listening && promptCtl.text.trim().isNotEmpty) {
      listening = false;
      levelN.value = 0;
      notifyListeners();
    }
  }

  void refresh() => notifyListeners();

  Mode get mode => busy ? Mode.building : speaking ? Mode.speaking : flash ? Mode.thinking : listening ? Mode.listening : Mode.idle;
  String get locale => langChoice == 'auto' ? autoLocale : langChoice;
  BuiltApp? get now => current >= 0 && current < items.length ? items[current] : null;

  static final _mods = {
    LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaRight, LogicalKeyboardKey.capsLock,
  };

  /// Zero-keyboard proof. Ignores modifiers and Ctrl/Cmd combos (dictation tools paste with Ctrl+V).
  void countKey(LogicalKeyboardKey k) {
    if (k == LogicalKeyboardKey.capsLock) {
      promptFocus.requestFocus();
      onCapsLockReleased();
      return;
    }
    if (_mods.contains(k)) return;
    if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed) return;
    keys++;
    notifyListeners();
  }

  void addLog(String t) {
    log.insert(0, t);
    if (log.length > 20) log.removeLast();
    notifyListeners();
  }

  void setStatus(String t, {bool err = false}) {
    status = t;
    statusErr = err;
    notifyListeners();
  }

  Future<void> say(String t) async {
    addLog(t);
    if (!talk) return;
    try {
      await tts.setLanguage(locale.replaceAll('_', '-'));
      await tts.speak(t);
    } catch (_) {
      speaking = false;
    }
  }

  // ---------- Wispr Flow Voice Integration ----------
  Future<void> toggleListening() async => listening ? stopListening() : startListening();

  Future<void> startListening() async {
    promptFocus.requestFocus();
    listening = true;
    levelN.value = 0.85;
    setStatus('Wispr Flow listening… Hold CapsLock and speak your prompt.');
    notifyListeners();
  }

  Future<void> stopListening() async {
    listening = false;
    levelN.value = 0;
    notifyListeners();
  }

  void setLang(String choice) {
    langChoice = choice;
    if (choice == 'auto') autoLocale = 'en_IN';
    notifyListeners();
  }

  // ---------- commands ----------
  void handleUtterance(String raw) {
    final p = parseUtterance(raw, wakeOnly: wakeOnly);
    if (p.ignored) { addLog('(ignored) $raw'); return; }
    if (p.woke) _wakeFlash();
    _queue = _queue.then((_) async {
      for (final c in p.cmds) {
        await _exec(c);
      }
    });
  }

  void _wakeFlash() {
    flash = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 700), () { flash = false; notifyListeners(); });
  }

  Future<void> _go(int i) async {
    if (i >= 0 && i < items.length) { current = i; notifyListeners(); await say('Showing app ${i + 1}.'); } else { await say('No app there.'); }
  }

  Future<void> _pc(Future<Res> f, String ok, String fail) async {
    final r = await f;
    await say(r.ok ? ok : '$fail${r.error != null ? ': ${r.error}' : '.'}');
  }

  Future<void> _exec(Cmd c) async {
    switch (c.type) {
      case CmdType.build:
        promptCtl.text = c.arg; addLog('▶ build ${c.arg}'); await say('Building.'); await run(false);
      case CmdType.remix:
        if (now == null) { await say('Build something first.'); return; }
        promptCtl.text = c.arg; addLog('▶ change ${c.arg}'); await say('Changing it.'); await run(true);
      case CmdType.saved:
        await say(now == null ? 'Nothing to save yet.' : 'Saved at ${now!.file}');
      case CmdType.back: await _go(current - 1);
      case CmdType.next: await _go(current + 1);
      case CmdType.openIndex: await _go((int.tryParse(c.arg) ?? 0) - 1);
      case CmdType.openFile:
        if (now == null) { await say('Nothing to open.'); return; }
        await _pc(PcControl.openPath(now!.file), 'Opening it.', "Couldn't open it");
      case CmdType.clear: promptCtl.clear(); await say('Cleared.');
      case CmdType.read:
        await say(now == null ? 'No app yet.' : 'Showing app ${current + 1} of ${items.length}: ${now!.prompt}');
      case CmdType.help:
        await say('Tell me what application to build, or what to open on your PC.');
      case CmdType.lang:
        setLang(c.arg); await say('OK.');
      case CmdType.stop: await say('Going quiet.'); await stopListening();
      case CmdType.folder: await _pc(PcControl.openFolder(), 'Opening your builds folder.', "Couldn't open the folder");
      case CmdType.url: addLog('▶ open site ${c.arg}'); await _pc(PcControl.openUrl(c.arg), 'Opening ${c.arg}.', "Couldn't open the site");
      case CmdType.app: addLog('▶ open app ${c.arg}'); await _pc(PcControl.openApp(c.arg), 'Opening ${c.arg}.', "Couldn't open ${c.arg}");
      case CmdType.greet:
        setStatus('Jarvis thinking…');
        final reply = await chatWithAi(
          settings.effectiveKey,
          c.arg,
          provider: settings.useOllama ? ApiProvider.ollama : settings.activeKey?.provider,
          ollamaHost: settings.ollamaHost,
          ollamaModel: settings.ollamaModel,
          useOllama: settings.useOllama,
        );
        setStatus('Jarvis: $reply');
        await say(reply);
      case CmdType.dictation:
        final trimmedArg = c.arg.trim();
        if (trimmedArg.isNotEmpty && !promptCtl.text.contains(trimmedArg)) {
          promptCtl.text = trimmedArg;
        }
        addLog('✎ $trimmedArg');
        if (autoJarvis && trimmedArg.isNotEmpty) {
          setStatus('Jarvis thinking…');
          final reply = await chatWithAi(
            settings.effectiveKey,
            trimmedArg,
            provider: settings.useOllama ? ApiProvider.ollama : settings.activeKey?.provider,
            ollamaHost: settings.ollamaHost,
            ollamaModel: settings.ollamaModel,
            useOllama: settings.useOllama,
          );
          setStatus('Jarvis: $reply');
          await say(reply);
        }
    }
  }

  Future<void> submitPrompt([String? inputPrompt, bool remix = false]) async {
    final prompt = (inputPrompt ?? promptCtl.text).trim();
    if (prompt.isEmpty) {
      setStatus('Say or type what you want to build.', err: true);
      return;
    }

    promptCtl.clear();
    final userMsg = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      text: prompt,
      isUser: true,
      timestamp: DateTime.now(),
    );
    messages.add(userMsg);

    final isOllama = settings.useOllama || (settings.apiKeys.isEmpty && ollamaOnline && ollamaModels.isNotEmpty);
    if (!settings.useOllama && isOllama) {
      settings.useOllama = true;
      settings.save();
    }

    final active = settings.activeKey;
    final key = settings.effectiveKey;
    if (!isOllama && key.isEmpty) {
      messages.add(ChatMessage(
        id: 'err_${DateTime.now().millisecondsSinceEpoch}',
        text: '⚠️ No API key or Ollama model configured. Please add an API key or enable local Ollama in Settings below.',
        isUser: false,
        timestamp: DateTime.now(),
        error: 'No API key',
      ));
      setStatus('No API key or Ollama model configured.', err: true);
      _scrollToBottom();
      notifyListeners();
      return;
    }

    busy = true;
    final thinkingMsg = ChatMessage(
      id: 'thinking_${DateTime.now().millisecondsSinceEpoch}',
      text: 'Thinking & generating code with ${isOllama ? "Local Ollama (${settings.ollamaModel.isNotEmpty ? settings.ollamaModel : "llama3"})" : (active != null ? active.name : "AI")}…',
      isUser: false,
      isThinking: true,
      timestamp: DateTime.now(),
    );
    messages.add(thinkingMsg);
    setStatus('Thinking & generating…');
    notifyListeners();
    _scrollToBottom();

    // Check if this is a build/code creation request vs a pure conversation query
    final lower = prompt.toLowerCase();
    final isBuildIntent = remix ||
        RegExp(r'^(?:build|create|make|generate|code|banao|change|remix|modify|program|design|write)\s+', caseSensitive: false).hasMatch(prompt) ||
        lower.contains('game') || lower.contains('app') || lower.contains('page') || lower.contains('calculator') ||
        lower.contains('tool') || lower.contains('website') || lower.contains('todo') || lower.contains('dashboard') ||
        lower.contains('timer') || lower.contains('clock') || lower.contains('canvas') || lower.contains('simulator');

    try {
      if (isBuildIntent) {
        final r = await buildApp(
          key,
          prompt,
          previous: remix ? now?.html : null,
          provider: isOllama ? ApiProvider.ollama : active?.provider,
          ollamaHost: settings.ollamaHost,
          ollamaModel: settings.ollamaModel.isNotEmpty ? settings.ollamaModel : ollamaModels.firstOrNull,
        );
        final app = BuiltApp(prompt, r.html, r.file);
        items.add(app);
        current = items.length - 1;
        addLog('Saved: ${r.file}');

        var opened = false;
        if (settings.openBuilt) opened = (await PcControl.openPath(r.file)).ok;
        if (settings.notify) {
          final n = await notifyPhone(settings.topic, 'Bolo & Build: work complete',
              'Your app "${prompt.length > 80 ? prompt.substring(0, 80) : prompt}" is ready. Saved to ${r.file}${opened ? ' and opened on your PC.' : '.'}');
          if (n.ok) addLog('📱 Phone notified');
        }

        messages.removeWhere((m) => m.id == thinkingMsg.id);
        messages.add(ChatMessage(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
          text: '✨ I created "$prompt" for you! You can run it, view live code on the right, or tell me changes to remix it.',
          isUser: false,
          timestamp: DateTime.now(),
          builtApp: app,
        ));

        setStatus('Done! App built & saved.');
        busy = false;
        notifyListeners();
        _scrollToBottom();
        await say('Your app is ready.');
      } else {
        // Conversational query
        final reply = await chatWithAi(
          key,
          prompt,
          provider: isOllama ? ApiProvider.ollama : active?.provider,
          ollamaHost: settings.ollamaHost,
          ollamaModel: settings.ollamaModel,
          useOllama: isOllama,
        );

        messages.removeWhere((m) => m.id == thinkingMsg.id);
        messages.add(ChatMessage(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
          text: reply,
          isUser: false,
          timestamp: DateTime.now(),
        ));

        setStatus('Jarvis: $reply');
        busy = false;
        notifyListeners();
        _scrollToBottom();
        await say(reply);
      }
    } on BuildError catch (e) {
      messages.removeWhere((m) => m.id == thinkingMsg.id);
      messages.add(ChatMessage(
        id: 'err_${DateTime.now().millisecondsSinceEpoch}',
        text: '❌ Build error: ${e.message}',
        isUser: false,
        timestamp: DateTime.now(),
        error: e.message,
      ));
      busy = false;
      setStatus(e.message, err: true);
      notifyListeners();
      _scrollToBottom();
    } catch (e) {
      messages.removeWhere((m) => m.id == thinkingMsg.id);
      messages.add(ChatMessage(
        id: 'err_${DateTime.now().millisecondsSinceEpoch}',
        text: '❌ Something went wrong while generating: $e',
        isUser: false,
        timestamp: DateTime.now(),
        error: e.toString(),
      ));
      busy = false;
      setStatus('Generation failed.', err: true);
      notifyListeners();
      _scrollToBottom();
    }
  }

  Future<void> run(bool remix) async => submitPrompt(null, remix);

  Future<void> addApiKey(String k) async {
    final v = k.trim();
    if (v.isEmpty) {
      setStatus("Please paste a valid API key.", err: true);
      return;
    }
    if (settings.apiKeys.length >= 10) {
      setStatus("Maximum 10 API keys allowed. Please delete an existing key first.", err: true);
      return;
    }

    // Check if already exists
    if (settings.apiKeys.any((entry) => entry.key == v)) {
      setStatus("This API key has already been added.", err: true);
      return;
    }

    final provider = ApiKeyEntry.detectProvider(v);
    final count = settings.apiKeys.where((entry) => entry.provider == provider).length + 1;
    final name = ApiKeyEntry.suggestName(v, provider, count);
    final id = 'key_${DateTime.now().millisecondsSinceEpoch}';

    final entry = ApiKeyEntry(
      id: id,
      name: name,
      key: v,
      provider: provider,
      status: 'testing',
      addedAt: DateTime.now(),
    );

    settings.apiKeys.add(entry);
    if (settings.apiKeys.length == 1 || settings.activeKeyId.isEmpty) {
      settings.activeKeyId = id;
    }
    settings.save();
    notifyListeners();
    setStatus('Added ${entry.name}. Testing connection…');

    // Asynchronously test the key
    testApiKey(entry);
  }

  Future<void> testApiKey(ApiKeyEntry entry) async {
    entry.status = 'testing';
    entry.lastError = null;
    notifyListeners();

    final res = await ApiKeyEntry.testKey(entry.key, entry.provider);
    if (res.ok) {
      entry.status = 'valid';
      entry.lastError = null;
      setStatus('✓ Verified: ${entry.name} is valid and working!');
    } else {
      entry.status = 'invalid';
      entry.lastError = res.error;
      setStatus('✗ ${entry.name} failed verification: ${res.error ?? "Invalid key"}', err: true);
    }
    settings.save();
    notifyListeners();
  }

  void setActiveApiKey(String id) {
    settings.activeKeyId = id;
    settings.save();
    notifyListeners();
    final active = settings.activeKey;
    if (active != null) {
      setStatus('Active key switched to: ${active.name}');
    }
  }

  void deleteApiKey(String id) {
    settings.apiKeys.removeWhere((e) => e.id == id);
    if (settings.activeKeyId == id) {
      settings.activeKeyId = settings.apiKeys.isNotEmpty ? settings.apiKeys.first.id : '';
    }
    settings.save();
    notifyListeners();
    setStatus('API key removed.');
  }

  void renameApiKey(String id, String newName) {
    final entry = settings.apiKeys.where((e) => e.id == id).firstOrNull;
    if (entry != null && newName.trim().isNotEmpty) {
      entry.name = newName.trim();
      settings.save();
      notifyListeners();
    }
  }

  Future<void> saveKey(String k) async => addApiKey(k);

  Future<void> testPhone() async {
    final r = await notifyPhone(settings.topic, 'Bolo & Build', 'Test: your phone is connected.');
    setStatus(r.ok ? 'Test sent. Check your phone.' : 'Could not send: ${r.error}', err: !r.ok);
  }

  void updateSettings({bool? notify, bool? openBuilt}) {
    if (notify != null) settings.notify = notify;
    if (openBuilt != null) settings.openBuilt = openBuilt;
    settings.save();
    notifyListeners();
  }
}
