import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'view_workouts_screen.dart';
import 'stats_manager.dart';

class AddWorkoutScreen extends StatefulWidget {
  /// If editing, these two come in; otherwise null for a new save.
  final String? initialCategory;
  final String? initialNotes;
  final int? editIndex;

  const AddWorkoutScreen({
    Key? key,
    this.initialCategory,
    this.initialNotes,
    this.editIndex,
  }) : super(key: key);

  @override
  State<AddWorkoutScreen> createState() => _AddWorkoutScreenState();
}

class _AddWorkoutScreenState extends State<AddWorkoutScreen> {
  final _catCtrl  = TextEditingController();
  final _noteCtrl = TextEditingController();
  List<String> _cats = [];
  String? _sel;

  @override
  void initState() {
    super.initState();
    _loadCats().then((_) {
      // if we’re editing, prefill after categories load
      if (widget.initialCategory != null) {
        _sel = widget.initialCategory;
        _noteCtrl.text = widget.initialNotes ?? '';
      }
    });
  }

  Future<void> _loadCats() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _cats = p.getStringList('workout_categories') ?? [];
    });
  }

  Future<void> _addCat() async {
    final c = _catCtrl.text.trim();
    if (c.isEmpty || _cats.contains(c)) return;
    _cats.add(c);
    _catCtrl.clear();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('workout_categories', _cats);
    setState(() {});
  }

  Future<void> _save() async {
    if (_sel == null || _noteCtrl.text.trim().isEmpty) return;

    final entry = {
      'category': _sel!,
      'notes':    _noteCtrl.text.trim(),
      'date':     DateTime.now().toIso8601String(),
    };

    final p    = await SharedPreferences.getInstance();
    final logs = p.getStringList('workout_logs') ?? [];

    if (widget.editIndex != null) {
      // overwrite the one we’re editing
      logs[widget.editIndex!] = jsonEncode(entry);
    } else {
      // new entry
      logs.add(jsonEncode(entry));
      StatsManager.recordWorkout(DateTime.now());

    }

    await p.setStringList('workout_logs', logs);

    // After save (new or edit), go to history
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ViewWorkoutsScreen()),
    );
  }

  @override
  Widget build(BuildContext c) {
    final isEditing = widget.editIndex != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Workout' : 'Add Workout'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // New Category Input
            TextField(
              controller: _catCtrl,
              decoration: const InputDecoration(
                labelText: 'New category (e.g. Legs, Chest)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _addCat(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _addCat, child: const Text('Add Category')),
            const SizedBox(height: 20),

            // Category Chips
            const Text('Select Category', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _cats.map((c) {
                return ChoiceChip(
                  label: Text(c),
                  selected: _sel == c,
                  onSelected: (_) => setState(() => _sel = c),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Notes
            TextField(
              controller: _noteCtrl,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Workout notes (reps, mood, etc.)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // Save Button
            ElevatedButton(
              onPressed: _save,
              child: Text(isEditing ? 'Save Changes' : 'Save Workout'),
            ),

            const Spacer(),

            // Fallback link
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                c,
                MaterialPageRoute(builder: (_) => const ViewWorkoutsScreen()),
              ),
              child: const Text('View Past Workouts'),
            ),
          ],
        ),
      ),
    );
  }
}



