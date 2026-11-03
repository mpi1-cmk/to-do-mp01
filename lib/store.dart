import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'alarm/alarm_service.dart';
import 'models.dart';

/// مصدر الحقيقة الوحيد: مهام + قوائم + إعدادات، محفوظة في ملف JSON محلي (Local-first).
/// نفس الكلاس يعمل داخل التطبيق وداخل الـ isolate الخلفي عند ضغط زر في الإشعار.
class TaskStore extends ChangeNotifier {
  TaskStore(this.alarms);

  final AlarmService alarms;

  static const smartIds = {'myday', 'important', 'planned', 'tasks'};

  List<Task> tasks = [];
  List<TaskList> lists = [];
  ThemeMode themeMode = ThemeMode.system;
  int accent = 0xFF0078D4;

  int _nextAlarmId = 1000;
  DateTime? _stamp;
  Timer? _debounce;

  // ───────────────────────── التخزين ─────────────────────────

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}tasks.json');
  }

  Future<void> load() async {
    final f = await _file();
    if (!await f.exists()) return;
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      tasks = [
        for (final t in (j['tasks'] as List? ?? const []))
          Task.fromJson(t as Map<String, dynamic>)
      ];
      lists = [
        for (final l in (j['lists'] as List? ?? const []))
          TaskList.fromJson(l as Map<String, dynamic>)
      ];
      _nextAlarmId = j['nextAlarmId'] as int? ?? 1000;
      themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == j['theme'],
        orElse: () => ThemeMode.system,
      );
      accent = j['accent'] as int? ?? accent;
      _stamp = await f.lastModified();
    } catch (_) {
      // ملف تالف: نبدأ بحالة فارغة بدل أن ينهار التطبيق
    }
  }

  Future<void> save() async {
    final f = await _file();
    final data = jsonEncode({
      'tasks': [for (final t in tasks) t.toJson()],
      'lists': [for (final l in lists) l.toJson()],
      'nextAlarmId': _nextAlarmId,
      'theme': themeMode.name,
      'accent': accent,
    });
    await f.writeAsString(data, flush: true);
    _stamp = await f.lastModified();
  }

  /// الإشعارات الخلفية تكتب في نفس الملف؛ هذه تلتقط تغييراتها لتحديث الواجهة.
  Future<void> reloadIfChanged() async {
    final f = await _file();
    if (!await f.exists()) return;
    final m = await f.lastModified();
    if (_stamp == null || m.isAfter(_stamp!)) {
      await load();
      notifyListeners();
    }
  }

  // ───────────────────────── الاستعلامات ─────────────────────────

  Task? byId(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Task? byAlarmId(int id) {
    for (final t in tasks) {
      if (t.alarmId == id) return t;
    }
    return null;
  }

  List<Task> view(String listId) {
    final now = DateTime.now();
    bool isToday(DateTime? d) =>
        d != null && d.year == now.year && d.month == now.month && d.day == now.day;

    final out = tasks.where((t) {
      switch (listId) {
        case 'myday':
          return t.myDay || isToday(t.dueAt);
        case 'important':
          return t.important;
        case 'planned':
          return t.dueAt != null;
        case 'tasks':
          return true;
        default:
          return t.listId == listId;
      }
    }).toList();

    out.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      final ad = a.dueAt, bd = b.dueAt;
      if (ad != null && bd != null) return ad.compareTo(bd);
      if (ad != null) return -1;
      if (bd != null) return 1;
      return b.id.compareTo(a.id);
    });
    return out;
  }

  int openCount(String listId) => view(listId).where((t) => !t.done).length;

  // ───────────────────────── العمليات ─────────────────────────

  Future<Task> addTask(String title, String listId) async {
    final t = Task(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      alarmId: _nextAlarmId++,
      title: title.trim(),
      listId: smartIds.contains(listId) ? 'tasks' : listId,
      myDay: listId == 'myday',
      important: listId == 'important',
    );
    tasks.add(t);
    await changed(t);
    return t;
  }

  /// استدعها بعد أي تعديل على مهمة: تعيد جدولة التنبيه وتحفظ وتحدّث الواجهة.
  Future<void> changed(Task t) async {
    await _syncAlarm(t);
    await save();
    notifyListeners();
  }

  /// للكتابة المتواصلة (العنوان/الملاحظات): تحديث فوري للواجهة وحفظ مؤجل.
  void saveSoon(Task t) {
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => changed(t));
  }

  Future<void> deleteTask(Task t) async {
    await alarms.cancel(t.alarmId);
    tasks.remove(t);
    await save();
    notifyListeners();
  }

  Future<void> toggleDone(Task t) async {
    if (t.done) {
      t.done = false;
      await changed(t);
    } else {
      await complete(t);
    }
  }

  /// إنهاء مهمة: المتكررة تنتقل للموعد التالي، والعادية تُعلَّم منجزة.
  Future<void> complete(Task t) async {
    t.snoozedUntil = null;
    final due = t.dueAt;
    if (t.repeat != Repeat.none && due != null) {
      t.dueAt = nextOccurrence(due, t.repeat, after: DateTime.now());
      for (final s in t.steps) {
        s.done = false;
      }
    } else {
      t.done = true;
    }
    await changed(t);
  }

  /// يُستدعى من أزرار الإشعار وشاشة التنبيه.
  Future<void> applyAlarmAction(int alarmId, AlarmAction a) async {
    await alarms.stopRinging(alarmId);
    final t = byAlarmId(alarmId);
    if (t == null) return;
    final d = a.snoozeFor;
    if (d != null) {
      t.snoozedUntil = DateTime.now().add(d);
      await changed(t);
    } else if (a == AlarmAction.done) {
      await complete(t);
    }
  }

  Future<void> _syncAlarm(Task t, {bool cancelStale = true}) async {
    final now = DateTime.now();
    final snooze = t.snoozedUntil;
    final when = (snooze != null && snooze.isAfter(now)) ? snooze : t.dueAt;

    if (t.done || when == null) {
      await alarms.cancel(t.alarmId);
      return;
    }
    if (when.isAfter(now)) {
      await alarms.schedule(AlarmRequest(
        id: t.alarmId,
        title: t.title.isEmpty ? 'مهمة' : t.title,
        body: t.notes.isEmpty ? null : t.notes,
        fireAt: when,
      ));
    } else if (cancelStale) {
      await alarms.cancel(t.alarmId);
    }
  }

  /// عند كل تشغيل: أعد جدولة كل التنبيهات القادمة (ضروري لـ Windows، ومفيد لـ Android).
  Future<void> rescheduleAll() async {
    final now = DateTime.now();
    for (final t in tasks) {
      final due = t.dueAt;
      if (t.done || due == null) continue;
      // مهمة متكررة فاتها موعدها بأكثر من ساعة: انتقل للموعد التالي بدل تركها متأخرة للأبد
      if (t.repeat != Repeat.none && due.isBefore(now.subtract(const Duration(hours: 1)))) {
        t.dueAt = nextOccurrence(due, t.repeat, after: now);
      }
      await _syncAlarm(t, cancelStale: false);
    }
    await save();
    notifyListeners();
  }

  // ───────────────────────── القوائم والإعدادات ─────────────────────────

  Future<TaskList> addList(String name) async {
    final l = TaskList(DateTime.now().microsecondsSinceEpoch.toString(), name);
    lists.add(l);
    await save();
    notifyListeners();
    return l;
  }

  Future<void> deleteList(String id) async {
    lists.removeWhere((l) => l.id == id);
    for (final t in tasks) {
      if (t.listId == id) t.listId = 'tasks';
    }
    await save();
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    await save();
    notifyListeners();
  }

  Future<void> setAccent(int c) async {
    accent = c;
    await save();
    notifyListeners();
  }
}
