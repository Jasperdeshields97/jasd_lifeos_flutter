import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_workout_screen.dart';

class ViewWorkoutsScreen extends StatefulWidget {
  const ViewWorkoutsScreen({Key? key}) : super(key: key);

  @override
  State<ViewWorkoutsScreen> createState() => _ViewWorkoutsScreenState();
}

class _ViewWorkoutsScreenState extends State<ViewWorkoutsScreen> {
  List<Map<String, String>> _workouts = [];

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    final List<Map<String, String>> workouts = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('workout_logs') ?? [];
      for (final jsonStr in stored) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          workouts.add({
            'category': map['category']?.toString() ?? '',
            'notes':    map['notes']?.toString()    ?? '',
          });
        } catch (_) {
          // skip malformed entry
        }
      }
    } catch (_) {
      // prefs error; keep workouts empty
    }
    setState(() => _workouts = workouts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
        leading: const BackButton(color: Colors.deepPurple),
      ),
      body: RefreshIndicator(
        onRefresh: _loadWorkouts,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _workouts.length,
          itemBuilder: (ctx, idx) {
            final w = _workouts[idx];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title:    Text(w['category']!, style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(w['notes']!,    style: Theme.of(context).textTheme.bodyMedium),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.deepPurple),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddWorkoutScreen(
                          initialCategory: w['category'],
                          initialNotes:    w['notes'],
                          editIndex:       idx,
                        ),
                      ),
                    ).then((_) => _loadWorkouts());
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

