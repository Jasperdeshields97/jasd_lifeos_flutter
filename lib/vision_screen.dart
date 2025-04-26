import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'stats_manager.dart';

class VisionScreen extends StatefulWidget {
  const VisionScreen({super.key});

  @override
  State<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen> {
  final TextEditingController _visionController = TextEditingController();
  List<Map<String, dynamic>> goals = [];

  @override
  void initState() {
    super.initState();
    _loadVision();
  }

  Future<void> _loadVision() async {
    final prefs = await SharedPreferences.getInstance();
    _visionController.text = prefs.getString('vision_statement') ?? '';
    final saved = prefs.getString('big_goals');
    final parsed = saved != null ? jsonDecode(saved) as List : [];
    setState(() => goals = List<Map<String, dynamic>>.from(parsed));
  }

  Future<void> _saveVision(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vision_statement', value);
  }

  void _showGoalDialog([Map<String, dynamic>? existingGoal, int? index]) {
    final TextEditingController titleController = TextEditingController(text: existingGoal?['title'] ?? '');
    final TextEditingController benefitController = TextEditingController(text: existingGoal?['benefit'] ?? '');
    String area = existingGoal?['area'] ?? 'Health';
    bool isActive = existingGoal?['active'] ?? true;
    DateTime? dueDate = existingGoal?['dueDate'] != null
        ? DateTime.tryParse(existingGoal!['dueDate'])
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20),
        child: Wrap(
          children: [
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: benefitController,
              decoration: const InputDecoration(labelText: 'Benefit'),
            ),
            DropdownButtonFormField<String>(
              value: area,
              items: const [
                DropdownMenuItem(value: 'Health', child: Text('Health')),
                DropdownMenuItem(value: 'Wealth', child: Text('Wealth')),
                DropdownMenuItem(value: 'Relationships', child: Text('Relationships')),
                DropdownMenuItem(value: 'Spirituality', child: Text('Spirituality')),
                DropdownMenuItem(value: 'Personal Growth', child: Text('Personal Growth')),
              ],
              onChanged: (val) => area = val!,
              decoration: const InputDecoration(labelText: 'Area'),
            ),
            Row(
              children: [
                Checkbox(
                  value: isActive,
                  onChanged: (val) => setState(() => isActive = val!),
                ),
                const Text('Active Goal'),
              ],
            ),
            TextButton(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: dueDate ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (selected != null) {
                  setState(() => dueDate = selected);
                }
              },
              child: Text(
                dueDate != null ? 'Due: ${dueDate!.toIso8601String().split('T').first}' : 'Select Due Date',
                style: const TextStyle(color: Colors.deepPurple),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final newGoal = {
                  'title': titleController.text,
                  'benefit': benefitController.text,
                  'area': area,
                  'active': isActive,
                  'dueDate': dueDate?.toIso8601String(),
                };
                if (index != null) {
                  goals[index] = newGoal;
                } else {
                  goals.add(newGoal);
                }
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('big_goals', jsonEncode(goals));
                StatsManager.updateGoalStats(goals); // ✅ auto update stats
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Save Goal'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision & Goals'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Your Vision Statement 🧠',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _visionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Describe your ideal life, mindset, and future...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: _saveVision,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Big Goals 🎯', style: TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: () => _showGoalDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade50,
                    foregroundColor: Colors.deepPurple,
                  ),
                  child: const Text('Add Goal'),
                )
              ],
            ),
            const SizedBox(height: 8),
            ...goals.map((goal) {
              final dueDate = goal['dueDate'] != null
                  ? DateTime.tryParse(goal['dueDate']) ?? DateTime.now()
                  : null;
              final daysLeft = dueDate != null
                  ? dueDate.difference(now).inDays
                  : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal['title'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    if (dueDate != null)
                      Text('⏳ ${daysLeft ?? '?'} days left',
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    if (goal['benefit'] != null)
                      Text('💡 Benefit: ${goal['benefit']}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.deepPurple),
                        onPressed: () => _showGoalDialog(goal, goals.indexOf(goal)),
                      ),
                    ),
                  ],
                ),
              );
            })
          ],
        ),
      ),
    );
  }
}




