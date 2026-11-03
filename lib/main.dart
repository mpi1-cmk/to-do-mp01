import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import 'alarm/alarm_service.dart';
import 'alarm/desktop_shell.dart';
import 'app_state.dart';
import 'store.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  alarmService = AlarmService.create();
  store = TaskStore(alarmService);

  if (Platform.isWindows) {
    await DesktopShell().init();
    launchAtStartup.setup(
      appName: 'MyTasks',
      appPath: Platform.resolvedExecutable,
    );
  }

  await store.load();
  await alarmService.init(onAction: onAlarmAction);
  await store.rescheduleAll();

  runApp(const TasksApp());
}

ThemeData _theme(int seed, Brightness b) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Color(seed), brightness: b),
      visualDensity: VisualDensity.compact,
    );

class TasksApp extends StatefulWidget {
  const TasksApp({super.key});

  @override
  State<TasksApp> createState() => _TasksAppState();
}

class _TasksAppState extends State<TasksApp> with WidgetsBindingObserver {
  Timer? _watch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // التقاط تغييرات الإشعارات الخلفية (تأجيل/تم) في الواجهة
    _watch = Timer.periodic(const Duration(seconds: 3), (_) => store.reloadIfChanged());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      alarmService.requestPermissions(); // Android 13: إذن الإشعارات
      final p = pendingAlarmId;
      if (p != null) {
        pendingAlarmId = null;
        openAlarm(p);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) store.reloadIfChanged();
  }

  @override
  void dispose() {
    _watch?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'مهامي',
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: store.themeMode,
        theme: _theme(store.accent, Brightness.light),
        darkTheme: _theme(store.accent, Brightness.dark),
        home: const HomePage(),
      ),
    );
  }
}
