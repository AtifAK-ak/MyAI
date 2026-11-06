import 'package:flutter/material.dart';
import 'screens.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadPrefs();
  await Keys.load();
  await Chats.load();
  runApp(const AlexApp());
}

class AlexApp extends StatelessWidget {
  const AlexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeMode, accent]),
      builder: (_, __) => MaterialApp(
        navigatorKey: navKey,
        builder: (c, child) => RepaintBoundary(key: shotKey, child: child),
        title: 'Alex AI',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode.value,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: accent.value, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: accent.value, brightness: Brightness.dark),
        home: userName.isEmpty ? const NameScreen() : const ChatScreen(),
      ),
    );
  }
}
