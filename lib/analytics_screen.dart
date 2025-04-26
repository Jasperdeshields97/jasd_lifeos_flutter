import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

import 'stats_manager.dart';
import 'services/pulse_service.dart';
import 'models/pulse_entry.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // --- Raw data fields ---
  double _taskAvg = 0;
  List<int> _last7TaskCounts = List.filled(7, 0);
  List<int> _workouts30Buckets = [0, 0, 0, 0];
  List<Map<String, dynamic>> _goals = [];
  PulseEntry? _todayPulse;
  List<PulseEntry> _pulseLast7 = [];
  int _pulseGoal = 5;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    // Defaults
    double taskAvg = 0;
    List<int> last7 = List.filled(7, 0);
    List<int> w30 = [0, 0, 0, 0];
    List<Map<String, dynamic>> goals = [];
    PulseEntry? pToday;
    List<PulseEntry> allP = [];
    int storedGoal = 5;

    // Safely load everything
    try {
      taskAvg = await StatsManager.get7DayTaskAverage();
    } catch (_) {}
    try {
      last7 = await StatsManager.getLast7DayTaskCounts();
    } catch (_) {}
    try {
      final lists = await StatsManager.get30DayWorkoutCount();
      w30 = lists;
    } catch (_) {}
    try {
      goals = await StatsManager.getGoals();
    } catch (_) {}
    try {
      pToday = await PulseService.getTodayEntry();
      allP = await PulseService.loadEntries();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      storedGoal = prefs.getInt('pulse_goal') ?? storedGoal;
    } catch (_) {}

    // Build sorted last7 pulses
    final cutoff = DateTime.now().subtract(const Duration(days: 6));
    final pulse7 = allP
        .where((e) => e.dateLogged.isAfter(cutoff))
        .toList()
          ..sort((a, b) => a.dateLogged.compareTo(b.dateLogged));

    // Build 4-week buckets
    final total = w30.length;
    final bucketSize = (total / 4).ceil();
    final buckets = List.generate(4, (i) {
      final start = i * bucketSize;
      final end = ((i + 1) * bucketSize).clamp(0, total);
      return w30.sublist(start, end).fold(0, (sum, v) => sum + v);
    });

    // Commit all to state
    setState(() {
      _taskAvg = taskAvg;
      _last7TaskCounts = last7;
      _workouts30Buckets = buckets;
      _goals = goals;
      _todayPulse = pToday;
      _pulseLast7 = pulse7;
      _pulseGoal = storedGoal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalGoals = _goals.length;
    final activeGoals =
        _goals.where((g) => g['active'] == true).length;
    final completedGoals = totalGoals - activeGoals;
    final upcoming = _goals.where((g) {
      final due = DateTime.tryParse(g['dueDate'] ?? '');
      return due != null &&
          due.isAfter(DateTime.now()) &&
          due.isBefore(
              DateTime.now().add(const Duration(days: 7)));
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Pulse KPIs
            Text('Pulse KPIs',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall!
                    .copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Today’s Pulse vs Goal
            _kpiCard(
              title: 'Today’s Pulse vs Goal',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_todayPulse?.pulseRating ?? 0} / $_pulseGoal',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _todayPulse != null
                        ? _todayPulse!.pulseRating / _pulseGoal
                        : 0,
                    backgroundColor: Colors.grey.shade300,
                    color: Colors.pinkAccent,
                    minHeight: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 7-Day Pulse Trend
            _chartCard(
              title: '7-Day Pulse Trend',
              chart: LineChart(
                LineChartData(
                  minY: 1,
                  maxY: _pulseGoal.toDouble(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(7, (i) {
                        final date = DateTime.now()
                            .subtract(Duration(days: 6 - i));
                        final entry = _pulseLast7.firstWhereOrNull(
                          (e) =>
                              e.dateLogged.year == date.year &&
                              e.dateLogged.month == date.month &&
                              e.dateLogged.day == date.day,
                        );
                        return FlSpot(
                            i.toDouble(),
                            entry != null
                                ? entry.pulseRating.toDouble()
                                : 0);
                      }),
                      isCurved: true,
                      color: Colors.pinkAccent,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, _) => spot.y > 0,
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) =>
                            Text(v.toInt().toString()),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          final idx = val.toInt();
                          final date =
                              DateTime.now().subtract(Duration(days: 6 - idx));
                          return Text(
                              DateFormat.MMMd().format(date),
                              style:
                                  const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pulse Streak & Avg
            Row(
              children: [
                Expanded(
                  child: _kpiCard(
                    title: 'Pulse Streak',
                    child: Text(
                      '${_calcStreak()} days',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _kpiCard(
                    title: '7-Day Avg Pulse',
                    child: Text(
                      _pulseLast7.isNotEmpty
                          ? (_pulseLast7
                                      .map((e) => e.pulseRating)
                                      .reduce((a, b) => a + b) /
                                  _pulseLast7.length)
                              .toStringAsFixed(1)
                          : '0',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Goals Overview
            Text('Goals Overview',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall!
                    .copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _kpiCard(
                    title: 'Active',
                    child: Text('$activeGoals',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _kpiCard(
                    title: 'Completed',
                    child: Text('$completedGoals',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            if (upcoming.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...upcoming.map((g) {
                final due = DateTime.parse(g['dueDate']!);
                final daysLeft =
                    due.difference(DateTime.now()).inDays;
                return ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(g['benefit'] ?? ''),
                  trailing: Text('$daysLeft days'),
                );
              }),
            ],
            const SizedBox(height: 24),

            // 7-Day Task Trend (actual per-day counts)
            _chartCard(
              title: '7-Day Task Trend',
              subtitle:
                  'Avg: ${_taskAvg.toStringAsFixed(1)} tasks/day',
              chart: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(7, (i) {
                        return FlSpot(i.toDouble(),
                            _last7TaskCounts[i].toDouble());
                      }),
                      isCurved: true,
                      color: Colors.deepPurple,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) =>
                            Text(v.toInt().toString()),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          final idx = val.toInt();
                          final date = DateTime.now()
                              .subtract(Duration(days: 6 - idx));
                          return Text(
                              DateFormat.MMMd().format(date),
                              style:
                                  const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Workouts (Last 30 Days)
            _chartCard(
              title: 'Workouts (Last 30 Days)',
              subtitle:
                  '${_workouts30Buckets.reduce((a, b) => a + b)} total workouts',
              chart: BarChart(
                BarChartData(
                  barGroups: List.generate(
                    _workouts30Buckets.length,
                    (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: _workouts30Buckets[i].toDouble(),
                          color: Colors.green,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) =>
                            Text(v.toInt().toString()),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) => Text(
                          'W${val.toInt() + 1}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard({required String title, Widget? child}) => Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (child != null) child,
          ],
        ),
      );

  Widget _chartCard({
    required String title,
    String? subtitle,
    required Widget chart,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 12),
          SizedBox(height: 160, child: chart),
        ]),
      );

  int _calcStreak() {
    if (_pulseLast7.isEmpty) return 0;
    int streak = 0;
    DateTime day = DateTime.now();
    for (int i = _pulseLast7.length - 1; i >= 0; i--) {
      final e = _pulseLast7[i];
      if (e.dateLogged.year == day.year &&
          e.dateLogged.month == day.month &&
          e.dateLogged.day == day.day) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}




