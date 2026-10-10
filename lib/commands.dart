// Turns what the user said (English, Hindi, Gujarati, Hinglish) into commands.
enum CmdType { build, remix, saved, back, next, openIndex, openFile, clear, read, stop, help, lang, folder, url, app, greet, dictation }

class Cmd {
  final CmdType type;
  final String arg;
  const Cmd(this.type, [this.arg = '']);
}

class Parsed {
  final List<Cmd> cmds;
  final bool ignored;
  final bool woke;
  const Parsed(this.cmds, {this.ignored = false, this.woke = false});
}

final _wake = RegExp(r'^(?:hey |hi |hello |ok |ओके |हे |नमस्ते )?(?:jarvis|जार्विस|जारविस|જાર્વિસ)[,.\s!]*', caseSensitive: false);
final _split = RegExp(
    r'\s+(?:and then|then|and|aur|फिर|और)\s+(?=(?:build|create|make|open|launch|change|remix|download|banao|kholo|बनाओ|खोलो|બનાવો|ખોલો))',
    caseSensitive: false);

Parsed parseUtterance(String raw, {required bool wakeOnly}) {
  var t = raw.trim();
  final w = _wake.firstMatch(t);
  final hasJarvis = t.toLowerCase().contains('jarvis') || t.contains('जार्विस') || t.contains('જાર્વિસ');
  if (wakeOnly && w == null && !hasJarvis) return const Parsed([], ignored: true);
  
  if (w != null) {
    t = t.substring(w.end).trim();
  } else if (hasJarvis) {
    t = t.replaceAll(RegExp(r'(?:hey |hi |hello )?jarvis[,.\s]*', caseSensitive: false), '').trim();
  }

  if (t.isEmpty && (w != null || hasJarvis)) {
    return const Parsed([Cmd(CmdType.greet, 'wake')], woke: true);
  }

  final cmds = <Cmd>[];
  for (final part in t.split(_split)) {
    final c = _one(part.trim());
    if (c != null) cmds.add(c);
  }
  return Parsed(cmds, woke: w != null || hasJarvis);
}

String _tail(String s, RegExpMatch m, int g) => s.substring(s.length - m.group(g)!.length);

Cmd? _one(String p) {
  if (p.isEmpty) return null;
  final q = p.replaceAll(RegExp(r'[.!?]+$'), '').trim();
  final l = q.toLowerCase();
  RegExpMatch? m;

  m = RegExp(r'^(?:build|create|make|generate|code|banao|bana|बनाओ|बना|બનાવો|બનાવ)\s+(.+)$').firstMatch(l);
  if (m != null) return Cmd(CmdType.build, _tail(q, m, 1));
  m = RegExp(r'^(?:change|remix|modify|update|badlo|बदलो|बदल|બદલો|બદલ)\s+(.+)$').firstMatch(l);
  if (m != null) return Cmd(CmdType.remix, _tail(q, m, 1));
  if (RegExp(r'^(?:download|save|डाउनलोड|ડાઉનલોડ)').hasMatch(l)) return const Cmd(CmdType.saved);
  if (RegExp(r'^(?:back|previous|undo|pichla|पिछला|પાછળ)').hasMatch(l)) return const Cmd(CmdType.back);
  if (RegExp(r'^(?:next|agla|अगला|આગળ)').hasMatch(l)) return const Cmd(CmdType.next);
  m = RegExp(r'^(?:open|show|kholo|खोलो)\s+(?:app\s+)?(\d+)$').firstMatch(l);
  if (m != null) return Cmd(CmdType.openIndex, m.group(1)!);
  if (RegExp(r'^(?:full ?screen|run it|open it|launch it|फुल ?स्क्रीन|ફુલ)$').hasMatch(l)) return const Cmd(CmdType.openFile);
  if (RegExp(r'^(?:clear|reset|saaf|साफ़?|સાફ)').hasMatch(l)) return const Cmd(CmdType.clear);
  if (RegExp(r'^(?:read|status|बताओ)').hasMatch(l)) return const Cmd(CmdType.read);
  if (RegExp(r'^(?:help|madad|मदद|મદદ)').hasMatch(l)) return const Cmd(CmdType.help);
  m = RegExp(r'^(?:speak|language|switch to|bolo|બોલો|बोलो)\s*(english|hindi|gujarati|हिंदी|ગુજરાતી|अंग्रेज़ी|अंग्रेजी)').firstMatch(l);
  if (m != null) {
    final k = m.group(1)!;
    final code = RegExp(r'hin|हिं').hasMatch(k) ? 'hi_IN' : RegExp(r'guj|ગુ').hasMatch(k) ? 'gu_IN' : 'en_IN';
    return Cmd(CmdType.lang, code);
  }
  if (RegExp(r'^(?:stop|quit|exit|band|बंद|બંધ)').hasMatch(l)) return const Cmd(CmdType.stop);

  if (RegExp(r'^(?:open|show)\s+(?:my\s+)?(?:builds?|apps?)\s+folder$').hasMatch(l)) return const Cmd(CmdType.folder);
  m = RegExp(r'^(?:open|go to|visit)\s+(?:the\s+)?(?:website\s+|site\s+)?((?:https?://)?[a-z0-9-]+(?:\.[a-z0-9-]+)+\S*)$').firstMatch(l);
  if (m != null) return Cmd(CmdType.url, m.group(1)!);
  m = RegExp(r'^(?:open|launch|kholo|खोलो|ખોલો)\s+(?:the\s+)?(?:app\s+|application\s+)?([a-z0-9 .+\-]{1,40})$').firstMatch(l) ??
      RegExp(r'^([a-z0-9 .+\-]{1,40})\s+(?:kholo|खोलो|ખોલો)$').firstMatch(l);
  if (m != null) return Cmd(CmdType.app, m.group(1)!.trim());

  return Cmd(CmdType.dictation, q);
}
