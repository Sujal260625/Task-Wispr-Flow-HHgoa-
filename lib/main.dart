import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'controller.dart';
import 'core.dart';

const bg = Color(0xFF130B1D), panel = Color(0xFF1F122B), line = Color(0xFF3B2050), ink = Color(0xFFF6ECDC), dim = Color(0xFFB09CBF);
const gold = Color(0xFFFFB52E), rose = Color(0xFFFF5D8F), purple = Color(0xFF9D4EDD), green = Color(0xFF4CAF50);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final a = Assistant();
  HardwareKeyboard.instance.addHandler((KeyEvent e) {
    if (e is KeyDownEvent) {
      if (e.logicalKey == LogicalKeyboardKey.capsLock) {
        a.promptFocus.requestFocus();
      }
      a.countKey(e.logicalKey);
    }
    if (e is KeyUpEvent && e.logicalKey == LogicalKeyboardKey.capsLock) {
      a.promptFocus.requestFocus();
      a.onCapsLockReleased();
    }
    return false;
  });
  runApp(BoloApp(a));
}

class BoloApp extends StatelessWidget {
  final Assistant a;
  const BoloApp(this.a, {super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Bolo & Build',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
          colorScheme: const ColorScheme.dark(primary: gold, surface: panel),
          useMaterial3: true,
        ),
        home: Home(a),
      );
}

class Home extends StatefulWidget {
  final Assistant a;
  const Home(this.a, {super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    return Scaffold(
      body: Stack(children: [
        AnimatedBuilder(
          animation: a,
          builder: (_, __) => Column(children: [
            _header(),
            const Divider(height: 1, color: line),
            Expanded(child: Row(children: [
              // Left: Chat & Conversation Stream
              Expanded(flex: 5, child: _chatAndInputSection(context)),
              const VerticalDivider(width: 1, color: line),
              // Right: Claude Artifacts Code & Preview Panel
              Expanded(flex: 4, child: _artifactsPanel()),
            ])),
          ]),
        ),
        Positioned.fill(child: IgnorePointer(child: AuroraLayer(a))),
      ]),
    );
  }

  Widget _header() {
    final a = widget.a;
    final isOllama = a.settings.useOllama;
    final activeKey = a.settings.activeKey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(children: [
        const Text.rich(TextSpan(children: [
          TextSpan(text: 'Bolo '),
          TextSpan(text: '&', style: TextStyle(color: gold)),
          TextSpan(text: ' Build'),
        ]), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(width: 12),
        InkWell(
          onTap: () => PcControl.openUrl('https://wisprflow.ai/r?SUJAL482'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF2E1B42),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: purple, width: 1.5),
              boxShadow: [BoxShadow(color: purple.withOpacity(0.3), blurRadius: 8)],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq, size: 15, color: Color(0xFFE0AAFF)),
                SizedBox(width: 5),
                Text('Powered by Wispr Flow', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE0AAFF))),
                SizedBox(width: 4),
                Icon(Icons.open_in_new, size: 11, color: Color(0xFFC77DFF)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Active AI Engine Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isOllama ? green.withOpacity(0.15) : (activeKey != null ? gold.withOpacity(0.15) : rose.withOpacity(0.15)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isOllama ? green : (activeKey != null ? gold : rose)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isOllama ? Icons.memory : Icons.cloud_done, size: 13, color: isOllama ? green : (activeKey != null ? gold : rose)),
              const SizedBox(width: 5),
              Text(
                isOllama ? '🦙 Ollama (${a.settings.ollamaModel.isNotEmpty ? a.settings.ollamaModel : "local"})' : (activeKey != null ? activeKey.name : 'No API key'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOllama ? green : (activeKey != null ? gold : rose)),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Settings Button
        TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: _showSettings ? gold.withOpacity(0.2) : panel,
            foregroundColor: _showSettings ? gold : ink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: line)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          icon: Icon(_showSettings ? Icons.close : Icons.tune, size: 16),
          label: Text(_showSettings ? 'Close Settings' : 'Settings & Keys', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          onPressed: () => setState(() => _showSettings = !_showSettings),
        ),
        const SizedBox(width: 10),
        // Zero Keyboard Counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: a.keys == 0 ? gold : rose, width: 2),
            boxShadow: [BoxShadow(color: (a.keys == 0 ? gold : rose).withOpacity(.3), blurRadius: 12)],
          ),
          child: Text('Keys typed: ${a.keys}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: a.keys == 0 ? gold : rose)),
        ),
      ]),
    );
  }

  Widget _chatAndInputSection(BuildContext context) {
    final a = widget.a;
    return Column(
      children: [
        if (_showSettings)
          Container(
            height: 320,
            decoration: const BoxDecoration(color: Color(0xFF170C22), border: Border(bottom: BorderSide(color: line, width: 2))),
            child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _pcPanel()),
          ),
        // Chat Stream
        Expanded(
          child: ListView.builder(
            controller: a.scrollCtl,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            itemCount: a.messages.length,
            itemBuilder: (ctx, i) => _chatBubble(a.messages[i]),
          ),
        ),
        // Floating Prompt Input Capsule (OpenAI / Claude style)
        _bottomInputCapsule(),
      ],
    );
  }

  Widget _chatBubble(ChatMessage msg) {
    final a = widget.a;
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF331648),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: purple.withOpacity(0.5)),
            boxShadow: [BoxShadow(color: purple.withOpacity(0.15), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('You', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: gold)),
                  SizedBox(width: 4),
                  Icon(Icons.person, size: 13, color: gold),
                ],
              ),
              const SizedBox(height: 4),
              Text(msg.text, style: const TextStyle(fontSize: 14, height: 1.4, color: ink)),
            ],
          ),
        ),
      );
    }

    if (msg.isThinking) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, right: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1029),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: gold.withOpacity(0.7), width: 1.5),
            boxShadow: [BoxShadow(color: gold.withOpacity(0.2), blurRadius: 14)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: gold)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(msg.text, style: const TextStyle(fontSize: 13, color: gold, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    // AI Message
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1B0E27),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: purple.withOpacity(0.3), shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome, size: 12, color: Color(0xFFE0AAFF)),
                ),
                const SizedBox(width: 6),
                const Text('Jarvis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE0AAFF))),
                const SizedBox(width: 6),
                Text(
                  '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, color: dim),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(msg.text, style: const TextStyle(fontSize: 13.5, height: 1.45, color: ink)),
            if (msg.builtApp != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF261337),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: purple.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.code, color: gold, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            msg.builtApp!.prompt,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: gold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: gold,
                            foregroundColor: Colors.black,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.play_arrow, size: 14),
                          label: const Text('Run App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => PcControl.openPath(msg.builtApp!.file),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.folder_open, size: 14),
                          label: const Text('Folder', style: TextStyle(fontSize: 12)),
                          onPressed: () => PcControl.openFolder(),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.visibility, size: 14),
                          label: const Text('View Code', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            final idx = a.items.indexOf(msg.builtApp!);
                            if (idx >= 0) {
                              a.current = idx;
                              a.refresh();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bottomInputCapsule() {
    final a = widget.a;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: line, width: 1)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: a.listening ? rose : purple.withOpacity(0.6), width: 1.5),
          boxShadow: [BoxShadow(color: (a.listening ? rose : purple).withOpacity(0.2), blurRadius: 14)],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                // Push-to-talk Mic Icon
                GestureDetector(
                  onTap: a.toggleListening,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: a.listening
                            ? const [Color(0xFFFFC2D6), rose, Color(0xFF8A1A45)]
                            : const [Color(0xFFFFE29A), gold, Color(0xFFB06A00)],
                      ),
                    ),
                    child: Icon(a.listening ? Icons.mic : Icons.mic_none, color: Colors.black, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    a.listening ? '🎤 Wispr Flow listening… Speak your prompt' : 'Hold CapsLock & speak into Wispr Flow, or type below',
                    style: TextStyle(fontSize: 11, color: a.listening ? rose : dim, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
                  icon: const Icon(Icons.content_paste, size: 13, color: gold),
                  label: const Text('Paste Dictation', style: TextStyle(fontSize: 11, color: gold)),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                      a.promptCtl.text = data.text!.trim();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: a.promptCtl,
              focusNode: a.promptFocus,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Type or speak your prompt... (e.g. "Build a calculator app", "Myself Sujal, how are you?")',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
              onSubmitted: (_) {
                if (!a.busy) a.submitPrompt();
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                DropdownButton<String>(
                  value: a.langChoice,
                  isDense: true,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 11, color: dim),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('🌐 Auto Language')),
                    DropdownMenuItem(value: 'en_IN', child: Text('🇮🇳 English (India)')),
                    DropdownMenuItem(value: 'hi_IN', child: Text('🇮🇳 हिन्दी')),
                    DropdownMenuItem(value: 'gu_IN', child: Text('🇮🇳 ગુજરાતી')),
                    DropdownMenuItem(value: 'en_US', child: Text('🇺🇸 English (US)')),
                  ],
                  onChanged: (v) => a.setLang(v ?? 'auto'),
                ),
                const Spacer(),
                if (a.now != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Change it'),
                    onPressed: a.busy ? null : () => a.run(true),
                  ),
                const SizedBox(width: 8),
                // Build it / Send Button (Only starts when clicked!)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: a.busy
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(a.busy ? 'Generating…' : 'Build it', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  onPressed: a.busy ? null : () => a.submitPrompt(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _artifactsPanel() {
    final a = widget.a;
    final cur = a.now;

    return Container(
      color: const Color(0xFF150A1E),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.widgets, color: gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cur?.prompt ?? 'Live Artifacts Studio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              if (cur != null) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.launch, size: 13),
                  label: const Text('Open App', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => PcControl.openPath(cur.file),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => PcControl.openFolder(),
                  child: const Text('Folder', style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0716),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: line),
              ),
              child: cur == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.code_off, size: 36, color: dim),
                          SizedBox(height: 8),
                          Text('No active application yet.', style: TextStyle(color: ink, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Speak or type your prompt to generate working HTML5 applications and tools in real time.',
                              textAlign: TextAlign.center, style: TextStyle(color: dim, fontSize: 12)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: SelectableText(
                        cur.html,
                        style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: ink, height: 1.4),
                      ),
                    ),
            ),
          ),
          if (cur != null) ...[
            const SizedBox(height: 6),
            Text('Saved: ${cur.file}', style: const TextStyle(color: dim, fontSize: 10)),
          ],
          if (a.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('App History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: gold)),
            const SizedBox(height: 4),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: a.items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (ctx, i) => ChoiceChip(
                  label: Text('${i + 1}. ${a.items[i].prompt}', style: const TextStyle(fontSize: 11)),
                  selected: i == a.current,
                  selectedColor: gold.withOpacity(0.3),
                  onSelected: (_) {
                    a.current = i;
                    a.refresh();
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pcPanel() {
    final a = widget.a;
    final keys = a.settings.apiKeys;
    final isOllamaActive = a.settings.useOllama;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------- Local Ollama Section ----------
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isOllamaActive ? const Color(0xFF1B2A1E) : const Color(0xFF160B1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isOllamaActive ? green : line, width: isOllamaActive ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🦙', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Local Ollama AI (Offline / Free)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Runs 100% locally on your PC without API keys or internet', style: TextStyle(color: dim, fontSize: 10)),
                      ],
                    ),
                  ),
                  Switch(
                    value: a.settings.useOllama,
                    activeColor: green,
                    onChanged: (val) {
                      if (val && !a.ollamaOnline) {
                        a.checkOllamaStatus(manual: true);
                      }
                      a.toggleOllama(val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (a.ollamaChecking) ...[
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: gold)),
                    const SizedBox(width: 6),
                    const Text('Checking Ollama…', style: TextStyle(color: gold, fontSize: 11)),
                  ] else if (a.ollamaOnline) ...[
                    const Icon(Icons.check_circle, color: green, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Connected (${a.ollamaModels.length} models detected)',
                      style: const TextStyle(color: green, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ] else ...[
                    const Icon(Icons.cancel_outlined, color: dim, size: 14),
                    const SizedBox(width: 4),
                    const Text('Ollama offline (localhost:11434)', style: TextStyle(color: dim, fontSize: 11)),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: 'Rescan Ollama models',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => a.checkOllamaStatus(manual: true),
                  ),
                ],
              ),
              if (a.ollamaOnline && a.ollamaModels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Select Model: ', style: TextStyle(fontSize: 12, color: dim)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: a.ollamaModels.contains(a.settings.ollamaModel) ? a.settings.ollamaModel : a.ollamaModels.first,
                        isDense: true,
                        underline: Container(height: 1, color: green),
                        items: a.ollamaModels.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (val) {
                          if (val != null) a.setOllamaModel(val);
                        },
                      ),
                    ),
                  ],
                ),
              ],
              if (isOllamaActive) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: green.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text('⚡ Ollama is ACTIVE. External API keys are turned off.', style: TextStyle(color: Color(0xFF81C784), fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),

        // ---------- Cloud API Keys Section ----------
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text(
                'Cloud AI Providers (${isOllamaActive ? "Disabled while Ollama is ON" : "Active"})',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isOllamaActive ? dim : gold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Paste any key (OpenAI sk-proj-..., Claude sk-ant-..., Gemini AIzaSy..., Groq gsk_...). Auto-tested and verified.',
          style: TextStyle(color: dim, fontSize: 11),
        ),
        const SizedBox(height: 10),

        if (keys.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF160B1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: line),
            ),
            child: const Row(
              children: [
                Icon(Icons.key_off, size: 18, color: rose),
                SizedBox(width: 8),
                Expanded(child: Text('No API keys added yet. Add one below to enable cloud building.', style: TextStyle(color: dim, fontSize: 12))),
              ],
            ),
          )
        else
          for (final k in keys) _apiKeyItem(k),

        const SizedBox(height: 8),

        if (keys.length < 10) ...[
          TextField(
            controller: a.keyCtl,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Paste API key here (sk-proj-..., sk-ant-..., etc.)',
              labelText: 'Add New API Key (${keys.length}/10)',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle, color: gold),
                tooltip: 'Add and verify API Key',
                onPressed: () {
                  if (a.keyCtl.text.trim().isNotEmpty) {
                    a.addApiKey(a.keyCtl.text);
                    a.keyCtl.clear();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Add & Test Key'),
              onPressed: () {
                if (a.keyCtl.text.trim().isNotEmpty) {
                  a.addApiKey(a.keyCtl.text);
                  a.keyCtl.clear();
                }
              },
            ),
          ),
        ],

        const Divider(height: 24, color: line),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('PC Control & Phone Alerts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: gold)),
        ),
        const SizedBox(height: 4),
        Text('Phone alerts: install the free ntfy app and subscribe to topic "${a.settings.topic}". Builds are saved in $buildsDir.', style: const TextStyle(color: dim, fontSize: 11)),
        SwitchListTile(dense: true, value: a.settings.openBuilt, title: const Text('Open finished apps on this PC', style: TextStyle(fontSize: 13)), onChanged: (v) => a.updateSettings(openBuilt: v)),
        SwitchListTile(dense: true, value: a.settings.notify, title: const Text('Message my phone when work is done', style: TextStyle(fontSize: 13)), onChanged: (v) => a.updateSettings(notify: v)),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.send_to_mobile, size: 16),
            onPressed: a.testPhone,
            label: const Text('Send test to phone'),
          ),
        ),
      ],
    );
  }

  Widget _apiKeyItem(ApiKeyEntry k) {
    final a = widget.a;
    final isActive = a.settings.activeKeyId == k.id;
    final isTesting = k.status == 'testing';
    final isValid = k.status == 'valid';
    final isInvalid = k.status == 'invalid';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? gold.withOpacity(0.08) : const Color(0xFF160B1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isActive ? gold : line, width: isActive ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Radio<String>(
            value: k.id,
            groupValue: a.settings.activeKeyId,
            activeColor: gold,
            visualDensity: VisualDensity.compact,
            onChanged: (val) {
              if (val != null) a.setActiveApiKey(val);
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        k.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isActive ? gold : ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(6)),
                        child: const Text('ACTIVE', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (isTesting) ...[
                      const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: gold)),
                      const SizedBox(width: 6),
                      const Text('Testing connection…', style: TextStyle(color: gold, fontSize: 11)),
                    ] else if (isValid) ...[
                      const Icon(Icons.check_circle, color: green, size: 13),
                      const SizedBox(width: 4),
                      const Text('Verified & Working', style: TextStyle(color: green, fontSize: 11, fontWeight: FontWeight.w600)),
                    ] else if (isInvalid) ...[
                      const Icon(Icons.error, color: rose, size: 13),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          k.lastError ?? 'Verification failed',
                          style: const TextStyle(color: rose, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      const Text('Untested', style: TextStyle(color: dim, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Re-test this key',
            visualDensity: VisualDensity.compact,
            onPressed: () => a.testApiKey(k),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: rose),
            tooltip: 'Delete key',
            visualDensity: VisualDensity.compact,
            onPressed: () => a.deleteApiKey(k.id),
          ),
        ],
      ),
    );
  }
}

// ---------- Aurora UI: glowing screen edge + flowing ribbon in the corner ----------
class AuroraLayer extends StatefulWidget {
  final Assistant a;
  const AuroraLayer(this.a, {super.key});
  @override
  State<AuroraLayer> createState() => _AuroraState();
}

const _palettes = {
  Mode.idle: [Color(0xFF3B82FF), Color(0xFFA24BFF), Color(0xFF2EE6FF)],
  Mode.listening: [Color(0xFF3B82FF), Color(0xFFA24BFF), Color(0xFF2EE6FF)],
  Mode.thinking: [Color(0xFFFF4FA3), Color(0xFFFF9A3C), Color(0xFFA24BFF)],
  Mode.building: [Color(0xFFFFB52E), Color(0xFFFF5D8F), Color(0xFFA24BFF)],
  Mode.speaking: [Color(0xFF2EE6FF), Color(0xFF2EFFC0), Color(0xFF3B82FF)],
};

class _AuroraState extends State<AuroraLayer> with SingleTickerProviderStateMixin {
  late final Ticker _tk;
  final repaint = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double t = 0, vis = 0, amp = 0;
  List<Color> cols = List.of(_palettes[Mode.listening]!);

  @override
  void initState() {
    super.initState();
    widget.a.addListener(_rebuild);
    _tk = createTicker((d) {
      final dt = ((d - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
      _last = d;
      _step(dt);
    })..start();
  }

  void _rebuild() => setState(() {});

  void _step(double dt) {
    final m = widget.a.mode;
    t += dt;
    final target = _palettes[m]!;
    for (var i = 0; i < 3; i++) {
      cols[i] = Color.lerp(cols[i], target[i], min(1.0, dt * 3))!;
    }
    vis += ((m == Mode.idle ? 0.0 : 1.0) - vis) * min(1.0, dt * 4);
    final lv = widget.a.levelN.value;
    final ta = switch (m) {
      Mode.idle => 0.0,
      Mode.listening => 12 + lv * 55,
      Mode.thinking => 30.0,
      Mode.building => 42 + 8 * sin(t * 5),
      Mode.speaking => 24 + 14 * sin(t * 6).abs(),
    };
    amp += (ta - amp) * min(1.0, dt * 6);
    repaint.value++;
  }

  @override
  void dispose() {
    widget.a.removeListener(_rebuild);
    _tk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.a.mode;
    const names = {Mode.listening: 'Listening', Mode.thinking: 'Thinking', Mode.building: 'Building', Mode.speaking: 'Speaking'};
    return Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _AuroraPainter(this))),
      if (m != Mode.idle)
        Positioned(
          right: 30,
          bottom: 178,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(color: bg.withOpacity(.85), borderRadius: BorderRadius.circular(99), border: Border.all(color: line)),
            child: Text('${names[m]} · ${langNames[widget.a.locale]}${widget.a.langChoice == 'auto' ? ' (auto)' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ),
    ]);
  }
}

class _AuroraPainter extends CustomPainter {
  final _AuroraState s;
  _AuroraPainter(this.s) : super(repaint: s.repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (s.vis < 0.01) return;
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(s.vis.clamp(0.0, 1.0)));
    final rr = RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(14));
    final shader = SweepGradient(colors: [s.cols[0], s.cols[1], s.cols[2], s.cols[0]], transform: GradientRotation(s.t * (s.amp > 35 ? 1.6 : .7)))
        .createShader(rect);
    canvas.drawRRect(rr, Paint()..shader = shader..style = PaintingStyle.stroke..strokeWidth = 24..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    canvas.drawRRect(rr, Paint()..shader = shader..style = PaintingStyle.stroke..strokeWidth = 3);

    // corner ribbon
    const w = 420.0, h = 190.0;
    canvas.save();
    canvas.translate(size.width - w - 18, size.height - h - 14);
    for (var k = 0; k < 3; k++) {
      final path = Path();
      for (double x = 0; x <= w; x += 4) {
        final env = pow(sin(pi * x / w), 1.4).toDouble();
        final y = h / 2 + sin(x * .016 + s.t * 2.2 * (k + 1.5) + k * 2.1) * s.amp * env * (0.7 + 0.3 * sin(x * .006 - s.t * 1.2 * (k + 1)));
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      final g = LinearGradient(colors: [s.cols[k].withOpacity(0), s.cols[k], s.cols[(k + 1) % 3], s.cols[(k + 2) % 3].withOpacity(0)])
          .createShader(const Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(path, Paint()..shader = g..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = 14.0 - k * 4..blendMode = BlendMode.plus..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => false;
}
