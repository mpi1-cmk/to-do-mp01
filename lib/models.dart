enum Repeat {
  none('بدون تكرار'),
  daily('يومياً'),
  weekly('أسبوعياً'),
  monthly('شهرياً');

  const Repeat(this.label);
  final String label;
}

enum Priority {
  low('منخفضة'),
  normal('عادية'),
  high('عالية');

  const Priority(this.label);
  final String label;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// أول موعد بعد [after] (الافتراضي: بعد [from] مباشرة) حسب نوع التكرار.
DateTime nextOccurrence(DateTime from, Repeat r, {DateTime? after}) {
  if (r == Repeat.none) return from;
  final limit = after ?? from;
  var d = from;
  var guard = 0;
  do {
    d = _step(d, r);
    guard++;
  } while (!d.isAfter(limit) && guard < 5000);
  return d;
}

DateTime _step(DateTime d, Repeat r) {
  switch (r) {
    case Repeat.daily:
      return DateTime(d.year, d.month, d.day + 1, d.hour, d.minute);
    case Repeat.weekly:
      return DateTime(d.year, d.month, d.day + 7, d.hour, d.minute);
    case Repeat.monthly:
      final y = d.month == 12 ? d.year + 1 : d.year;
      final m = d.month == 12 ? 1 : d.month + 1;
      final last = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, d.day > last ? last : d.day, d.hour, d.minute);
    case Repeat.none:
      return d;
  }
}

String two(int n) => n.toString().padLeft(2, '0');
String fmtTime(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String fmtDue(DateTime d) {
  final now = DateTime.now();
  final today = DateTime.utc(now.year, now.month, now.day);
  final day = DateTime.utc(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  final time = fmtTime(d);
  if (diff == 0) return 'اليوم $time';
  if (diff == 1) return 'غداً $time';
  if (diff == -1) return 'أمس $time';
  return '${d.day}/${d.month}/${d.year} $time';
}

class SubStep {
  SubStep(this.title, {this.done = false});

  String title;
  bool done;

  Map<String, dynamic> toJson() => {'title': title, 'done': done};

  factory SubStep.fromJson(Map<String, dynamic> j) =>
      SubStep(j['title'] as String? ?? '', done: j['done'] as bool? ?? false);
}

class TaskList {
  TaskList(this.id, this.name);

  final String id;
  String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory TaskList.fromJson(Map<String, dynamic> j) =>
      TaskList(j['id'] as String, j['name'] as String? ?? '');
}

class Task {
  Task({
    required this.id,
    required this.alarmId,
    required this.title,
    this.notes = '',
    this.listId = 'tasks',
    this.important = false,
    this.myDay = false,
    this.done = false,
    this.dueAt,
    this.snoozedUntil,
    this.repeat = Repeat.none,
    this.priority = Priority.normal,
    List<SubStep>? steps,
  }) : steps = steps ?? [];

  final String id;
  final int alarmId; // رقم ثابت يُستعمل لجدولة التنبيه في النظام
  String title;
  String notes;
  String listId;
  bool important;
  bool myDay;
  bool done;
  DateTime? dueAt;
  DateTime? snoozedUntil;
  Repeat repeat;
  Priority priority;
  List<SubStep> steps;

  Map<String, dynamic> toJson() => {
        'id': id,
        'alarmId': alarmId,
        'title': title,
        'notes': notes,
        'listId': listId,
        'important': important,
        'myDay': myDay,
        'done': done,
        'dueAt': dueAt?.toIso8601String(),
        'snoozedUntil': snoozedUntil?.toIso8601String(),
        'repeat': repeat.name,
        'priority': priority.name,
        'steps': [for (final s in steps) s.toJson()],
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        alarmId: j['alarmId'] as int,
        title: j['title'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        listId: j['listId'] as String? ?? 'tasks',
        important: j['important'] as bool? ?? false,
        myDay: j['myDay'] as bool? ?? false,
        done: j['done'] as bool? ?? false,
        dueAt: DateTime.tryParse(j['dueAt'] as String? ?? ''),
        snoozedUntil: DateTime.tryParse(j['snoozedUntil'] as String? ?? ''),
        repeat: _enumByName(Repeat.values, j['repeat'], Repeat.none),
        priority: _enumByName(Priority.values, j['priority'], Priority.normal),
        steps: [
          for (final s in (j['steps'] as List? ?? const []))
            SubStep.fromJson(s as Map<String, dynamic>)
        ],
      );
}
