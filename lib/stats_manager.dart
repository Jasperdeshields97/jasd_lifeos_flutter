import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StatsManager {
  // -------------------- Keys --------------------
  static const String taskKey = 'task_list';
  static const String archivedTaskKey = 'archived_tasks';
  static const String lastRolloverKey = 'last_rollover_date';

  static const String taskLogKey = 'task_logs';
  static const String workoutLogKey = 'workout_logs';

  static const String dailyGoalKey = 'daily_task_goal';
  static const String weeklyGoalKey = 'weekly_workout_goal';

  static const String activeGoalKey = 'active_goals';
  static const String totalGoalKey = 'total_goals';

  static const String goalsKey = 'big_goals';

  static const int defaultDailyTaskGoal = 5;
  static const int defaultWeeklyWorkoutGoal = 7;

  // -------------------- Goals --------------------

  static Future<void> updateGoalStats(List<Map<String, dynamic>> goals) async {
    final prefs = await SharedPreferences.getInstance();
    final total = goals.length;
    final active = goals.where((g) => g['active'] == true).length;
    await prefs.setInt(totalGoalKey, total);
    await prefs.setInt(activeGoalKey, active);
  }

  static Future<int> getTotalGoals() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(totalGoalKey) ?? 0;
  }

  static Future<int> getActiveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(activeGoalKey) ?? 0;
  }

  static Future<List<Map<String, dynamic>>> getGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(goalsKey);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.cast<Map<String, dynamic>>();
  }

  // -------------------- Daily/Weekly Goals --------------------

  static Future<int> getDailyTaskGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(dailyGoalKey) ?? defaultDailyTaskGoal;
  }

  static Future<void> setDailyTaskGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(dailyGoalKey, goal);
  }

  static Future<int> getWeeklyWorkoutGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(weeklyGoalKey) ?? defaultWeeklyWorkoutGoal;
  }

  static Future<void> setWeeklyWorkoutGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(weeklyGoalKey, goal);
  }

  // -------------------- Task Tracking --------------------

  static Future<void> recordTask(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList(taskLogKey) ?? [];
    logs.add(jsonEncode({'date': date.toIso8601String()}));
    await prefs.setStringList(taskLogKey, logs);
  }

  static Future<void> removeRecordedTask() async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList(taskLogKey) ?? [];
    if (logs.isNotEmpty) {
      logs.removeLast();
      await prefs.setStringList(taskLogKey, logs);
    }
  }

  static Future<List<Map<String, dynamic>>> getTodayTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(taskKey) ?? [];
    return raw.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
  }

  static Future<void> resetTaskLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(taskLogKey);
  }

  // -------------------- Workout Tracking --------------------

  static Future<void> recordWorkout(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList(workoutLogKey) ?? [];
    final entry = jsonEncode({'date': date.toIso8601String()});
    logs.add(entry);
    await prefs.setStringList(workoutLogKey, logs);
  }

  static Future<int> getWeeklyWorkoutCount() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(workoutLogKey) ?? [];
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return entries
        .map((raw) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            return DateTime.parse(map['date']);
          } catch (_) {
            return null;
          }
        })
        .where((dt) => dt != null && dt.isAfter(weekAgo))
        .length;
  }

  static Future<List<int>> get30DayWorkoutCount() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(workoutLogKey) ?? [];
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final grouped = List<int>.filled(4, 0);
    for (final raw in entries) {
      try {
        final entry = jsonDecode(raw) as Map<String, dynamic>;
        final dt = DateTime.parse(entry['date']);
        if (dt.isAfter(start)) {
          final weekIndex = ((now.difference(dt).inDays) / 7).floor();
          if (weekIndex >= 0 && weekIndex < 4) grouped[3 - weekIndex]++;
        }
      } catch (_) {}
    }
    return grouped;
  }

  static Future<void> resetWorkoutLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(workoutLogKey);
  }

  // -------------------- Rollover & Archive --------------------

  /// Move uncompleted tasks from yesterday into archive once per day.
  static Future<void> rolloverTasksIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(lastRolloverKey);
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    if (last == todayStr) return;

    final raw = prefs.getStringList(taskKey) ?? [];
    final tasks = raw
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    // Identify uncompleted yesterday tasks
    final toArchive = tasks.where((t) {
      final dt = DateTime.parse(t['date']);
      return dt.year == yesterday.year &&
             dt.month == yesterday.month &&
             dt.day == yesterday.day &&
             t['done'] != true;
    }).toList();

    // Append to archive
    final archivedRaw = prefs.getStringList(archivedTaskKey) ?? [];
    final updatedArchive = [
      ...archivedRaw,
      ...toArchive.map(jsonEncode),
    ];
    await prefs.setStringList(archivedTaskKey, updatedArchive);

    // Keep remaining tasks
    final remaining = tasks
        .where((t) => !toArchive.contains(t))
        .map(jsonEncode)
        .toList();
    await prefs.setStringList(taskKey, remaining);

    // Mark rollover date
    await prefs.setString(lastRolloverKey, todayStr);
  }

  /// Get archived tasks list.
  static Future<List<Map<String, dynamic>>> getArchivedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(archivedTaskKey) ?? [];
    return raw.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
  }

  static get7DayTaskAverage() {}

  static getWeeklyTaskCount() {}

    /// Return how many tasks were completed today.
  static Future<int> getTodayTaskCount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(taskKey) ?? [];
    final today = DateTime.now();
    return raw.map((e) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        return DateTime.parse(m['date'] as String);
      } catch (_) {
        return null;
      }
    }).where((dt) =>
        dt != null &&
        dt.year == today.year &&
        dt.month == today.month &&
        dt.day == today.day).length;
  }
  /// Returns a list of 7 ints: [count 6 days ago, …, count yesterday, count today]
static Future<List<int>> getLast7DayTaskCounts() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(taskKey) ?? [];
  final now = DateTime.now();
  // Initialize zero counts
  List<int> counts = List.filled(7, 0);
  for (final entry in raw) {
    try {
      final m = jsonDecode(entry) as Map<String, dynamic>;
      final dt = DateTime.parse(m['date'] as String);
      final diff = now.difference(dt).inDays;
      if (diff >= 0 && diff < 7) {
        // index 6 = today, 0 = six days ago
        counts[6 - diff]++;
      }
    } catch (_) {}
  }
  return counts;
}
}





