import 'dart:ui' as ui;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:volume_controller/volume_controller.dart';
import 'store.dart';

const sensitiveTools = {'call_contact', 'call_number', 'send_whatsapp'};

const _s = {'type': 'string'};
const _n = {'type': 'number'};

Map<String, Object> _t(String name, String desc,
        [Map<String, Object> props = const {}, List<String> req = const []]) =>
    {
      'type': 'function',
      'function': {
        'name': name,
        'description': desc,
        'parameters': {
          'type': 'object',
          'properties': props,
          if (req.isNotEmpty) 'required': req,
        }
      }
    };

final actionDefs = [
  _t('call_contact', 'Call a saved contact by name.', {'name': _s}, ['name']),
  _t('call_number', 'Call a phone number.', {'number': _s}, ['number']),
  _t('send_whatsapp', 'Open a WhatsApp chat with the message typed (user taps Send). "to" is a contact name or number.', {'to': _s, 'message': _s}, ['to']),
  _t('open_app', 'Open an app: instagram, tiktok, youtube, whatsapp, facebook, x, telegram, snapchat, chrome, gmail, maps, spotify, camera, gallery, settings, dialer, calculator, contacts, messages, calendar, browser, email.', {'name': _s}, ['name']),
  _t('device_control', 'Phone control. action: flashlight_on, flashlight_off, volume (value 0-100), volume_up, volume_down, mute, brightness (value 0-100), vibrate, battery.', {'action': _s, 'value': _n}, ['action']),
  _t('take_photo', 'Open the camera and take a photo (saved to gallery).'),
  _t('take_screenshot', 'Screenshot of the Alex app screen (saved to gallery).'),
  _t('set_alarm', 'Set an alarm at 24-hour time HH:mm (next occurrence).', {'time': _s, 'label': _s}, ['time']),
  _t('set_timer', 'Set a countdown timer in minutes.', {'minutes': _n, 'label': _s}, ['minutes']),
  _t('save_note', 'Save a note.', {'text': _s}, ['text']),
  _t('read_notes', 'Read the saved notes.'),
  _t('clipboard', 'Clipboard: action "read" or "copy" (with text).', {'action': _s, 'text': _s}, ['action']),
];

String actionLabel(String n) => switch (n) {
      'call_contact' || 'call_number' => 'Calling…',
      'send_whatsapp' => 'Opening WhatsApp…',
      'open_app' => 'Opening app…',
      'take_photo' => 'Opening camera…',
      _ => 'Working…',
    };

// ---------- contacts, calls, WhatsApp ----------
Future<(String?, String)> _numberFor(String name) async {
  if (!await disclose('contacts', 'Alex needs access to your contacts so it can call or message people by name. Contacts stay on your phone.')) {
    return (null, 'User declined contacts access.');
  }
  if (!await FlutterContacts.requestPermission(readonly: true)) {
    return (null, 'Contacts permission denied.');
  }
  final all = await FlutterContacts.getContacts(withProperties: true);
  final q = name.trim().toLowerCase();
  var m = all.where((c) => c.phones.isNotEmpty && c.displayName.toLowerCase() == q).toList();
  if (m.isEmpty) {
    m = all.where((c) => c.phones.isNotEmpty && c.displayName.toLowerCase().contains(q)).toList();
  }
  if (m.isEmpty) {
    return (null, 'No contact matched "$name". Try another spelling (English or Urdu) or ask the user for the number.');
  }
  if (m.length > 1) {
    return (null, 'Several contacts match: ${m.take(5).map((c) => c.displayName).join(', ')}. Ask the user which one.');
  }
  return (m.first.phones.first.number, m.first.displayName);
}

Future<String> _call(String number, String who) async {
  if (!await disclose('call', 'Alex needs permission to place phone calls when you ask it to.')) {
    return 'User declined call permission.';
  }
  final ok = await FlutterPhoneDirectCaller.callNumber(number);
  return ok == true ? 'Calling $who.' : 'Call could not be started (permission denied?).';
}

String _waNumber(String n) {
  final d = n.replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.startsWith('+')) return d.substring(1);
  if (d.startsWith('00')) return d.substring(2);
  if (d.startsWith('0')) return countryCode + d.substring(1);
  return d;
}

Future<String> _whatsapp(String to, String msg) async {
  var num = to;
  var who = to;
  if (!RegExp(r'^[+0-9 ()-]{6,}$').hasMatch(to.trim())) {
    final (n, w) = await _numberFor(to);
    if (n == null) return w;
    num = n;
    who = w;
  }
  final u = Uri.parse('https://wa.me/${_waNumber(num)}?text=${Uri.encodeComponent(msg)}');
  final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
  return ok
      ? 'WhatsApp chat with $who opened with the message typed. The user must tap Send.'
      : 'Could not open WhatsApp.';
}

// ---------- open apps ----------
const _pkgs = {
  'instagram': 'com.instagram.android', 'tiktok': 'com.zhiliaoapp.musically',
  'youtube': 'com.google.android.youtube', 'whatsapp': 'com.whatsapp',
  'facebook': 'com.facebook.katana', 'x': 'com.twitter.android', 'twitter': 'com.twitter.android',
  'telegram': 'org.telegram.messenger', 'snapchat': 'com.snapchat.android',
  'chrome': 'com.android.chrome', 'gmail': 'com.google.android.gm',
  'maps': 'com.google.android.apps.maps', 'spotify': 'com.spotify.music',
};
const _cats = {
  'calculator': 'APP_CALCULATOR', 'contacts': 'APP_CONTACTS', 'messages': 'APP_MESSAGING',
  'calendar': 'APP_CALENDAR', 'gallery': 'APP_GALLERY', 'browser': 'APP_BROWSER',
  'email': 'APP_EMAIL', 'music': 'APP_MUSIC',
};

Future<String> _openApp(String name) async {
  final n = name.toLowerCase().replaceFirst('google ', '').trim();
  final nt = [Flag.FLAG_ACTIVITY_NEW_TASK];
  try {
    if (n == 'settings') {
      await AndroidIntent(action: 'android.settings.SETTINGS', flags: nt).launch();
    } else if (n == 'camera') {
      await AndroidIntent(action: 'android.media.action.STILL_IMAGE_CAMERA', flags: nt).launch();
    } else if (n == 'dialer' || n == 'phone') {
      await AndroidIntent(action: 'android.intent.action.DIAL', flags: nt).launch();
    } else if (_cats.containsKey(n)) {
      await AndroidIntent(action: 'android.intent.action.MAIN', category: 'android.intent.category.${_cats[n]}', flags: nt).launch();
    } else if (_pkgs.containsKey(n)) {
      await AndroidIntent(action: 'android.intent.action.MAIN', category: 'android.intent.category.LAUNCHER', package: _pkgs[n], flags: nt).launch();
    } else {
      return 'App "$name" is not in my list.';
    }
    return 'Opened $name.';
  } catch (_) {
    return 'Could not open $name (is it installed?).';
  }
}

// ---------- device control ----------
Future<String> _device(String action, dynamic value) async {
  final v = ((num.tryParse('$value') ?? 50).clamp(0, 100) / 100).toDouble();
  switch (action) {
    case 'flashlight_on':
      await TorchLight.enableTorch();
      return 'Flashlight on.';
    case 'flashlight_off':
      await TorchLight.disableTorch();
      return 'Flashlight off.';
    case 'volume':
      VolumeController().setVolume(v);
      return 'Volume set to ${(v * 100).round()}%.';
    case 'mute':
      VolumeController().setVolume(0);
      return 'Muted.';
    case 'volume_up':
    case 'volume_down':
      final cur = await VolumeController().getVolume();
      final nv = (cur + (action == 'volume_up' ? 0.1 : -0.1)).clamp(0.0, 1.0);
      VolumeController().setVolume(nv);
      return 'Volume ${(nv * 100).round()}%.';
    case 'brightness':
      await ScreenBrightness().setScreenBrightness(v);
      return 'Brightness set to ${(v * 100).round()}% (for this app).';
    case 'vibrate':
      await Vibration.vibrate(duration: 600);
      return 'Vibrated.';
    case 'battery':
      return 'Battery is ${await Battery().batteryLevel}%.';
    default:
      return 'Unknown device action.';
  }
}

// ---------- photo & screenshot ----------
Future<String> _photo() async {
  final f = await ImagePicker().pickImage(source: ImageSource.camera);
  if (f == null) return 'Camera closed without a photo.';
  try {
    await Gal.putImage(f.path);
    return 'Photo taken and saved to the gallery.';
  } catch (_) {
    return 'Photo taken but could not be saved to the gallery.';
  }
}

Future<String> _screenshot() async {
  final b = shotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (b == null) return 'Screenshot failed.';
  final img = await b.toImage(pixelRatio: 2);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) return 'Screenshot failed.';
  await Gal.putImageBytes(data.buffer.asUint8List());
  return "Screenshot of the Alex app screen saved to the gallery (Android only lets an app capture its own screen).";
}

// ---------- alarm & timer (Alex's own, via notifications) ----------
final _np = FlutterLocalNotificationsPlugin();
bool _npReady = false;

Future<String> _schedule(DateTime when, String label) async {
  if (!_npReady) {
    tzdata.initializeTimeZones();
    await _np.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _npReady = true;
  }
  final a = _np.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await a?.requestNotificationsPermission();
  var mode = AndroidScheduleMode.exactAllowWhileIdle;
  if (await a?.canScheduleExactNotifications() != true) {
    await a?.requestExactAlarmsPermission();
    if (await a?.canScheduleExactNotifications() != true) {
      mode = AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }
  await _np.zonedSchedule(
    (when.millisecondsSinceEpoch ~/ 1000) % 2147483647,
    'Alex AI',
    label,
    tz.TZDateTime.from(when, tz.UTC),
    const NotificationDetails(
      android: AndroidNotificationDetails('alex_alarm', 'Alarms & timers',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          playSound: true,
          enableVibration: true),
    ),
    androidScheduleMode: mode,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
  );
  return mode == AndroidScheduleMode.exactAllowWhileIdle
      ? ''
      : ' (may be a few minutes late: exact-alarm permission was not given)';
}

Future<String> _alarm(String time, String label) async {
  final p = time.split(':');
  final now = DateTime.now();
  var t = DateTime(now.year, now.month, now.day, int.parse(p[0].trim()), int.parse(p[1].trim()));
  if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
  final note = await _schedule(t, label.isEmpty ? 'Alarm' : label);
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return 'Alarm set for $hm${t.day != now.day ? ' tomorrow' : ''}.$note';
}

Future<String> _timer(num minutes, String label) async {
  final t = DateTime.now().add(Duration(seconds: (minutes * 60).round()));
  final note = await _schedule(t, label.isEmpty ? 'Timer finished' : label);
  return 'Timer set for $minutes minute(s).$note';
}

// ---------- entry point ----------
Future<String> runAction(String name, Map a) async {
  try {
    switch (name) {
      case 'call_contact':
        final (n, w) = await _numberFor('${a['name'] ?? ''}');
        return n == null ? w : _call(n, w);
      case 'call_number':
        return _call('${a['number'] ?? ''}', '${a['number'] ?? ''}');
      case 'send_whatsapp':
        return _whatsapp('${a['to'] ?? ''}', '${a['message'] ?? ''}');
      case 'open_app':
        return _openApp('${a['name'] ?? ''}');
      case 'device_control':
        return _device('${a['action'] ?? ''}', a['value']);
      case 'take_photo':
        return _photo();
      case 'take_screenshot':
        return _screenshot();
      case 'set_alarm':
        return _alarm('${a['time'] ?? ''}', '${a['label'] ?? ''}');
      case 'set_timer':
        return _timer(num.tryParse('${a['minutes']}') ?? 1, '${a['label'] ?? ''}');
      case 'save_note':
        final saved = await Notes.load();
        saved.insert(0, '${DateTime.now().toString().substring(0, 16)}  ${a['text'] ?? ''}');
        await Notes.save(saved);
        return 'Note saved.';
      case 'read_notes':
        final all = await Notes.load();
        return all.isEmpty ? 'No notes saved.' : all.take(10).join('\n');
      case 'clipboard':
        if ('${a['action']}' == 'copy') {
          await Clipboard.setData(ClipboardData(text: '${a['text'] ?? ''}'));
          return 'Copied to clipboard.';
        }
        final d = await Clipboard.getData('text/plain');
        return d?.text ?? 'Clipboard is empty.';
      default:
        return 'Unknown tool.';
    }
  } catch (e) {
    return 'Action failed: $e';
  }
}
