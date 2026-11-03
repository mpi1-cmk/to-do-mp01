import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

class TaskDetail extends StatefulWidget {
  const TaskDetail({super.key, required this.taskId, required this.onClose});

  final String taskId;
  final VoidCallback onClose;

  @override
  State<TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends State<TaskDetail> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _step = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TaskDetail old) {
    super.didUpdateWidget(old);
    if (old.taskId != widget.taskId) _load();
  }

  void _load() {
    final t = store.byId(widget.taskId);
    _title.text = t?.title ?? '';
    _notes.text = t?.notes ?? '';
    _step.clear();
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _step.dispose();
    super.dispose();
  }

  Future<void> _pickDue(Task t) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: t.dueAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (d == null || !mounted) return;
    final tm = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(t.dueAt ?? now.add(const Duration(minutes: 5))),
    );
    if (tm == null) return;
    t.dueAt = DateTime(d.year, d.month, d.day, tm.hour, tm.minute);
    t.snoozedUntil = null;
    await store.changed(t);
  }

  Widget _section(String label, Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );

  Widget _stepRow(Task t, int i) {
    final s = t.steps[i];
    return ListTile(
      dense: true,
      leading: Checkbox(
        value: s.done,
        shape: const CircleBorder(),
        onChanged: (v) {
          s.done = v ?? false;
          store.changed(t);
        },
      ),
      title: Text(
        s.title,
        style: s.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        onPressed: () {
          t.steps.removeAt(i);
          store.changed(t);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final t = store.byId(widget.taskId);
        if (t == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onClose();
          });
          return const SizedBox.shrink();
        }
        final scheme = Theme.of(context).colorScheme;
        final due = t.dueAt;

        return Material(
          color: scheme.surfaceContainerLow,
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  tooltip: 'إغلاق',
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Row(children: [
                          Checkbox(
                            value: t.done,
                            shape: const CircleBorder(),
                            onChanged: (_) => store.toggleDone(t),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _title,
                              style: Theme.of(context).textTheme.titleMedium,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'عنوان المهمة',
                              ),
                              onChanged: (v) {
                                t.title = v;
                                store.saveSoon(t);
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(t.important ? Icons.star : Icons.star_border),
                            onPressed: () {
                              t.important = !t.important;
                              store.changed(t);
                            },
                          ),
                        ]),
                      ),
                    ),
                    Card(
                      child: Column(children: [
                        for (var i = 0; i < t.steps.length; i++) _stepRow(t, i),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: _step,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.add),
                              hintText: 'خطوة جديدة',
                              border: InputBorder.none,
                            ),
                            onSubmitted: (v) {
                              final s = v.trim();
                              if (s.isEmpty) return;
                              t.steps.add(SubStep(s));
                              _step.clear();
                              store.changed(t);
                            },
                          ),
                        ),
                      ]),
                    ),
                    Card(
                      child: Column(children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.wb_sunny_outlined),
                          title: const Text('أضف إلى يومي'),
                          value: t.myDay,
                          onChanged: (v) {
                            t.myDay = v;
                            store.changed(t);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.alarm),
                          title: const Text('التذكير والموعد'),
                          subtitle: Text(due == null ? 'لم يُحدَّد' : fmtDue(due)),
                          trailing: due == null
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    t.dueAt = null;
                                    t.snoozedUntil = null;
                                    t.repeat = Repeat.none;
                                    store.changed(t);
                                  },
                                ),
                          onTap: () => _pickDue(t),
                        ),
                      ]),
                    ),
                    Card(
                      child: Column(children: [
                        _section(
                          'التكرار',
                          Wrap(spacing: 8, children: [
                            for (final r in Repeat.values)
                              ChoiceChip(
                                label: Text(r.label),
                                selected: t.repeat == r,
                                onSelected: due == null
                                    ? null
                                    : (_) {
                                        t.repeat = r;
                                        store.changed(t);
                                      },
                              ),
                          ]),
                        ),
                        _section(
                          'الأولوية',
                          Wrap(spacing: 8, children: [
                            for (final p in Priority.values)
                              ChoiceChip(
                                label: Text(p.label),
                                selected: t.priority == p,
                                onSelected: (_) {
                                  t.priority = p;
                                  store.changed(t);
                                },
                              ),
                          ]),
                        ),
                        _section(
                          'القائمة',
                          DropdownButton<String>(
                            isExpanded: true,
                            value: store.lists.any((l) => l.id == t.listId) ? t.listId : 'tasks',
                            items: [
                              const DropdownMenuItem(value: 'tasks', child: Text('المهام')),
                              for (final l in store.lists)
                                DropdownMenuItem(value: l.id, child: Text(l.name)),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              t.listId = v;
                              store.changed(t);
                            },
                          ),
                        ),
                      ]),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          controller: _notes,
                          minLines: 3,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            hintText: 'ملاحظات',
                            border: InputBorder.none,
                          ),
                          onChanged: (v) {
                            t.notes = v;
                            store.saveSoon(t);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: scheme.error),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('حذف المهمة'),
                      onPressed: () async {
                        await store.deleteTask(t);
                        widget.onClose();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
