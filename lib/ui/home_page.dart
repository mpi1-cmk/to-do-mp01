import 'package:flutter/material.dart';

import '../app_state.dart';
import 'settings_dialog.dart';
import 'task_detail.dart';
import 'task_list_view.dart';

class SmartList {
  const SmartList(this.id, this.name, this.icon);
  final String id;
  final String name;
  final IconData icon;
}

const smartLists = [
  SmartList('myday', 'يومي', Icons.wb_sunny_outlined),
  SmartList('important', 'مهم', Icons.star_border),
  SmartList('planned', 'مخطط لها', Icons.event_note_outlined),
  SmartList('tasks', 'المهام', Icons.home_outlined),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String listId = 'myday';
  String? selectedId;

  String _title() {
    for (final s in smartLists) {
      if (s.id == listId) return s.name;
    }
    for (final l in store.lists) {
      if (l.id == listId) return l.name;
    }
    return 'المهام';
  }

  void _openDetail(String id, bool wide) {
    setState(() => selectedId = id);
    if (!wide) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.85,
            child: TaskDetail(taskId: id, onClose: () => Navigator.pop(ctx)),
          ),
        ),
      ).whenComplete(() {
        if (mounted) setState(() => selectedId = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final side = Sidebar(
          current: listId,
          onSelect: (id) {
            setState(() {
              listId = id;
              selectedId = null;
            });
            if (!wide) Navigator.pop(context);
          },
        );
        final main = TaskListView(
          listId: listId,
          selectedId: selectedId,
          onOpen: (id) => _openDetail(id, wide),
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(_title()),
            actions: [
              IconButton(
                tooltip: 'الإعدادات',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => showSettings(context),
              ),
            ],
          ),
          drawer: wide ? null : Drawer(child: SafeArea(child: side)),
          body: wide
              ? Row(children: [
                  SizedBox(width: 260, child: side),
                  const VerticalDivider(width: 1),
                  Expanded(child: main),
                  if (selectedId != null) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 380,
                      child: TaskDetail(
                        taskId: selectedId!,
                        onClose: () => setState(() => selectedId = null),
                      ),
                    ),
                  ],
                ])
              : main,
        );
      },
    );
  }
}

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.current, required this.onSelect});

  final String current;
  final ValueChanged<String> onSelect;

  Future<void> _newList(BuildContext context) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('قائمة جديدة'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم القائمة'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('إنشاء')),
        ],
      ),
    );
    c.dispose();
    if (name != null && name.trim().isNotEmpty) {
      final l = await store.addList(name.trim());
      onSelect(l.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = scheme.primaryContainer.withValues(alpha: 0.5);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final s in smartLists)
          ListTile(
            leading: Icon(s.icon),
            title: Text(s.name),
            trailing: Text('${store.openCount(s.id)}'),
            selected: current == s.id,
            selectedTileColor: tint,
            onTap: () => onSelect(s.id),
          ),
        const Divider(),
        for (final l in store.lists)
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: Text(l.name),
            selected: current == l.id,
            selectedTileColor: tint,
            onTap: () => onSelect(l.id),
            trailing: PopupMenuButton<String>(
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'del', child: Text('حذف القائمة')),
              ],
              onSelected: (_) async {
                if (current == l.id) onSelect('tasks');
                await store.deleteList(l.id);
              },
            ),
          ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('قائمة جديدة'),
          onTap: () => _newList(context),
        ),
      ],
    );
  }
}
