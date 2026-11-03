import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../alarm/alarm_service.dart';
import '../app_state.dart';

Future<void> showSettings(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _SettingsDialog());

const _accents = [0xFF0078D4, 0xFF107C10, 0xFFD13438, 0xFF8764B8, 0xFFCA5010, 0xFF038387];

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  bool _auto = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      launchAtStartup.isEnabled().then((v) {
        if (mounted) setState(() => _auto = v);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => AlertDialog(
        title: const Text('الإعدادات'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('المظهر'),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('فاتح')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('داكن')),
                    ButtonSegment(value: ThemeMode.system, label: Text('النظام')),
                  ],
                  selected: {store.themeMode},
                  onSelectionChanged: (s) => store.setTheme(s.first),
                ),
                const SizedBox(height: 16),
                const Text('اللون المميز'),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final c in _accents)
                    GestureDetector(
                      onTap: () => store.setAccent(c),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(c),
                        child: store.accent == c
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                    ),
                ]),
                if (Platform.isWindows) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('التشغيل مع ويندوز'),
                    value: _auto,
                    onChanged: (v) async {
                      if (v) {
                        await launchAtStartup.enable();
                      } else {
                        await launchAtStartup.disable();
                      }
                      setState(() => _auto = v);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('جرّب التنبيه بعد 10 ثوانٍ'),
                  onPressed: () {
                    final messenger = ScaffoldMessenger.of(context);
                    alarmService.schedule(AlarmRequest(
                      id: 1,
                      title: 'تجربة التنبيه',
                      body: 'إذا سمعت الصوت فكل شيء يعمل',
                      fireAt: DateTime.now().add(const Duration(seconds: 10)),
                    ));
                    Navigator.pop(context);
                    messenger.showSnackBar(const SnackBar(
                      content: Text('سيرن التنبيه بعد 10 ثوانٍ. يمكنك قفل الشاشة للتجربة.'),
                    ));
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}
