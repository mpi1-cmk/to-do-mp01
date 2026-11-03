import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

import 'alarm_service.dart';

/// على Windows: مجدول داخل التطبيق (يعمل والتطبيق في الـ tray) + صوت متكرر + نافذة فوق كل شيء.
class WindowsAlarmService implements AlarmService {
  final Map<int, AlarmRequest> _pending = {};
  final AudioPlayer _player = AudioPlayer();
  late AlarmActionCallback _onAction;
  Timer? _ticker;
  bool _busy = false;

  @override
  Future<void> init({required AlarmActionCallback onAction}) async {
    _onAction = onAction;
    await localNotifier.setup(
      appName: 'مهامي',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
    // فحص كل 5 ثوانٍ: يتحمل نوم الجهاز بدل Timer واحد طويل
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> schedule(AlarmRequest r) async => _pending[r.id] = r;

  @override
  Future<void> cancel(int alarmId) async => _pending.remove(alarmId);

  @override
  Future<void> stopRinging(int alarmId) async {
    await _player.stop();
    await windowManager.setAlwaysOnTop(false);
  }

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      final now = DateTime.now();
      final due = _pending.values.where((r) => !r.fireAt.isAfter(now)).toList();
      for (final r in due) {
        _pending.remove(r.id);
        await _ring(r);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _ring(AlarmRequest r) async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/alarm.wav'));

    await windowManager.show();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.focus();

    const actions = [
      AlarmAction.snooze5,
      AlarmAction.snooze10,
      AlarmAction.snooze15,
      AlarmAction.done,
    ];

    final n = LocalNotification(
      title: r.title,
      body: r.body ?? 'حان موعد المهمة',
      actions: [
        LocalNotificationAction(text: 'تأجيل 5 د'),
        LocalNotificationAction(text: 'تأجيل 10 د'),
        LocalNotificationAction(text: 'تأجيل 15 د'),
        LocalNotificationAction(text: 'تم ✓'),
      ],
    );
    n.onClickAction = (i) => _onAction(actions[i], r.id);
    n.onClick = () => _onAction(AlarmAction.open, r.id);
    await n.show();

    _onAction(AlarmAction.open, r.id); // شاشة التنبيه داخل التطبيق
  }
}
