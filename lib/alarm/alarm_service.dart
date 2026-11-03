import 'dart:io';

import 'android_alarm_service.dart';
import 'windows_alarm_service.dart';

enum AlarmAction {
  snooze5(Duration(minutes: 5)),
  snooze10(Duration(minutes: 10)),
  snooze15(Duration(minutes: 15)),
  done(null),
  open(null); // المستخدم ضغط على التنبيه نفسه

  const AlarmAction(this.snoozeFor);
  final Duration? snoozeFor;
}

class AlarmRequest {
  const AlarmRequest({
    required this.id,
    required this.title,
    required this.fireAt,
    this.body,
  });

  final int id;
  final String title;
  final String? body;
  final DateTime fireAt;
}

typedef AlarmActionCallback = void Function(AlarmAction action, int alarmId);

abstract class AlarmService {
  Future<void> init({required AlarmActionCallback onAction});
  Future<void> requestPermissions();
  Future<void> schedule(AlarmRequest request);
  Future<void> cancel(int alarmId);

  /// يوقف الصوت المتكرر للتنبيه الجاري.
  Future<void> stopRinging(int alarmId);

  static AlarmService create() =>
      Platform.isAndroid ? AndroidAlarmService() : WindowsAlarmService();
}
