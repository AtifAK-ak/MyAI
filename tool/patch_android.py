import pathlib, re

# ---- AndroidManifest ----
m = pathlib.Path('android/app/src/main/AndroidManifest.xml')
s = m.read_text()
perms = ['INTERNET', 'RECORD_AUDIO', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION',
         'CALL_PHONE', 'READ_CONTACTS', 'VIBRATE', 'POST_NOTIFICATIONS',
         'SCHEDULE_EXACT_ALARM', 'RECEIVE_BOOT_COMPLETED']
p = ''.join(f'    <uses-permission android:name="android.permission.{x}"/>\n' for x in perms)
s = s.replace('<application', p + '    <application', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Alex AI"', s, count=1)

pkgs = ['com.instagram.android', 'com.zhiliaoapp.musically', 'com.google.android.youtube',
        'com.whatsapp', 'com.facebook.katana', 'com.twitter.android', 'org.telegram.messenger',
        'com.snapchat.android', 'com.android.chrome', 'com.google.android.gm',
        'com.google.android.apps.maps', 'com.spotify.music']
q = ''.join(f'        <package android:name="{x}"/>\n' for x in pkgs)
q += '        <intent><action android:name="android.speech.RecognitionService"/></intent>\n'
q += '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n'
if '<queries>' in s:
    s = s.replace('<queries>', '<queries>\n' + q, 1)
else:
    s = s.replace('</manifest>', '    <queries>\n' + q + '    </queries>\n</manifest>')

rec = '''        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''
s = s.replace('</application>', rec + '    </application>', 1)
m.write_text(s)

# ---- Gradle: desugaring (notifications) + minSdk 24 ----
kts = pathlib.Path('android/app/build.gradle.kts')
grv = pathlib.Path('android/app/build.gradle')
if kts.exists():
    t = kts.read_text()
    t = t.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 1)
    t = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24', t)
    t += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    kts.write_text(t)
elif grv.exists():
    t = grv.read_text()
    t = t.replace('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true', 1)
    t = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24', t)
    t += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    grv.write_text(t)
print('patched')
