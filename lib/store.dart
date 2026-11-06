import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);
final accent = ValueNotifier<Color>(const Color(0xFF6C63FF));
final sttLocale = ValueNotifier<String>('en_US');
String userName = '';
String countryCode = '92';
final navKey = GlobalKey<NavigatorState>();
final shotKey = GlobalKey();

BuildContext? _ctx() => navKey.currentState?.overlay?.context;

Future<bool> ask(String text) async {
  final c = _ctx();
  if (c == null) return false;
  return await showDialog<bool>(
        context: c,
        builder: (d) => AlertDialog(content: Text(text), actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Yes')),
        ]),
      ) ??
      false;
}

// One-time explanation shown before Alex asks Android for a permission.
Future<bool> disclose(String id, String why) async {
  final p = await SharedPreferences.getInstance();
  if (p.getBool('disc_$id') ?? false) return true;
  final c = _ctx();
  if (c == null) return false;
  final ok = await showDialog<bool>(
        context: c,
        barrierDismissible: false,
        builder: (d) => AlertDialog(title: const Text('Permission needed'), content: Text(why), actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Continue')),
        ]),
      ) ??
      false;
  if (ok) await p.setBool('disc_$id', true);
  return ok;
}

class Notes {
  static Future<List<String>> load() async =>
      (await SharedPreferences.getInstance()).getStringList('notes') ?? [];
  static Future<void> save(List<String> n) async =>
      (await SharedPreferences.getInstance()).setStringList('notes', n);
}

Future<void> loadPrefs() async {
  final p = await SharedPreferences.getInstance();
  userName = p.getString('name') ?? '';
  themeMode.value = ThemeMode.values[p.getInt('theme') ?? 2];
  accent.value = Color(p.getInt('accent') ?? 0xFF6C63FF);
  sttLocale.value = p.getString('stt') ?? 'en_US';
  countryCode = p.getString('cc') ?? '92';
}

const providers = ['Groq', 'SerpAPI', 'Tavily', 'NewsData', 'OpenWeather'];

// Default keys are injected at build time (GitHub Secrets), never written in code.
const _seed = {
  'Groq': String.fromEnvironment('GROQ_KEYS'),
  'SerpAPI': String.fromEnvironment('SERP_KEYS'),
  'Tavily': String.fromEnvironment('TAVILY_KEYS'),
  'NewsData': String.fromEnvironment('NEWSDATA_KEYS'),
  'OpenWeather': String.fromEnvironment('WEATHER_KEYS'),
};

class KeyItem {
  String key;
  bool on;
  KeyItem(this.key, [this.on = true]);
}

class Keys {
  static const _s = FlutterSecureStorage();
  static final Map<String, List<KeyItem>> data = {};
  static final Set<String> _cool = {};

  static Future<void> load() async {
    final raw = await _s.read(key: 'keys_v1');
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      for (final p in providers) {
        data[p] = ((m[p] ?? []) as List).map((e) => KeyItem(e['k'], e['on'])).toList();
      }
    } else {
      for (final p in providers) {
        data[p] = _seed[p]!
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .map((e) => KeyItem(e))
            .toList();
      }
      await save();
    }
  }

  static Future<void> save() => _s.write(
        key: 'keys_v1',
        value: jsonEncode({
          for (final p in providers)
            p: [for (final k in data[p]!) {'k': k.key, 'on': k.on}]
        }),
      );

  static List<KeyItem> live(String p) =>
      data[p]!.where((k) => k.on && !_cool.contains(k.key)).toList();
  static void cool(String k) => _cool.add(k);
  static void clearCool() => _cool.clear();
  static String mask(String k) =>
      k.length <= 8 ? '••••••' : '${k.substring(0, 4)}…${k.substring(k.length - 3)}';
}

class Msg {
  String role, text;
  Msg(this.role, this.text);
}

class Chat {
  String id, title;
  List<Msg> msgs;
  int ts;
  Chat(this.id, this.title, this.msgs, this.ts);
}

class Chats {
  static List<Chat> all = [];

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('chats_v1');
    if (raw == null) return;
    all = (jsonDecode(raw) as List)
        .map((c) => Chat(c['id'], c['title'],
            (c['m'] as List).map((m) => Msg(m['r'], m['t'])).toList(), c['ts']))
        .toList();
  }

  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'chats_v1',
      jsonEncode([
        for (final c in all)
          {
            'id': c.id,
            'title': c.title,
            'ts': c.ts,
            'm': [for (final m in c.msgs) {'r': m.role, 't': m.text}]
          }
      ]),
    );
  }
}
