import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'stats_manager.dart';
import 'services/pulse_service.dart';   // for clearing pulses

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Defaults from StatsManager & SharedPreferences
  int _dailyGoal = StatsManager.defaultDailyTaskGoal;
  int _weeklyGoal = StatsManager.defaultWeeklyWorkoutGoal;
  int _activeGoalLimit = 3;

  // NEW: Pulse goal
  int _pulseGoal = 5;  // you can load this from prefs if you want

  // Reminder toggle
  bool _pulseReminder = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyGoal = prefs.getInt('daily_task_goal') ??
          StatsManager.defaultDailyTaskGoal;
      _weeklyGoal = prefs.getInt('weekly_workout_goal') ??
          StatsManager.defaultWeeklyWorkoutGoal;
      _activeGoalLimit = prefs.getInt('active_goal_limit') ?? 3;
      _pulseGoal = prefs.getInt('pulse_goal') ?? 5;
      _pulseReminder = prefs.getBool('pulse_reminder') ?? false;
    });
  }

  Future<void> _saveInt(String key, int val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, val);
  }

  Future<void> _togglePulseReminder(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pulse_reminder', v);
    setState(() => _pulseReminder = v);
    // TODO: integrate notifications if needed
  }

  Future<void> _clearTasks() async {
    await StatsManager.resetTaskLogs();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All tasks cleared')));
  }

  Future<void> _clearWorkouts() async {
    await StatsManager.resetWorkoutLogs();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All workouts cleared')));
  }

  Future<void> _clearPulse() async {
    await PulseService.deleteAllEntries();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All pulse entries cleared')));
  }

  Future<void> _clearAllData() async {
    await StatsManager.resetTaskLogs();
    await StatsManager.resetWorkoutLogs();
    await PulseService.deleteAllEntries();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared')));
  }

  Future<bool?> _confirm(String title) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== Reminders =====
          const Text('Reminders',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SwitchListTile(
            title: const Text('Daily Pulse Reminder'),
            subtitle: const Text('Get a notification each morning'),
            value: _pulseReminder,
            onChanged: _togglePulseReminder,
          ),
          const Divider(height: 32),

          // ===== Defaults =====
          const Text('Defaults',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),

          // Tasks per day
          ListTile(
            title: const Text('Tasks per day'),
            subtitle: const Text('How many tasks to complete daily'),
            trailing: Text(
              '$_dailyGoal',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              final newVal =
                  await _editGoal(_dailyGoal, 'Tasks per day');
              if (newVal != null) {
                await _saveInt('daily_task_goal', newVal);
                setState(() => _dailyGoal = newVal);
              }
            },
          ),

          // Workouts per week
          ListTile(
            title: const Text('Workouts per week'),
            subtitle: const Text(
                'How many workouts to complete weekly'),
            trailing: Text(
              '$_weeklyGoal',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              final newVal =
                  await _editGoal(_weeklyGoal, 'Workouts per week');
              if (newVal != null) {
                await _saveInt('weekly_workout_goal', newVal);
                setState(() => _weeklyGoal = newVal);
              }
            },
          ),

          // Active Goal Limit
          ListTile(
            title: const Text('Active Goal Limit'),
            subtitle: const Text(
                'Max goals shown on dashboard/analytics'),
            trailing: DropdownButton<int>(
              value: _activeGoalLimit,
              underline: const SizedBox(),
              style: const TextStyle(
                  fontSize: 16, color: Colors.black),
              items: [1, 2, 3, 4, 5]
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text('$v'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  _saveInt('active_goal_limit', v);
                  setState(() => _activeGoalLimit = v);
                }
              },
            ),
          ),

          // Pulse goal
          ListTile(
            title: const Text('Pulse goal'),
            subtitle:
                const Text('Expected readiness score target'),
            trailing: Text(
              '$_pulseGoal',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              final newVal =
                  await _editGoal(_pulseGoal, 'Pulse goal');
              if (newVal != null) {
                await _saveInt('pulse_goal', newVal);
                setState(() => _pulseGoal = newVal);
              }
            },
          ),

          const Divider(height: 32),

          // ===== Data Management =====
          const Text('Data Management',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),

          ListTile(
            leading:
                const Icon(Icons.delete, color: Colors.redAccent),
            title: const Text('Clear all tasks',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              if (await _confirm('Delete all tasks?') == true) {
                await _clearTasks();
              }
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.delete, color: Colors.redAccent),
            title: const Text('Clear all workouts',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              if (await _confirm('Delete all workouts?') == true) {
                await _clearWorkouts();
              }
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.delete, color: Colors.redAccent),
            title: const Text('Clear all pulse entries',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              if (await _confirm('Delete all pulse entries?') ==
                  true) {
                await _clearPulse();
              }
            },
          ),

          const Divider(height: 32),

          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear ALL data',
                style: TextStyle(color: Colors.red)),
            onTap: () async {
              if (await _confirm('Delete ALL data?') == true) {
                await _clearAllData();
              }
            },
          ),

          const Divider(height: 32),

          // ===== About =====
          const ListTile(
            title: Text('App Version'),
            subtitle: Text('v1.0.0'),
          ),
        ],
      ),
    );
  }

  // Helper for editing any numeric goal
  Future<int?> _editGoal(int current, String label) async {
    final controller = TextEditingController(text: '$current');
    return showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                final v = int.tryParse(controller.text);
                if (v != null && v > 0) Navigator.pop(context, v);
              },
              child: const Text('Save')),
        ],
      ),
    );
  }
}


