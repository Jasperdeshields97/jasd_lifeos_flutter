import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'stats_manager.dart';

class DailyTasksScreen extends StatefulWidget {
  const DailyTasksScreen({Key? key}) : super(key: key);

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  final TextEditingController _taskController = TextEditingController();
  List<Map<String, dynamic>> _allTasks = [];
  String _tab = 'Today';
  int _todaysDoneCount = 0;
  static const int _dailyGoal = 5;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    await StatsManager.rolloverTasksIfNeeded();
    await _loadTasks();
  }

  Future<void> _loadTasks() async {
    // Load the full task list from prefs
    _allTasks = await StatsManager.getTodayTasks();
    // Count done for today
    final now = DateTime.now();
    _todaysDoneCount = _allTasks.where((t) {
      final due = DateTime.tryParse(t['date'] ?? '') ?? now;
      return _isSameDay(due, now) &&
          (t['someday'] != true) &&
          (t['done'] == true);
    }).length;
    setState(() {});
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _saveAllTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _allTasks.map((t) => jsonEncode(t)).toList();
    await prefs.setStringList(StatsManager.taskKey, raw);
  }

  Future<void> _addTask() async {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;
    final newTask = {
      'title': text,
      'done': false,
      'date': DateTime.now().toIso8601String(),
      'priority': 'Normal',
      'someday': false,
      'repeat': false,
    };
    _allTasks.add(newTask);
    await _saveAllTasks();
    await StatsManager.recordTask(DateTime.now());
    _taskController.clear();
    await _loadTasks();
  }

  Future<void> _toggleDone(int index) async {
    // index in filtered list, find actual index in _allTasks
    final filtered = _filteredTasks();
    final task = filtered[index];
    final idx = _allTasks.indexOf(task);
    final wasDone = _allTasks[idx]['done'] == true;
    _allTasks[idx]['done'] = !wasDone;
    if (!wasDone) {
      await StatsManager.recordTask(DateTime.now());
    } else {
      await StatsManager.removeRecordedTask();
    }
    await _saveAllTasks();
    await _loadTasks();
  }

  List<Map<String, dynamic>> _filteredTasks() {
    final now = DateTime.now();
    if (_tab == 'Today') {
      return _allTasks.where((t) {
        final due = DateTime.tryParse(t['date'] ?? '') ?? now;
        return _isSameDay(due, now) && t['someday'] != true;
      }).toList();
    } else if (_tab == 'Upcoming') {
      return _allTasks.where((t) {
        final due = DateTime.tryParse(t['date'] ?? '') ?? now;
        return due.isAfter(now) && t['someday'] != true;
      }).toList();
    } else {
      // Someday
      return _allTasks.where((t) => t['someday'] == true).toList();
    }
  }

  Future<void> _editTask(int index) async {
    final filtered = _filteredTasks();
    final orig = Map<String, dynamic>.from(filtered[index]);
    final idx = _allTasks.indexOf(filtered[index]);

    final titleController = TextEditingController(text: orig['title'] ?? '');
    DateTime dueDate =
        DateTime.tryParse(orig['date'] ?? '') ?? DateTime.now();
    bool someday = orig['someday'] == true;
    bool repeat = orig['repeat'] == true;
    String priority = orig['priority']?.toString() ?? 'Normal';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Task'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Priority:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: priority,
                items: ['High', 'Normal', 'Low']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => priority = v);
                },
              ),
            ]),
            Row(children: [
              Checkbox(
                value: someday,
                onChanged: (v) => setState(() => someday = v ?? false),
              ),
              const Text('Someday'),
              const SizedBox(width: 16),
              Checkbox(
                value: repeat,
                onChanged: (v) => setState(() => repeat = v ?? false),
              ),
              const Text('Repeat Daily'),
            ]),
            Row(children: [
              const Text('Due Date:'),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: dueDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => dueDate = picked);
                  }
                },
                child: Text(DateFormat.yMd().format(dueDate)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton(
                onPressed: () async {
                  _allTasks.removeAt(idx);
                  await _saveAllTasks();
                  Navigator.pop(ctx);
                  await _loadTasks();
                },
                child:
                    const Text('Delete Task', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final updated = {
                    'title': titleController.text.trim(),
                    'done': orig['done'] == true,
                    'date': dueDate.toIso8601String(),
                    'priority': priority,
                    'someday': someday,
                    'repeat': repeat,
                  };
                  _allTasks[idx] = updated;
                  await _saveAllTasks();
                  Navigator.pop(ctx);
                  await _loadTasks();
                },
                child: const Text('Save'),
              ),
            ]),
            const SizedBox(height: 16),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_todaysDoneCount / _dailyGoal).clamp(0.0, 1.0);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Daily Tasks'),
          bottom: TabBar(
            onTap: (i) {
              _tab = ['Today', 'Upcoming', 'Someday'][i];
              _loadTasks();
            },
            tabs: const [
              Tab(text: 'Today'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Someday'),
            ],
          ),
        ),
        body: Column(children: [
          // Progress + Add UI only for Today
          if (_tab == 'Today')
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade300,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$_todaysDoneCount/$_dailyGoal'),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _taskController,
                      decoration: const InputDecoration(
                        hintText: 'Add new task',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _addTask, child: const Text('Add')),
                ]),
              ]),
            ),

          // Task List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTasks().length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (_, i) {
                final t = _filteredTasks()[i];
                final p = t['priority']?.toString() ?? 'Normal';
                final color = p == 'High'
                    ? Colors.red
                    : p == 'Low'
                        ? Colors.green
                        : Colors.grey;
                final done = t['done'] == true;
                final due = DateTime.tryParse(t['date'] ?? '') ?? DateTime.now();

                return GestureDetector(
                  onTap: () => _editTask(i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Container(width: 6, height: 60, color: color),
                      Expanded(
                        child: ListTile(
                          leading: IconButton(
                            icon: Icon(
                              done
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: done ? Colors.blue : Colors.grey,
                            ),
                            onPressed: () => _toggleDone(i),
                          ),
                          title: Text(
                            t['title']?.toString() ?? '',
                            style: TextStyle(
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Priority: $p'),
                              Text(
                                  'Due: ${due.month}/${due.day}/${due.year}'),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}





