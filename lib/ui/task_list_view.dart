import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

class TaskListView extends StatefulWidget {
  const TaskListView({
    super.key,
    required this.listId,
    required this.selectedId,
    required this.onOpen,
  });

  final String listId;
  final String? selectedId;
  final ValueChanged<String> onOpen;

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  final _c = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add(String v) async {
    final s = v.trim();
    if (s.isEmpty) return;
    _c.clear();
    _focus.requestFocus();
    await store.addTask(s, widget.listId);
  }

  Widget? _meta(BuildContext context, Task t) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall;
    final items = <Widget>[];

    if (t.steps.isNotEmpty) {
      final done = t.steps.where((s) => s.done).length;
      items.add(Text('$done/${t.steps.length}', style: style));
    }
    final due = t.dueAt;
    if (due != null) {
      final overdue = !t.done && due.isBefore(DateTime.now());
      final color = overdue ? scheme.error : null;
      items.add(Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.alarm, size: 14, color: color),
        const SizedBox(width: 4),
        Text(fmtDue(due), style: style?.copyWith(color: color)),
      ]));
    }
    if (t.repeat != Repeat.none) items.add(const Icon(Icons.repeat, size: 14));
    if (t.priority == Priority.high) {
      items.add(Icon(Icons.priority_high, size: 14, color: scheme.error));
    }
    if (items.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final tasks = store.view(widget.listId);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _c,
                focusNode: _focus,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'إضافة مهمة',
                  prefixIcon: const Icon(Icons.add),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: _add,
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? const Center(child: Text('لا توجد مهام هنا'))
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, i) {
                        final t = tasks[i];
                        return ListTile(
                          selected: t.id == widget.selectedId,
                          selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.4),
                          leading: Checkbox(
                            value: t.done,
                            shape: const CircleBorder(),
                            onChanged: (_) => store.toggleDone(t),
                          ),
                          title: Text(
                            t.title,
                            style: t.done
                                ? const TextStyle(decoration: TextDecoration.lineThrough)
                                : null,
                          ),
                          subtitle: _meta(context, t),
                          trailing: IconButton(
                            icon: Icon(t.important ? Icons.star : Icons.star_border),
                            onPressed: () {
                              t.important = !t.important;
                              store.changed(t);
                            },
                          ),
                          onTap: () => widget.onOpen(t.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
