import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'groq.dart';
import 'store.dart';

TextDirection dirOf(String s) =>
    RegExp(r'[\u0600-\u06FF]').hasMatch(s) ? TextDirection.rtl : TextDirection.ltr;

Future<bool> confirm(BuildContext c, String text) async =>
    await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Yes')),
        ],
      ),
    ) ??
    false;

// ---------------- Name screen (first open) ----------------
class NameScreen extends StatefulWidget {
  const NameScreen({super.key});
  @override
  State<NameScreen> createState() => _NameState();
}

class _NameState extends State<NameScreen> {
  final c = TextEditingController();

  Future<void> go() async {
    final n = c.text.trim();
    if (n.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('name', n);
    userName = n;
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.asset('assets/logo.png', width: 110, height: 110)),
              const SizedBox(height: 16),
              Text('Alex AI', style: t.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
              const Text('Your Personal Assistant AI'),
              const SizedBox(height: 40),
              TextField(
                controller: c,
                textAlign: TextAlign.center,
                onSubmitted: (_) => go(),
                decoration: InputDecoration(
                  hintText: 'آپ کا نام / Your name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: go, child: const Text('Continue')),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Chat screen ----------------
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatState();
}

class _ChatState extends State<ChatScreen> {
  Chat? cur;
  bool busy = false;
  String status = 'Alex is typing…';
  final stt = SpeechToText();
  bool listening = false;
  final input = TextEditingController();
  final scroll = ScrollController();

  void _down() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> mic() async {
    if (listening) {
      await stt.stop();
      setState(() => listening = false);
      return;
    }
    if (!await disclose('mic', 'Alex uses the microphone only when you tap the mic button, to turn your speech into text.')) return;
    final ok = await stt.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) setState(() => listening = false);
      },
      onError: (_) {
        if (mounted) setState(() => listening = false);
      },
    );
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone or speech service not available')));
      }
      return;
    }
    setState(() => listening = true);
    await stt.listen(
      localeId: sttLocale.value,
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(partialResults: true),
      onResult: (r) {
        input.text = r.recognizedWords;
        input.selection = TextSelection.collapsed(offset: input.text.length);
      },
    );
  }

  Future<void> send() async {
    final t = input.text.trim();
    if (t.isEmpty || busy) return;
    input.clear();
    final chat = cur ??= Chat(DateTime.now().microsecondsSinceEpoch.toString(),
        t.length > 28 ? '${t.substring(0, 28)}…' : t, [], 0);
    if (!Chats.all.contains(chat)) Chats.all.add(chat);
    chat.msgs.add(Msg('user', t));
    chat.ts = DateTime.now().millisecondsSinceEpoch;
    if (listening) await stt.stop();
    setState(() {
      busy = true;
      listening = false;
      status = 'Alex is typing…';
    });
    _down();
    final a = await askAlex(chat.msgs, onStatus: (s) {
      if (mounted) setState(() => status = s);
    });
    chat.msgs.add(Msg('assistant', a));
    await Chats.save();
    if (!mounted) return;
    setState(() => busy = false);
    _down();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final msgs = cur?.msgs ?? <Msg>[];
    final sorted = [...Chats.all]..sort((a, b) => b.ts.compareTo(a.ts));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alex AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              setState(() {});
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.note_alt_outlined),
                title: const Text('Notes'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New Chat'),
                onTap: () {
                  setState(() => cur = null);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    for (final c in sorted)
                      ListTile(
                        title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        selected: c == cur,
                        onTap: () {
                          setState(() => cur = c);
                          Navigator.pop(context);
                          _down();
                        },
                        onLongPress: () async {
                          if (await confirm(context, 'Delete this chat?')) {
                            Chats.all.remove(c);
                            if (cur == c) cur = null;
                            await Chats.save();
                            setState(() {});
                          }
                        },
                      ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_sweep),
                title: const Text('Clear all chats'),
                onTap: () async {
                  if (await confirm(context, 'Delete ALL chats?')) {
                    Chats.all.clear();
                    cur = null;
                    await Chats.save();
                    if (!mounted) return;
                    setState(() {});
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: msgs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('ویلکم، $userName 👋\nمیں آپ کی کیا مدد کر سکتا ہوں؟',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      final me = m.role == 'user';
                      return Align(
                        alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                          decoration: BoxDecoration(
                            color: me ? cs.primaryContainer : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SelectableText(m.text, textDirection: dirOf(m.text)),
                        ),
                      );
                    },
                  ),
          ),
          if (busy) Padding(padding: const EdgeInsets.all(8), child: Text(status)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Message Alex…',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: busy ? null : mic,
                    icon: Icon(listening ? Icons.stop_circle : Icons.mic, color: listening ? Colors.red : null),
                  ),
                  IconButton.filled(onPressed: busy ? null : send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Settings ----------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  static const colors = [0xFF6C63FF, 0xFF00A884, 0xFFE53935, 0xFFFB8C00, 0xFF1E88E5, 0xFFD81B60];

  Future<void> setTheme(ThemeMode m) async {
    themeMode.value = m;
    (await SharedPreferences.getInstance()).setInt('theme', m.index);
    setState(() {});
  }

  Future<void> setAccent(int c) async {
    accent.value = Color(c);
    (await SharedPreferences.getInstance()).setInt('accent', c);
    setState(() {});
  }

  Future<void> addKey(String p) async {
    final c = TextEditingController();
    final k = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('$p key'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Paste key')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (k == null || k.isEmpty) return;
    Keys.data[p]!.add(KeyItem(k));
    await Keys.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {themeMode.value},
            onSelectionChanged: (s) => setTheme(s.first),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              for (final c in colors)
                GestureDetector(
                  onTap: () => setAccent(c),
                  child: CircleAvatar(
                    backgroundColor: Color(c),
                    child: accent.value == Color(c) ? const Icon(Icons.check, color: Colors.white) : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Mic language', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en_US', label: Text('English')),
              ButtonSegment(value: 'ur_PK', label: Text('اردو')),
            ],
            selected: {sttLocale.value},
            onSelectionChanged: (s) async {
              sttLocale.value = s.first;
              (await SharedPreferences.getInstance()).setString('stt', s.first);
              setState(() {});
            },
          ),
          const SizedBox(height: 24),
          TextFormField(
            initialValue: countryCode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Country code for WhatsApp numbers starting with 0 (e.g. 92)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) async {
              countryCode = v.trim();
              (await SharedPreferences.getInstance()).setString('cc', countryCode);
            },
          ),
          const SizedBox(height: 24),
          Text('API Keys', style: Theme.of(context).textTheme.titleMedium),
          const Text('If one key fails or runs out, Alex switches to the next one automatically.'),
          const SizedBox(height: 8),
          for (final p in providers)
            ExpansionTile(
              title: Text('$p (${Keys.data[p]!.length})'),
              children: [
                for (final k in List<KeyItem>.from(Keys.data[p]!))
                  ListTile(
                    title: Text(Keys.mask(k.key)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: k.on,
                          onChanged: (v) async {
                            k.on = v;
                            await Keys.save();
                            setState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            Keys.data[p]!.remove(k);
                            await Keys.save();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => addKey(p),
                  icon: const Icon(Icons.add),
                  label: const Text('Add key'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------- Notes ----------------
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesState();
}

class _NotesState extends State<NotesScreen> {
  List<String> notes = [];

  @override
  void initState() {
    super.initState();
    Notes.load().then((n) => setState(() => notes = n));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: notes.isEmpty
          ? const Center(child: Text('No notes yet. Say: "Alex, note: buy milk"'))
          : ListView(
              children: [
                for (var i = 0; i < notes.length; i++)
                  ListTile(
                    title: Text(notes[i]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        notes.removeAt(i);
                        await Notes.save(notes);
                        setState(() {});
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
