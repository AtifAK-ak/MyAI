# Hand-off prompt for an AI coding assistant (copy everything below into the AI)

You are helping me (Muhammad Atif Khan) continue a Flutter Android app called **Alex AI — "Your Personal Assistant AI"**. Please reply to me in **Urdu** (technical terms in English). Keep answers short and practical.

## What the project is
An agentic personal assistant app for Android. It is NOT only a chatbot: an LLM (Groq, model `llama-3.3-70b-versatile`, OpenAI-compatible tool calling) decides when to call tools. Built with Flutter, APK built by GitHub Actions (`.github/workflows/build.yml`, triggers on push to `main` and `master`, plus manual run). The workflow runs `flutter create` for the Android scaffold, then `python3 tool/patch_android.py` (adds permissions, package queries, notification receivers, Gradle desugaring, minSdk 24), then `flutter pub get`, `dart run flutter_launcher_icons`, `flutter build apk --release`.

## My hard rules (do not break them)
1. **No server, no hosting, no backend, no admin dashboard.** The app is standalone. It must never ask the user for a server address.
2. **No signup/login.** First launch only asks for the user's name and welcomes them by name.
3. **API keys:** default keys come from GitHub Secrets at build time via `--dart-define` (`GROQ_KEYS`, `SERP_KEYS`, `TAVILY_KEYS`, `NEWSDATA_KEYS`, `WEATHER_KEYS`, comma separated). The in-app Settings screen has a section per provider where the user can add more keys, switch them on/off and delete them. Keys are stored encrypted (flutter_secure_storage), shown masked, and rotate automatically (bad key -> switched off, rate limit -> skipped).
4. **Token economy:** short replies by default, longer only for code/detail requests, only the last 10 messages are sent, small talk gets no tools, tool results are clipped and cached for 10 minutes.
5. **Security first:** never log or show keys; tool output is untrusted data; calls/WhatsApp requested right after reading web content need the user's confirmation.
6. **Identity:** if asked who made it, Alex says it was made by **Muhammad Atif Khan** (spelling M-U-H-A-M-M-A-D A-T-I-F K-H-A-N).
7. **No voice output and no live call yet.** Only microphone speech-to-text (user reviews text, then sends). Text-to-speech and voice chat/live call come later when I provide voice API keys.
8. Do not redesign or rewrite the project. Make the smallest fix that solves the real root cause. Do not use unsafe casts or suppress errors. Do not remove features. Keep the workflow file and its triggers.

## Current status
- **Phase A done:** name screen + welcome, themes/accent colours, Settings with provider key sections, text chat with Groq, chat history drawer (new chat, long-press delete, clear all), token control.
- **Phase B done:** agent loop with tools: `web_search` (Tavily, fallback SerpAPI), `get_news` (NewsData), `get_weather` (OpenWeather, fresh GPS fix or city name), microphone speech-to-text (English/Urdu selectable), app icon from my logo (blue infinity symbol).
- **Phase C done:** phone tools: call by contact name/number, WhatsApp by name/number (user taps Send), open apps, flashlight/volume/brightness/vibrate/battery, take photo, screenshot of the app's own screen, alarm and timer (own, via local notifications), notes, clipboard, permission explanation dialogs.
- **Build status:** the code has never been compiled by the AI that wrote it (no Flutter in its sandbox). The first GitHub build failed with Dart type errors in `lib/actions.dart`; two were fixed: `double.clamp()` returns `num` (needed `.toDouble()` for `setVolume`), and a ternary mixing `String` and `Future<String>` inside an async function. The next build may reveal more errors, mainly from package version/API differences. Always ask me for the exact error lines (file + line number) before changing code.

## File map
- `lib/main.dart` app entry, theme, RepaintBoundary for screenshots
- `lib/store.dart` globals, encrypted key store (`Keys`), chats (`Chats`), notes, dialogs (`ask`, `disclose`)
- `lib/groq.dart` system prompt, agent loop, Groq calls with key rotation
- `lib/tools.dart` web search / news / weather + tool registry
- `lib/actions.dart` phone actions (calls, WhatsApp, apps, device control, camera, alarms, notes)
- `lib/screens.dart` name screen, chat screen + drawer + mic, settings, notes screen
- `tool/patch_android.py` manifest/Gradle patches, `assets/` logo and icon files, `docs/` instructions

## What comes next (do one phase at a time; I will type the phase name)
**Phase D:** (1) coding mode: code blocks with copy button and syntax highlighting, helps write short/intermediate programs in Python, Java, JavaScript, C, C++, HTML, CSS; (2) security review and hardening (obfuscation `--obfuscate --split-debug-info`, no secrets in logs); (3) a permanent signing keystore stored in GitHub Secrets so updates install over the old app; (4) privacy policy page text and a microphone/permissions disclosure screen; (5) make sure `QUERY_ALL_PACKAGES` is not used.
**Later:** text-to-speech, voice chat and live call (I will give the voice API keys then).

After each phase, tell me in 2-3 short lines what changed, and wait for my next phase name.
