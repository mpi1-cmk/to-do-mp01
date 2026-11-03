import 'dart:typed_data';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../store.dart';
import 'alarm_service.dart';

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

// صوت الـ channel يُثبَّت عند إنشائه؛ لتغيير الصوت مستقبلاً غيّر هذا الاسم (v2...).
const String _channelId = 'task_alarm_v1';

AlarmAction _actionFrom(String? id) => switch (id) {
      'snooze_5' => AlarmAction.snooze5,
      'snooze_10' => AlarmAction.snooze10,
      'snooze_15' => AlarmAction.snooze15,
      'done' => AlarmAction.done,
      _ => AlarmAction.open,
    };

NotificationDetails _details() => NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'تنبيهات المهام',
        channelDescription: 'تنبيهات صوتية لمواعيد المهام',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound: const RawResourceAndroidNotificationSound('alarm'),
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        visibility: NotificationVisibility.public,
        // FLAG_INSISTENT = 4 → يكرر الصوت حتى يُغلق التنبيه
        additionalFlags: Int32List.fromList([4]),
        // أندرويد يعرض 3 أزرار فقط؛ تأجيل 5/10/15 كاملة في شاشة التنبيه
        actions: const [
          AndroidNotificationAction('snooze_5', 'تأجيل 5 د',
              showsUserInterface: false, cancelNotification: true),
          AndroidNotificationAction('snooze_15', 'تأجيل 15 د',
              showsUserInterface: false, cancelNotification: true),
          AndroidNotificationAction('done', 'تم ✓',
              showsUserInterface: false, cancelNotification: true),
        ],
      ),
    );

/// يُنفَّذ في isolate خلفي عندما يضغط المستخدم زراً في الإشعار والتطبيق مغلق.
@pragma('vm:entry-point')
Future<void> alarmBackgroundHandler(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  final id = int.tryParse(r.payload ?? '');
  if (id == null) return;
  final action = _actionFrom(r.actionId);
  if (action == AlarmAction.open) return;
  final store = TaskStore(AndroidAlarmService());
  await store.load();
  await store.applyAlarmAction(id, action);
}

class AndroidAlarmService implements AlarmService {
  @override
  Future<void> init({required AlarmActionCallback onAction}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        final id = int.tryParse(r.payload ?? '');
        if (id != null) onAction(_actionFrom(r.actionId), id);
      },
      onDidReceiveBackgroundNotificationResponse: alarmBackgroundHandler,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'تنبيهات المهام',
      description: 'تنبيهات صوتية لمواعيد المهام',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
    ));

    // التطبيق فُتح من تنبيه (شاشة مقفلة / تطبيق مغلق)
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final resp = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && resp != null) {
      final id = int.tryParse(resp.payload ?? '');
      if (id != null) onAction(AlarmAction.open, id);
    }
  }

  @override
  Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission(); // Android 13+
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission();
  }

  @override
  Future<void> schedule(AlarmRequest r) async {
    // لحظة مطلقة بتوقيت UTC → لا حاجة لمعرفة المنطقة الزمنية للجهاز
    final u = r.fireAt.toUtc();
    await _plugin.zonedSchedule(
      id: r.id,
      title: r.title,
      body: r.body,
      scheduledDate: tz.TZDateTime.utc(u.year, u.month, u.day, u.hour, u.minute, u.second),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload: '${r.id}',
    );
  }

  @override
  Future<void> cancel(int alarmId) => _plugin.cancel(id: alarmId);

  @override
  Future<void> stopRinging(int alarmId) => _plugin.cancel(id: alarmId);
}
