
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ToDoListApp());
}

class Task {
  String id;
  String title;
  String description;
  DateTime dueDate;
  bool highPriority;
  bool completed;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.highPriority = false,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dueDate': dueDate.toIso8601String(),
        'highPriority': highPriority,
        'completed': completed,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        description: (j['description'] ?? '') as String,
        dueDate: DateTime.parse(j['dueDate'] as String),
        highPriority: (j['highPriority'] ?? false) as bool,
        completed: (j['completed'] ?? false) as bool,
      );
}

class ToDoListApp extends StatelessWidget {
  const ToDoListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TO DO LIST',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF03152D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2787FF),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  final List<Task> tasks = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('tasks') ?? [];
    tasks
      ..clear()
      ..addAll(raw.map((e) => Task.fromJson(jsonDecode(e))));
    setState(() => loading = false);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('tasks', tasks.map((t) => jsonEncode(t.toJson())).toList());
  }

  void _addTask() => _showTaskEditor();

  Future<void> _showTaskEditor({Task? task}) async {
    final title = TextEditingController(text: task?.title ?? '');
    final description = TextEditingController(text: task?.description ?? '');
    DateTime due = task?.dueDate ?? DateTime.now();
    bool high = task?.highPriority ?? false;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071A35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48, height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF5576E8),
                      child: Icon(task == null ? Icons.task_alt : Icons.edit,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text(task == null ? 'Add New Task' : 'Edit Task',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 22),
                  const Text('Task Name *'),
                  const SizedBox(height: 8),
                  _field(title, task == null ? 'e.g. Finish project report' : null),
                  const SizedBox(height: 15),
                  const Text('Description (optional)'),
                  const SizedBox(height: 8),
                  _field(description, 'Add more details...', maxLines: 3),
                  const SizedBox(height: 15),
                  const Text('Due Date'),
                  const SizedBox(height: 8),
                  _tapBox(
                    icon: Icons.calendar_month,
                    text: _date(due),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: due,
                        builder: (c, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(primary: Color(0xFF2D8CFF)),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setSheet(() => due = picked);
                    },
                  ),
                  const SizedBox(height: 15),
                  const Text('Priority'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _priorityButton('High', true, high, () => setSheet(() => high = true))),
                    const SizedBox(width: 10),
                    Expanded(child: _priorityButton('Low', false, !high, () => setSheet(() => high = false))),
                  ]),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (title.text.trim().isEmpty) return;
                        Navigator.pop(ctx, {
                          'title': title.text.trim(),
                          'description': description.text.trim(),
                          'due': due,
                          'high': high,
                        });
                      },
                      icon: Icon(task == null ? Icons.add : Icons.save),
                      label: Text(task == null ? 'Add Task' : 'Update Task'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2585FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == null) return;
    setState(() {
      if (task == null) {
        tasks.insert(0, Task(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: result['title'],
          description: result['description'],
          dueDate: result['due'],
          highPriority: result['high'],
        ));
      } else {
        task.title = result['title'];
        task.description = result['description'];
        task.dueDate = result['due'];
        task.highPriority = result['high'];
      }
    });
    await _save();
  }

  Widget _field(TextEditingController c, String? hint, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF16345D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _tapBox({required IconData icon, required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF16345D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          const Icon(Icons.chevron_right, color: Colors.white54),
        ]),
      ),
    );
  }

  Widget _priorityButton(String label, bool isHigh, bool selected, VoidCallback onTap) {
    final color = isHigh ? const Color(0xFFFF3D78) : const Color(0xFF2389FF);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(.22) : const Color(0xFF16345D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isHigh ? Icons.priority_high : Icons.download, color: color),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: selected ? color : Colors.white70)),
        ]),
      ),
    );
  }

  String _date(DateTime d) => '${_month(d.month)} ${d.day}, ${d.year}';
  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  void _toggle(Task t) {
    setState(() => t.completed = !t.completed);
    _save();
  }

  void _delete(Task t) {
    setState(() => tasks.remove(t));
    _save();
  }

  void _options(Task t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF071A35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Task Options', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ListTile(leading: const Icon(Icons.edit), title: const Text('Edit'),
              onTap: () { Navigator.pop(ctx); _showTaskEditor(task: t); }),
            ListTile(leading: const Icon(Icons.flag), title: const Text('Change Priority'),
              onTap: () { Navigator.pop(ctx); setState(() => t.highPriority = !t.highPriority); _save(); }),
            ListTile(leading: const Icon(Icons.delete, color: Colors.pink), title: const Text('Delete'),
              onTap: () { Navigator.pop(ctx); _delete(t); }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final pages = [
      _home(),
      _stats(),
      _settings(),
    ];

    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF06182F),
        indicatorColor: const Color(0xFF173E73),
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton(
              onPressed: _addTask,
              backgroundColor: const Color(0xFF2585FF),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _top({bool back = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 48, 18, 8),
      child: Row(children: [
        if (back) const Icon(Icons.arrow_back) else Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: const Color(0xFF2D82FF), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.check, color: Colors.white, size: 25),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('To Do List', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          Text('Small steps every day', style: TextStyle(fontSize: 11, color: Colors.white60)),
        ])),
        const Icon(Icons.settings_outlined),
      ]),
    );
  }

  Widget _home() {
    final completed = tasks.where((t) => t.completed).length;
    final left = tasks.length - completed;
    final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF061B3A), Color(0xFF03142A), Color(0xFF071D3B)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _top()),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: const Text('Small steps every day\nlead to big results.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35)),
            )),
            SliverToBoxAdapter(child: _summary(left, completed, progress)),
            SliverToBoxAdapter(child: _filters()),
            if (tasks.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _empty())
            else
              SliverList(delegate: SliverChildBuilderDelegate(
                (ctx, i) => _taskCard(tasks[i]),
                childCount: tasks.length,
              )),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _summary(int left, int completed, double progress) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2345).withOpacity(.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        _stat('Tasks Left', '$left', Icons.assignment_outlined, const Color(0xFF39A5FF)),
        _stat('Completed', '$completed', Icons.check_circle_outline, const Color(0xFF36D99B)),
        Expanded(child: Column(children: [
          SizedBox(width: 60, height: 60, child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(value: progress, strokeWidth: 6,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF36D99B))),
            Text('${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          ])),
          const SizedBox(height: 5),
          const Text('Progress', style: TextStyle(fontSize: 11, color: Colors.white70)),
        ])),
      ]),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) => Expanded(
    child: Column(children: [
      Icon(icon, color: color),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
    ]),
  );

  Widget _filters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(children: [
        _chip('All', true, Icons.tune),
        const SizedBox(width: 8), _chip('Today', false, null),
        const SizedBox(width: 8), _chip('High Priority', false, Icons.priority_high),
        const SizedBox(width: 8), _chip('Completed', false, Icons.check_circle),
      ]),
    );
  }

  Widget _chip(String label, bool selected, IconData? icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: selected ? const Color(0xFF328BFF) : const Color(0xFF112D50),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(children: [
      if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 4)],
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _taskCard(Task t) {
    final accent = t.highPriority ? const Color(0xFFFF3D78) : const Color(0xFF248BFF);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 5, 20, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2446),
        borderRadius: BorderRadius.circular(15),
        border: Border(left: BorderSide(color: accent, width: 5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: Checkbox(
          value: t.completed,
          onChanged: (_) => _toggle(t),
          activeColor: const Color(0xFF36D99B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        title: Text(t.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: t.completed ? TextDecoration.lineThrough : null,
            color: t.completed ? Colors.white54 : Colors.white,
          )),
        subtitle: Row(children: [
          const Icon(Icons.calendar_month, size: 13, color: Colors.white54),
          const SizedBox(width: 4),
          Text(_date(t.dueDate), style: const TextStyle(fontSize: 11, color: Colors.white54)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(.16), borderRadius: BorderRadius.circular(12)),
            child: Text(t.highPriority ? 'High' : 'Low',
              style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
        trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _options(t)),
        onTap: () => _details(t),
      ),
    );
  }

  void _details(Task t) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFF071A35),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _detailBox(Icons.calendar_month, 'Due Date', _date(t.dueDate)),
          _detailBox(Icons.description_outlined, 'Description', t.description.isEmpty ? 'No description' : t.description),
          _detailBox(Icons.circle_outlined, 'Status', t.completed ? 'Completed' : 'Not Completed'),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
            onPressed: () { Navigator.pop(ctx); _toggle(t); },
            icon: Icon(t.completed ? Icons.undo : Icons.check),
            label: Text(t.completed ? 'Mark as Not Completed' : 'Mark as Completed'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2585FF)),
          )),
        ]),
      ),
    );
  }

  Widget _detailBox(IconData icon, String title, String value) => Container(
    width: double.infinity, margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF102B50), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF6FB5FF)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ])),
    ]),
  );

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 150, height: 150,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF102E56)),
          child: const Icon(Icons.nightlight_round, size: 72, color: Color(0xFF76B8FF))),
        const SizedBox(height: 20),
        const Text('No tasks yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        const Text('Add something you want to accomplish.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          onPressed: _addTask,
          icon: const Icon(Icons.add),
          label: const Text('Add Task'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2585FF)),
        ),
      ]),
    ),
  );

  Widget _stats() {
    final total = tasks.length;
    final done = tasks.where((t) => t.completed).length;
    final high = tasks.where((t) => t.highPriority).length;
    final low = total - high;
    final progress = total == 0 ? 0.0 : done / total;

    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 30, 20, 30), children: [
        const Text('Your Progress', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: const Color(0xFF0B2446), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            SizedBox(width: 125, height: 125, child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(value: progress, strokeWidth: 12,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF36D99B))),
              Text('${(progress * 100).round()}%\nCompleted',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ])),
            const SizedBox(width: 22),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _legend(const Color(0xFF2585FF), '$total', 'Tasks Total'),
              _legend(const Color(0xFF36D99B), '$done', 'Completed'),
              _legend(Colors.white70, '${total - done}', 'Tasks Left'),
            ]),
          ]),
        ),
        const SizedBox(height: 22),
        const Text('Priority Breakdown', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _priorityCard('High Priority', '$high', const Color(0xFFFF3D78))),
          const SizedBox(width: 12),
          Expanded(child: _priorityCard('Low Priority', '$low', const Color(0xFF2585FF))),
        ]),
        const SizedBox(height: 25),
        const Text('This Week', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          height: 180,
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
          decoration: BoxDecoration(color: const Color(0xFF0B2446), borderRadius: BorderRadius.circular(18)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final h = total == 0 ? 12.0 : (15 + ((i + done) % 4) * 20).toDouble();
              return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(width: 22, height: h, decoration: BoxDecoration(
                  color: const Color(0xFF278BFF), borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 8),
                Text(['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][i],
                  style: const TextStyle(fontSize: 9, color: Colors.white60)),
              ]);
            }),
          ),
        ),
      ]),
    );
  }

  Widget _legend(Color c, String n, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text('$n $label', style: const TextStyle(fontSize: 11)),
    ]),
  );

  Widget _priorityCard(String label, String count, Color color) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.priority_high, color: color),
      const SizedBox(height: 8),
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      Text(count, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      const Text('tasks', style: TextStyle(color: Colors.white60, fontSize: 11)),
    ]),
  );

  Widget _settings() => SafeArea(
    child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Settings', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
      const SizedBox(height: 18),
      Card(
        color: const Color(0xFF0B2446),
        child: Column(children: [
          const ListTile(
            leading: Icon(Icons.dark_mode),
            title: Text('Dark Mode'),
            subtitle: Text('The app uses a dark theme'),
            trailing: Icon(Icons.check_circle, color: Color(0xFF36D99B)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Clear Completed Tasks'),
            onTap: () async {
              setState(() => tasks.removeWhere((t) => t.completed));
              await _save();
            },
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset All Tasks'),
            onTap: () async {
              setState(() => tasks.clear());
              await _save();
            },
          ),
        ]),
      ),
    ]),
  );
}
