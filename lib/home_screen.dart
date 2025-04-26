import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily_tasks_screen.dart';
import 'add_workout_screen.dart';
import 'settings_screen.dart';
import 'analytics_screen.dart';
import 'vision_screen.dart';
import 'pulse_check_screen.dart';
import 'services/pulse_service.dart';
import 'models/pulse_entry.dart';
import 'stats_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tasksToday = 0;               // ← today’s count
  int _workoutsThisWeek = 0;
  PulseEntry? _todayPulse;
  List<Map<String, dynamic>> _goals = [];
  int _activeGoalLimit = 3;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    int tasks = 0, workouts = 0;
    PulseEntry? pulse;
    List<Map<String, dynamic>> goals = [];
    int limit = _activeGoalLimit;

    try {
      // NEW: fetch today’s completed tasks
      tasks = await StatsManager.getTodayTaskCount();
    } catch (_) {}
    try {
      workouts = await StatsManager.getWeeklyWorkoutCount();
    } catch (_) {}
    try {
      pulse = await PulseService.getTodayEntry();
    } catch (_) {}
    try {
      goals = await StatsManager.getGoals();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      limit = prefs.getInt('active_goal_limit') ?? limit;
    } catch (_) {}

    setState(() {
      _tasksToday = tasks;
      _workoutsThisWeek = workouts;
      _todayPulse = pulse;
      _goals = goals;
      _activeGoalLimit = limit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int dailyGoal = StatsManager.defaultDailyTaskGoal;
    final int workoutGoal = StatsManager.defaultWeeklyWorkoutGoal;
    const int pulseGoal = 5;

    // compute percents
    final double taskPercent =
        dailyGoal > 0 ? _tasksToday / dailyGoal : 0;
    final double workoutPercent =
        workoutGoal > 0 ? _workoutsThisWeek / workoutGoal : 0;
    final double pulsePercent = _todayPulse != null
        ? (_todayPulse!.pulseRating / pulseGoal)
        : 0;

    // filter & sort active goals by dueDate
    final activeGoals = _goals
        .where((g) => g['active'] == true && g['dueDate'] != null)
        .toList()
          ..sort((a, b) {
            final da = DateTime.tryParse(a['dueDate'] ?? '') ??
                DateTime(2100);
            final db = DateTime.tryParse(b['dueDate'] ?? '') ??
                DateTime(2100);
            return da.compareTo(db);
          });
    final limitedGoals =
        activeGoals.take(_activeGoalLimit).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('JASD LifeOS'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => _loadStats()),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
            ).then((_) => _loadStats()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Metrics Row ───────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MetricCircle(
                  size: 120,
                  percent: taskPercent,
                  icon: Icons.task_alt,
                  color: Colors.deepPurple,
                  label: 'Tasks',
                  value: '$_tasksToday/$dailyGoal',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DailyTasksScreen()),
                  ).then((_) => _loadStats()),
                ),
                _MetricCircle(
                  size: 120,
                  percent: workoutPercent,
                  icon: Icons.fitness_center,
                  color: Colors.green,
                  label: 'Workouts',
                  value: '$_workoutsThisWeek/$workoutGoal',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddWorkoutScreen()),
                  ).then((_) => _loadStats()),
                ),
                _MetricCircle(
                  size: 120,
                  percent: pulsePercent,
                  icon: Icons.favorite,
                  color: Colors.pinkAccent,
                  label: 'Pulse',
                  value: _todayPulse != null
                      ? '${_todayPulse!.pulseRating}/$pulseGoal'
                      : '0/$pulseGoal',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PulseCheckScreen()),
                  ).then((_) => _loadStats()),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Goals Overview ────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber),
                      SizedBox(width: 8),
                      Text('Goals Overview',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_goals.length} total • ${activeGoals.length} active',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  if (limitedGoals.isEmpty)
                    const Text('No active goals'),
                  ...limitedGoals.map((g) {
                    final due =
                        DateTime.tryParse(g['dueDate'] ?? '');
                    final daysLeft = due != null
                        ? due.difference(DateTime.now()).inDays
                        : null;
                    final benefit = g['benefit'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '• $benefit${daysLeft != null ? ' ⏳ $daysLeft days' : ''}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── Navigation Cards ──────────────────
            _NavCard(
              icon: Icons.edit,
              text: 'Daily Tasks',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DailyTasksScreen()),
              ).then((_) => _loadStats()),
            ),
            const SizedBox(height: 12),
            _NavCard(
              icon: Icons.fitness_center,
              text: 'Workout Log',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddWorkoutScreen()),
              ).then((_) => _loadStats()),
            ),
            const SizedBox(height: 12),
            _NavCard(
              icon: Icons.lightbulb,
              text: 'Vision & Big Goals',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const VisionScreen()),
              ).then((_) => _loadStats()),
            ),
            const SizedBox(height: 12),
            _NavCard(
              icon: Icons.favorite,
              text: 'Pulse Check',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PulseCheckScreen()),
              ).then((_) => _loadStats()),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 120px circle with an 8px-thick inset progress ring.
class _MetricCircle extends StatelessWidget {
  final double size;
  final double percent;
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _MetricCircle({
    Key? key,
    required this.size,
    required this.percent,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const double inset = 8;
    final inner = size - inset * 2;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          // outer
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
            ),
          ),
          // inset ring
          SizedBox(
            width: inner,
            height: inner,
            child: CircularProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              strokeWidth: 8,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          // icon + text
          Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: size * 0.2, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.15,
                    color: color)),
            Text(label,
                style:
                    TextStyle(fontSize: size * 0.1, color: Colors.black54)),
          ]),
        ]),
      ),
    );
  }
}

/// Simple card for navigation buttons.
class _NavCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _NavCard({
    Key? key,
    required this.icon,
    required this.text,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(text),
        onTap: onTap,
      ),
    );
  }
}

