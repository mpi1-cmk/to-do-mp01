import 'package:flutter/material.dart';

import 'alarm/alarm_service.dart';
import 'store.dart';
import 'ui/alarm_screen.dart';

late final AlarmService alarmService;
late final TaskStore store;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

int? pendingAlarmId; // تنبيه فتح التطبيق قبل أن تجهز الواجهة
bool _alarmOpen = false;

void openAlarm(int id) {
  final nav = navigatorKey.currentState;
  if (nav == null) {
    pendingAlarmId = id;
    return;
  }
  if (_alarmOpen) return;
  _alarmOpen = true;
  nav
      .push(MaterialPageRoute<void>(builder: (_) => AlarmScreen(alarmId: id)))
      .whenComplete(() => _alarmOpen = false);
}

void onAlarmAction(AlarmAction a, int alarmId) {
  if (a == AlarmAction.open) {
    openAlarm(alarmId);
    return;
  }
  store.applyAlarmAction(alarmId, a).then((_) {
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  });
}
