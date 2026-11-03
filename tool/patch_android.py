#!/usr/bin/env python3
"""
يعدّل مشروع Android الذي ينشئه `flutter create` ليعمل التنبيه بشكل صحيح (Android 13 وما فوق):
  - الأذونات (إشعارات، منبّه دقيق، شاشة كاملة، إعادة التشغيل)
  - استقبال الجدولة بعد إعادة تشغيل الهاتف
  - إظهار التطبيق فوق شاشة القفل عند رنين المنبّه
  - تفعيل desugaring (شرط مكتبة الإشعارات)
  - نسخ صوت المنبّه إلى res/raw
شغّله من جذر المشروع بعد: flutter create --platforms=android,windows .
"""
import pathlib
import re
import shutil
import sys

root = pathlib.Path('android')
manifest = root / 'app/src/main/AndroidManifest.xml'
if not manifest.exists():
    sys.exit('android/ غير موجود. شغّل أولاً: flutter create --platforms=android .')

s = manifest.read_text(encoding='utf-8')

# ---- الأذونات ----
perms = [
    'POST_NOTIFICATIONS',
    'SCHEDULE_EXACT_ALARM',
    'USE_FULL_SCREEN_INTENT',
    'RECEIVE_BOOT_COMPLETED',
    'VIBRATE',
    'WAKE_LOCK',
]
lines = [
    f'<uses-permission android:name="android.permission.{p}"/>'
    for p in perms
    if f'android.permission.{p}"' not in s
]
if lines:
    block = '\n    ' + '\n    '.join(lines)
    s = re.sub(r'(<manifest[^>]*>)', lambda m: m.group(1) + block, s, count=1)

# ---- الـ Activity فوق شاشة القفل ----
if 'android:showWhenLocked' not in s:
    s = s.replace(
        '<activity',
        '<activity\n            android:showWhenLocked="true"\n            android:turnScreenOn="true"',
        1,
    )

# ---- مستقبلات الجدولة وإعادة التشغيل ----
if 'ScheduledNotificationReceiver' not in s:
    receivers = '''
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    '''
    s = s.replace('</application>', receivers + '</application>', 1)

# ---- اسم التطبيق ----
s = re.sub(
    r'(<application[^>]*?android:label=")[^"]*(")',
    lambda m: m.group(1) + 'مهامي' + m.group(2),
    s,
    count=1,
    flags=re.S,
)
manifest.write_text(s, encoding='utf-8')

# ---- Gradle: core library desugaring ----
gradle = None
for name in ('build.gradle.kts', 'build.gradle'):
    p = root / 'app' / name
    if p.exists():
        gradle = p
        break
if gradle is None:
    sys.exit('لم أجد android/app/build.gradle(.kts)')

g = gradle.read_text(encoding='utf-8')
if 'desugar_jdk_libs' not in g:
    if gradle.suffix == '.kts':
        g = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', g, count=1)
        g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")\n}\n'
    else:
        g = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        coreLibraryDesugaringEnabled true', g, count=1)
        g += '\ndependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.5"\n}\n'
    gradle.write_text(g, encoding='utf-8')

# ---- صوت المنبّه ----
raw = root / 'app/src/main/res/raw'
raw.mkdir(parents=True, exist_ok=True)
shutil.copy('assets/sounds/alarm.wav', raw / 'alarm.wav')

print('Android patched OK')
