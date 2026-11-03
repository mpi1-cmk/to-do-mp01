import 'package:flutter/material.dart';

import '../alarm/alarm_service.dart';
import '../app_state.dart';
import '../models.dart';

/// شاشة التنبيه الكاملة: تظهر فوق قفل الشاشة عند رنين المنبه.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key, required this.alarmId});

  final int alarmId;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  bool _busy = false;

  Future<void> _act(AlarmAction a) async {
    if (_busy) return;
    setState(() => _busy = true);
    await store.applyAlarmAction(widget.alarmId, a);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = store.byAlarmId(widget.alarmId);
    final title = (t == null || t.title.isEmpty) ? 'تنبيه' : t.title;

    return Scaffold(
      backgroundColor: scheme.primaryContainer,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.alarm, size: 72, color: scheme.onPrimaryContainer),
                const SizedBox(height: 12),
                Text(
                  fmtTime(t?.dueAt ?? DateTime.now()),
                  style: text.displayLarge?.copyWith(color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.headlineMedium?.copyWith(color: scheme.onPrimaryContainer),
                ),
                if (t != null && t.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(t.notes, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 32),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final a in [
                      AlarmAction.snooze5,
                      AlarmAction.snooze10,
                      AlarmAction.snooze15,
                    ])
                      FilledButton.tonal(
                        onPressed: () => _act(a),
                        child: Text('تأجيل ${a.snoozeFor!.inMinutes} د'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _act(AlarmAction.done),
                  icon: const Icon(Icons.check),
                  label: const Text('تم'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
