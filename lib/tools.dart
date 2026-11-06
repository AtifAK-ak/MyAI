import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'actions.dart';
import 'store.dart';

final _cache = <String, MapEntry<DateTime, String>>{};

String? _cached(String k) {
  final h = _cache[k];
  return (h != null && DateTime.now().difference(h.key).inMinutes < 10) ? h.value : null;
}

String _keep(String k, String v) {
  _cache[k] = MapEntry(DateTime.now(), v);
  return v;
}

String _clip(dynamic s, int n) {
  final t = (s ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length > n ? '${t.substring(0, n)}…' : t;
}

// Tries each live key of a provider; bad key -> switched off, limit -> skipped.
Future<http.Response?> _call(String provider, Future<http.Response> Function(String key) f,
    {bool allow404 = false}) async {
  var keys = Keys.live(provider);
  if (keys.isEmpty) {
    Keys.clearCool();
    keys = Keys.live(provider);
  }
  for (final k in keys) {
    try {
      final r = await f(k.key).timeout(const Duration(seconds: 25));
      if (r.statusCode == 200 || (allow404 && r.statusCode == 404)) return r;
      if (r.statusCode == 401 || r.statusCode == 403) {
        k.on = false;
        await Keys.save();
      } else {
        Keys.cool(k.key);
      }
    } catch (_) {}
  }
  return null;
}

dynamic _json(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));

Future<String> webSearch(String q) async {
  final ck = 's:$q';
  final c = _cached(ck);
  if (c != null) return c;
  final b = StringBuffer();
  final t = await _call(
      'Tavily',
      (k) => http.post(Uri.parse('https://api.tavily.com/search'),
          headers: {'Authorization': 'Bearer $k', 'Content-Type': 'application/json'},
          body: jsonEncode({'query': q, 'max_results': 4, 'include_answer': true})));
  if (t != null) {
    final j = _json(t);
    if (j['answer'] != null) b.writeln('Summary: ${_clip(j['answer'], 400)}');
    for (final r in ((j['results'] ?? []) as List).take(4)) {
      final host = Uri.tryParse('${r['url']}')?.host ?? '';
      b.writeln('- ${_clip(r['title'], 80)} ($host): ${_clip(r['content'], 280)}');
    }
  } else {
    final s = await _call(
        'SerpAPI',
        (k) => http.get(Uri.https('serpapi.com', '/search.json',
            {'engine': 'google', 'q': q, 'api_key': k, 'num': '5'})));
    if (s != null) {
      final j = _json(s);
      final ab = j['answer_box'];
      if (ab is Map) {
        final a = ab['answer'] ?? ab['snippet'];
        if (a != null) b.writeln('Answer: ${_clip(a, 300)}');
      }
      for (final r in ((j['organic_results'] ?? []) as List).take(4)) {
        b.writeln('- ${_clip(r['title'], 80)}: ${_clip(r['snippet'], 250)}');
      }
    }
  }
  final out = b.toString().trim();
  return out.isEmpty ? 'No search results available.' : _keep(ck, out);
}

Future<String> getNews(String? q, String? country) async {
  final ck = 'n:${q ?? ''}:${country ?? ''}';
  final c = _cached(ck);
  if (c != null) return c;
  final r = await _call(
      'NewsData',
      (k) => http.get(Uri.https('newsdata.io', '/api/1/latest', {
            'apikey': k,
            if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
            if (country != null && country.trim().isNotEmpty) 'country': country.trim().toLowerCase(),
          })));
  if (r == null) return 'News service unavailable.';
  final list = ((_json(r)['results'] ?? []) as List).take(5);
  final b = StringBuffer();
  for (final n in list) {
    b.writeln('- ${_clip(n['title'], 110)} (${_clip(n['source_name'] ?? n['source_id'], 30)}, ${_clip(n['pubDate'], 16)}): ${_clip(n['description'], 140)}');
  }
  final out = b.toString().trim();
  return out.isEmpty ? 'No news found.' : _keep(ck, out);
}

Future<String> getWeather(String? city) async {
  Map<String, String> loc;
  if (city != null && city.trim().isNotEmpty) {
    loc = {'q': city.trim()};
  } else {
    try {
      if (!await disclose('loc', 'Alex uses your phone location only to find the weather where you are. You can type a city name instead.')) {
        return 'User declined location. Ask for a city name.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return 'Location permission denied. Ask the user for a city name.';
      }
      // fresh GPS fix (not the cached last-known location)
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)));
      loc = {'lat': '${pos.latitude}', 'lon': '${pos.longitude}'};
    } catch (_) {
      return 'Could not get GPS location. Ask the user for a city name.';
    }
  }
  final ck = 'w:${loc.values.join(',')}';
  final c = _cached(ck);
  if (c != null) return c;
  final r = await _call(
      'OpenWeather',
      (k) => http.get(Uri.https('api.openweathermap.org', '/data/2.5/weather',
          {...loc, 'appid': k, 'units': 'metric'})),
      allow404: true);
  if (r == null) return 'Weather service unavailable (check OpenWeather keys).';
  if (r.statusCode == 404) return 'City not found. Ask the user to check the city name.';
  final j = _json(r);
  final t = DateTime.fromMillisecondsSinceEpoch((j['dt'] as int) * 1000, isUtc: true)
      .add(Duration(seconds: (j['timezone'] ?? 0) as int));
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return _keep(
      ck,
      '${j['name']}, ${j['sys']?['country'] ?? ''}: ${j['weather'][0]['description']}, '
      '${j['main']['temp']}°C (feels ${j['main']['feels_like']}°C), humidity ${j['main']['humidity']}%, '
      'wind ${j['wind']?['speed'] ?? '?'} m/s. Local time there: $hm.');
}

final _infoDefs = [
  {
    'type': 'function',
    'function': {
      'name': 'web_search',
      'description': 'Search the web for current facts, prices, events or anything that may have changed recently.',
      'parameters': {
        'type': 'object',
        'properties': {'query': {'type': 'string'}},
        'required': ['query']
      }
    }
  },
  {
    'type': 'function',
    'function': {
      'name': 'get_news',
      'description': 'Get the latest news headlines. Optional topic and 2-letter country code (pk, us, gb).',
      'parameters': {
        'type': 'object',
        'properties': {'query': {'type': 'string'}, 'country': {'type': 'string'}}
      }
    }
  },
  {
    'type': 'function',
    'function': {
      'name': 'get_weather',
      'description': 'Get current weather. Leave city empty to use the phone GPS location.',
      'parameters': {
        'type': 'object',
        'properties': {'city': {'type': 'string'}}
      }
    }
  },
];

final allTools = [..._infoDefs, ...actionDefs];

String toolLabel(String n) => switch (n) {
      'web_search' => 'Searching the web…',
      'get_news' => 'Fetching news…',
      'get_weather' => 'Checking weather…',
      _ => actionLabel(n),
    };

Future<String> runTool(String name, Map a) async {
  switch (name) {
    case 'web_search':
      return webSearch('${a['query'] ?? ''}');
    case 'get_news':
      return getNews(a['query']?.toString(), a['country']?.toString());
    case 'get_weather':
      return getWeather(a['city']?.toString());
    default:
      return runAction(name, a);
  }
}
