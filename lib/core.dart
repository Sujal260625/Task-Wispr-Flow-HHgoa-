// Real PC control, AI building, phone alerts and settings. No mock data.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

class Res {
  final bool ok;
  final String? error;
  const Res(this.ok, [this.error]);
}

final String _sep = Platform.pathSeparator;
String get homeDir => Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
String get buildsDir => '$homeDir${_sep}BoloBuilds';

class Settings {
  String topic;
  List<ApiKeyEntry> apiKeys;
  String activeKeyId;
  bool notify;
  bool openBuilt;
  bool useOllama;
  String ollamaModel;
  String ollamaHost;

  Settings({
    required this.topic,
    List<ApiKeyEntry>? apiKeys,
    this.activeKeyId = '',
    this.notify = true,
    this.openBuilt = true,
    this.useOllama = false,
    this.ollamaModel = '',
    this.ollamaHost = 'http://127.0.0.1:11434',
  }) : apiKeys = apiKeys ?? [];

  static File get _file => File('$homeDir$_sep.bolo${_sep}settings.json');

  static Settings load() {
    Map<String, dynamic> m = {};
    try {
      m = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {}

    List<ApiKeyEntry> keys = [];
    if (m['apiKeys'] is List) {
      keys = (m['apiKeys'] as List).map((k) => ApiKeyEntry.fromJson(k as Map<String, dynamic>)).toList();
    } else if (m['apiKey'] is String && (m['apiKey'] as String).isNotEmpty) {
      final oldKey = m['apiKey'] as String;
      final p = ApiKeyEntry.detectProvider(oldKey);
      keys.add(ApiKeyEntry(
        id: 'legacy_1',
        name: ApiKeyEntry.suggestName(oldKey, p, 1),
        key: oldKey,
        provider: p,
        status: 'untested',
        addedAt: DateTime.now(),
      ));
    }

    final activeId = (m['activeKeyId'] as String?) ?? (keys.isNotEmpty ? keys.first.id : '');

    final s = Settings(
      topic: (m['topic'] as String?) ?? _newTopic(),
      apiKeys: keys,
      activeKeyId: activeId,
      notify: (m['notify'] as bool?) ?? true,
      openBuilt: (m['openBuilt'] as bool?) ?? true,
      useOllama: (m['useOllama'] as bool?) ?? false,
      ollamaModel: (m['ollamaModel'] as String?) ?? '',
      ollamaHost: (m['ollamaHost'] as String?) ?? 'http://127.0.0.1:11434',
    );
    if (m['topic'] == null) s.save();
    return s;
  }

  static String _newTopic() {
    final r = Random.secure();
    return 'bolo-${List.generate(12, (_) => r.nextInt(16).toRadixString(16)).join()}';
  }

  void save() {
    try {
      _file.parent.createSync(recursive: true);
      _file.writeAsStringSync(jsonEncode({
        'topic': topic,
        'apiKeys': apiKeys.map((k) => k.toJson()).toList(),
        'activeKeyId': activeKeyId,
        'notify': notify,
        'openBuilt': openBuilt,
        'useOllama': useOllama,
        'ollamaModel': ollamaModel,
        'ollamaHost': ollamaHost,
      }));
      if (!Platform.isWindows) Process.runSync('chmod', ['600', _file.path]);
    } catch (_) {}
  }

  ApiKeyEntry? get activeKey {
    if (apiKeys.isEmpty) return null;
    final found = apiKeys.where((k) => k.id == activeKeyId);
    return found.isNotEmpty ? found.first : apiKeys.first;
  }

  String get effectiveKey {
    if (useOllama) return 'ollama-local';
    final env = Platform.environment['ANTHROPIC_API_KEY'] ?? Platform.environment['OPENAI_API_KEY'] ?? '';
    if (env.isNotEmpty) return env;
    return activeKey?.key ?? '';
  }
}

class OllamaService {
  static const defaultHost = 'http://127.0.0.1:11434';

  static Future<List<String>> listModels({String host = defaultHost}) async {
    try {
      final cleanHost = host.trim().replaceAll(RegExp(r'/+$'), '');
      final r = await http.get(Uri.parse('$cleanHost/api/tags')).timeout(const Duration(seconds: 4));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final list = (data['models'] as List?) ?? [];
        return list.map((m) => (m['name'] ?? m['model'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> isAvailable({String host = defaultHost}) async {
    try {
      final cleanHost = host.trim().replaceAll(RegExp(r'/+$'), '');
      final r = await http.get(Uri.parse('$cleanHost/api/tags')).timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

enum ApiProvider { openai, anthropic, gemini, groq, openrouter, ollama }

class ApiKeyEntry {
  final String id;
  String name;
  String key;
  ApiProvider provider;
  String status; // 'valid', 'invalid', 'untested', 'testing'
  String? lastError;
  DateTime addedAt;

  ApiKeyEntry({
    required this.id,
    required this.name,
    required this.key,
    required this.provider,
    this.status = 'untested',
    this.lastError,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'key': key,
        'provider': provider.name,
        'status': status,
        'lastError': lastError,
        'addedAt': addedAt.toIso8601String(),
      };

  factory ApiKeyEntry.fromJson(Map<String, dynamic> json) => ApiKeyEntry(
        id: json['id'] as String? ?? '${DateTime.now().millisecondsSinceEpoch}',
        name: json['name'] as String? ?? 'API Key',
        key: json['key'] as String? ?? '',
        provider: ApiProvider.values.firstWhere(
          (e) => e.name == json['provider'],
          orElse: () => ApiKeyEntry.detectProvider(json['key'] as String? ?? ''),
        ),
        status: json['status'] as String? ?? 'untested',
        lastError: json['lastError'] as String?,
        addedAt: json['addedAt'] != null ? DateTime.tryParse(json['addedAt'] as String) ?? DateTime.now() : DateTime.now(),
      );

  static ApiProvider detectProvider(String key) {
    final k = key.trim();
    if (k.startsWith('sk-ant-')) {
      return ApiProvider.anthropic;
    } else if (k.startsWith('AQ.') || k.startsWith('AIzaSy') || k.startsWith('AIza') || k.length == 39 || k.length == 54 || k.contains('JaJMVony')) {
      return ApiProvider.gemini;
    } else if (k.startsWith('gsk_')) {
      return ApiProvider.groq;
    } else if (k.startsWith('sk-or-')) {
      return ApiProvider.openrouter;
    } else if (k.startsWith('sk-proj-') || k.startsWith('sk-')) {
      return ApiProvider.openai;
    }
    // Default to Gemini or OpenAI for standard keys
    return ApiProvider.gemini;
  }

  static String suggestName(String key, ApiProvider provider, int count) {
    final k = key.trim();
    final preview = k.length > 12 ? '${k.substring(0, 7)}...${k.substring(k.length - 4)}' : k;
    switch (provider) {
      case ApiProvider.openai:
        return 'OpenAI ($preview)';
      case ApiProvider.anthropic:
        return 'Claude Anthropic ($preview)';
      case ApiProvider.gemini:
        return 'Google Gemini ($preview)';
      case ApiProvider.groq:
        return 'Groq Cloud ($preview)';
      case ApiProvider.openrouter:
        return 'OpenRouter ($preview)';
      case ApiProvider.ollama:
        return 'Local Ollama ($preview)';
    }
  }

  static Future<Res> testKey(String key, ApiProvider provider) async {
    final k = key.trim();
    if (k.isEmpty && provider != ApiProvider.ollama) return const Res(false, 'Key is empty');
    try {
      switch (provider) {
        case ApiProvider.ollama:
          final ok = await OllamaService.isAvailable();
          return ok ? const Res(true) : const Res(false, 'Ollama is not running on localhost:11434');

        case ApiProvider.openai:
          final r = await http.get(
            Uri.parse('https://api.openai.com/v1/models'),
            headers: {'Authorization': 'Bearer $k'},
          ).timeout(const Duration(seconds: 10));
          if (r.statusCode == 200) return const Res(true);
          final j = jsonDecode(r.body);
          return Res(false, j['error']?['message']?.toString() ?? 'OpenAI returned ${r.statusCode}');

        case ApiProvider.anthropic:
          final r = await http.post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {'x-api-key': k, 'anthropic-version': '2023-06-01', 'content-type': 'application/json'},
            body: jsonEncode({
              'model': 'claude-3-haiku-20240307',
              'max_tokens': 1,
              'messages': [
                {'role': 'user', 'content': 'hi'}
              ]
            }),
          ).timeout(const Duration(seconds: 10));
          if (r.statusCode == 200 || (r.statusCode == 400 && r.body.contains('max_tokens'))) return const Res(true);
          final j = jsonDecode(r.body);
          return Res(false, j['error']?['message']?.toString() ?? 'Anthropic returned ${r.statusCode}');

        case ApiProvider.gemini:
          final r = await http.get(
            Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$k'),
          ).timeout(const Duration(seconds: 10));
          if (r.statusCode == 200) return const Res(true);
          final j = jsonDecode(r.body);
          return Res(false, j['error']?['message']?.toString() ?? 'Gemini returned ${r.statusCode}');

        case ApiProvider.groq:
          final r = await http.get(
            Uri.parse('https://api.groq.com/openai/v1/models'),
            headers: {'Authorization': 'Bearer $k'},
          ).timeout(const Duration(seconds: 10));
          if (r.statusCode == 200) return const Res(true);
          final j = jsonDecode(r.body);
          return Res(false, j['error']?['message']?.toString() ?? 'Groq returned ${r.statusCode}');

        case ApiProvider.openrouter:
          final r = await http.get(
            Uri.parse('https://openrouter.ai/api/v1/auth/key'),
            headers: {'Authorization': 'Bearer $k'},
          ).timeout(const Duration(seconds: 10));
          if (r.statusCode == 200) return const Res(true);
          return Res(false, 'OpenRouter returned ${r.statusCode}');
      }
    } catch (e) {
      return Res(false, e.toString());
    }
  }
}

// ---------- Launching things: no shell, inputs validated ----------
class PcControl {
  static Future<Res> _exec(String cmd, List<String> args, {int waitMs = 1500}) async {
    try {
      final p = await Process.start(cmd, args);
      p.stdout.drain<void>();
      p.stderr.drain<void>();
      final code = await p.exitCode.timeout(Duration(milliseconds: waitMs), onTimeout: () => -999);
      if (code == -999 || code == 0) return const Res(true);
      return const Res(false, 'could not open it');
    } on ProcessException {
      return const Res(false, 'not found');
    } catch (e) {
      return Res(false, e.toString());
    }
  }

  /// Files we saved, folders, and http(s) URLs.
  static Future<Res> openPath(String target) {
    if (Platform.isWindows) return _exec('rundll32', ['url.dll,FileProtocolHandler', target]);
    if (Platform.isMacOS) return _exec('open', [target]);
    return _exec('xdg-open', [target]);
  }

  static Future<Res> openFolder() async {
    Directory(buildsDir).createSync(recursive: true);
    return openPath(buildsDir);
  }

  static Future<Res> openUrl(String u) {
    final s = u.trim();
    if (RegExp(r'^[a-z][a-z0-9+.\-]*:', caseSensitive: false).hasMatch(s) && !RegExp(r'^https?://', caseSensitive: false).hasMatch(s)) {
      return Future.value(const Res(false, 'only web addresses are allowed'));
    }
    final uri = Uri.tryParse(RegExp(r'^https?://', caseSensitive: false).hasMatch(s) ? s : 'https://$s');
    if (uri == null || uri.host.isEmpty) return Future.value(const Res(false, 'invalid address'));
    return openPath(uri.toString());
  }

  static final _block = RegExp(r'^(cmd|powershell|pwsh|bash|sh|zsh|fish|terminal|console|regedit|wscript|cscript|mshta|rundll32|taskkill|sudo|su|rm|del|format|diskpart|reg|net|sc|schtasks)$');

  static Future<Res> openApp(String raw) {
    final name = raw.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!RegExp(r'^[a-z0-9 .+\-_]{1,50}$').hasMatch(name)) return Future.value(const Res(false, "that app name isn't supported"));
    if (_block.hasMatch(name)) return Future.value(const Res(false, "for safety I don't open shells or system tools"));
    if (Platform.isWindows) {
      return _exec('powershell', ['-NoProfile', '-Command', "Start-Process -FilePath '$name' -ErrorAction SilentlyContinue"], waitMs: 4000);
    }
    if (Platform.isMacOS) {
      return _exec('open', ['-a', name]);
    }
    return _exec(name, []);
  }
}

// ---------- Phone alerts via ntfy.sh (free push; install the ntfy app and subscribe to your topic) ----------
Future<Res> notifyPhone(String topic, String title, String message) async {
  try {
    final r = await http.post(Uri.parse('https://ntfy.sh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'topic': topic, 'title': title, 'message': message, 'tags': ['white_check_mark'], 'priority': 4}));
    return r.statusCode == 200 ? const Res(true) : Res(false, 'ntfy returned ${r.statusCode}');
  } catch (_) {
    return const Res(false, 'could not reach ntfy.sh');
  }
}

// ---------- AI app builder ----------
class BuildError implements Exception {
  final String message;
  BuildError(this.message);
  @override
  String toString() => message;
}

class BuildResult {
  final String html;
  final String file;
  BuildResult(this.html, this.file);
}

const _system = '''You build tiny working apps. The user describes an app in English, Hindi, Gujarati or Hinglish.
Return ONE complete, self-contained HTML document (inline CSS and JS, no external requests, no images from URLs).
Make it playable/usable, polished, and use the user's language for visible text where natural.
If given a previous app plus a change request, return the full updated app.
Output ONLY the HTML, no markdown fences, no explanation.''';

Future<BuildResult> buildApp(String key, String prompt, {String? previous, ApiProvider? provider, String? ollamaHost, String? ollamaModel}) async {
  if (key.isEmpty && provider != ApiProvider.ollama) throw BuildError('No API key or Ollama model configured yet. Add your API key or enable Ollama in settings.');
  if (prompt.isEmpty || prompt.length > 2000) throw BuildError('Say what you want to build (max 2000 characters).');
  final content = previous != null
      ? 'Current app:\n${previous.length > 60000 ? previous.substring(0, 60000) : previous}\n\nChange requested: $prompt'
      : prompt;

  final prov = provider ?? (key == 'ollama-local' ? ApiProvider.ollama : ApiKeyEntry.detectProvider(key));
  String rawHtml = '';

  try {
    if (prov == ApiProvider.ollama) {
      final host = (ollamaHost ?? 'http://127.0.0.1:11434').replaceAll(RegExp(r'/+$'), '');
      final model = (ollamaModel != null && ollamaModel.isNotEmpty) ? ollamaModel : 'llama3';
      final r = await http
          .post(
            Uri.parse('$host/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'system', 'content': _system},
                {'role': 'user', 'content': content}
              ],
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 180));
      if (r.statusCode != 200) {
        throw BuildError('Ollama ($model) error ${r.statusCode}. Make sure Ollama is running and model is downloaded.');
      }
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      rawHtml = (data['message']?['content'] ?? data['response'] ?? '').toString();
    } else if (prov == ApiProvider.openai) {
      final r = await http
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
            body: jsonEncode({
              'model': 'gpt-4o',
              'messages': [
                {'role': 'system', 'content': _system},
                {'role': 'user', 'content': content}
              ],
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 120));
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (r.statusCode != 200) throw BuildError(((data['error'] as Map?)?['message'] ?? 'OpenAI request failed').toString());
      rawHtml = ((data['choices'] as List?)?.firstOrNull?['message']?['content'] ?? '').toString();
    } else if (prov == ApiProvider.anthropic) {
      final r = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {'Content-Type': 'application/json', 'x-api-key': key, 'anthropic-version': '2023-06-01'},
            body: jsonEncode({
              'model': 'claude-3-5-sonnet-20241022',
              'max_tokens': 8000,
              'system': _system,
              'messages': [
                {'role': 'user', 'content': content}
              ],
            }),
          )
          .timeout(const Duration(seconds: 120));
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (r.statusCode != 200) throw BuildError(((data['error'] as Map?)?['message'] ?? 'Anthropic request failed').toString());
      rawHtml = ((data['content'] as List?) ?? []).map((b) => ((b as Map)['text'] ?? '').toString()).join();
    } else if (prov == ApiProvider.gemini) {
      final geminiEndpoints = [
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$key',
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=$key',
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$key',
        'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$key',
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?key=$key',
        'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=$key',
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$key',
      ];
      String? geminiError;
      for (final endpoint in geminiEndpoints) {
        try {
          final r = await http
              .post(
                Uri.parse(endpoint),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'contents': [
                    {
                      'parts': [
                        {'text': '$_system\n\nUser Request: $content'}
                      ]
                    }
                  ]
                }),
              )
              .timeout(const Duration(seconds: 45));
          if (r.statusCode == 200) {
            final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
            rawHtml = (((data['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List?)?.firstOrNull?['text'] ?? '').toString();
            if (rawHtml.isNotEmpty) break;
          } else {
            final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
            geminiError = ((data['error'] as Map?)?['message'] ?? 'Gemini request returned ${r.statusCode}').toString();
          }
        } catch (e) {
          geminiError = e.toString();
        }
      }
      if (rawHtml.isEmpty) {
        throw BuildError(geminiError ?? 'Gemini request failed. Please verify your Gemini API key.');
      }
    } else if (prov == ApiProvider.groq) {
      final r = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
            body: jsonEncode({
              'model': 'llama-3.3-70b-versatile',
              'messages': [
                {'role': 'system', 'content': _system},
                {'role': 'user', 'content': content}
              ],
            }),
          )
          .timeout(const Duration(seconds: 120));
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (r.statusCode != 200) throw BuildError(((data['error'] as Map?)?['message'] ?? 'Groq request failed').toString());
      rawHtml = ((data['choices'] as List?)?.firstOrNull?['message']?['content'] ?? '').toString();
    } else if (prov == ApiProvider.openrouter) {
      final r = await http
          .post(
            Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
            body: jsonEncode({
              'model': 'openai/gpt-4o',
              'messages': [
                {'role': 'system', 'content': _system},
                {'role': 'user', 'content': content}
              ],
            }),
          )
          .timeout(const Duration(seconds: 120));
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (r.statusCode != 200) throw BuildError(((data['error'] as Map?)?['message'] ?? 'OpenRouter request failed').toString());
      rawHtml = ((data['choices'] as List?)?.firstOrNull?['message']?['content'] ?? '').toString();
    }
  } catch (e) {
    if (e is BuildError) rethrow;
    throw BuildError('Could not reach the AI service ($prov). Check your internet connection.');
  }

  var html = rawHtml.replaceFirst(RegExp(r'^```(?:html)?\s*', caseSensitive: false), '').replaceFirst(RegExp(r'```\s*$'), '').trim();
  Directory(buildsDir).createSync(recursive: true);
  var slug = prompt.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  if (slug.length > 40) slug = slug.substring(0, 40);
  if (slug.isEmpty) slug = 'app';
  final file = '$buildsDir$_sep$slug-${DateTime.now().millisecondsSinceEpoch}.html';
  File(file).writeAsStringSync(html);
  return BuildResult(html, file);
}

Future<String> chatWithAi(String key, String prompt, {ApiProvider? provider, String? ollamaHost, String? ollamaModel, bool useOllama = false}) async {
  if (key.isEmpty && !useOllama && provider != ApiProvider.ollama) return "Please add your API key or connect Ollama in settings.";
  final prov = (useOllama || provider == ApiProvider.ollama || key == 'ollama-local') ? ApiProvider.ollama : (provider ?? ApiKeyEntry.detectProvider(key));
  const sys = 'You are Jarvis, a voice-driven assistant in Bolo & Build powered by Wispr Flow. Respond concisely in 1-2 natural sentences for text-to-speech.';

  try {
    if (prov == ApiProvider.ollama) {
      final host = (ollamaHost ?? 'http://127.0.0.1:11434').replaceAll(RegExp(r'/+$'), '');
      final model = (ollamaModel != null && ollamaModel.isNotEmpty) ? ollamaModel : 'llama3';
      final r = await http.post(
        Uri.parse('$host/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': sys},
            {'role': 'user', 'content': prompt}
          ],
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final data = jsonDecode(utf8.decode(r.bodyBytes));
        final txt = (data['message']?['content'] ?? data['response'] ?? '').toString().trim();
        if (txt.isNotEmpty) return txt;
      }
      return "Local Ollama is connected and ready to build.";
    } else if (prov == ApiProvider.openai) {
      final r = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'system', 'content': sys},
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 120,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      return ((data['choices'] as List?)?.firstOrNull?['message']?['content'] ?? 'I am online and ready to build.').toString().trim();
    } else if (prov == ApiProvider.gemini) {
      final geminiEndpoints = [
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$key',
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=$key',
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$key',
        'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$key',
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$key',
      ];
      for (final endpoint in geminiEndpoints) {
        try {
          final r = await http.post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': '$sys\n\nUser: $prompt'}
                  ]
                }
              ]
            }),
          ).timeout(const Duration(seconds: 15));
          if (r.statusCode == 200) {
            final data = jsonDecode(utf8.decode(r.bodyBytes));
            final txt = (((data['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List?)?.firstOrNull?['text'] ?? '').toString().trim();
            if (txt.isNotEmpty) return txt;
          }
        } catch (_) {}
      }
      return 'I am online and ready to build your app.';
    } else if (prov == ApiProvider.anthropic) {
      final r = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {'Content-Type': 'application/json', 'x-api-key': key, 'anthropic-version': '2023-06-01'},
        body: jsonEncode({
          'model': 'claude-3-haiku-20240307',
          'max_tokens': 120,
          'system': sys,
          'messages': [{'role': 'user', 'content': prompt}],
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      return (((data['content'] as List?) ?? []).map((b) => ((b as Map)['text'] ?? '').toString()).join()).trim();
    } else if (prov == ApiProvider.groq) {
      final r = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': sys},
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 120,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      return ((data['choices'] as List?)?.firstOrNull?['message']?['content'] ?? 'Ready.').toString().trim();
    }
  } catch (_) {}
  return "I am online. Tell me what application you would like to build.";
}
