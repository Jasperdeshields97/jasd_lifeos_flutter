// lib/pulse_check_screen.dart

import 'package:flutter/material.dart';
import 'services/pulse_service.dart';
import 'models/pulse_entry.dart';

class PulseCheckScreen extends StatefulWidget {
  const PulseCheckScreen({Key? key}) : super(key: key);

  @override
  _PulseCheckScreenState createState() => _PulseCheckScreenState();
}

class _PulseCheckScreenState extends State<PulseCheckScreen> {
  int _pulseRating = 3;
  final _gratitudeController = TextEditingController();
  final _taskGoalController = TextEditingController(text: '5');
  final _freeReflectionController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayEntry();
  }

  Future<void> _loadTodayEntry() async {
    final entry = await PulseService.getTodayEntry();
    if (entry != null) {
      _pulseRating = entry.pulseRating;
      _gratitudeController.text = entry.gratitudeNote;
      _taskGoalController.text = entry.taskGoal.toString();
      _freeReflectionController.text = entry.freeReflection;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveEntry() async {
    final newEntry = PulseEntry(
      pulseRating: _pulseRating,
      gratitudeNote: _gratitudeController.text,
      taskGoal: int.tryParse(_taskGoalController.text) ?? 5,
      freeReflection: _freeReflectionController.text,
    );
    await PulseService.saveEntry(newEntry);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pulse saved!')),
    );
    Navigator.pop(context);
  }

  Widget _buildPulseButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (i) {
        final val = i + 1;
        final isSelected = _pulseRating == val;
        return GestureDetector(
          onTap: () => setState(() => _pulseRating = val),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.black : Colors.grey[300],
            ),
            child: Text(
              '$val',
              style: TextStyle(
                fontSize: 18,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ),
        );
      }),
    );
  }

  String _ratingDescription() {
    switch (_pulseRating) {
      case 5:
        return 'Unstoppable';
      case 4:
        return 'Focused';
      case 3:
        return 'Okay';
      case 2:
        return 'Low energy';
      case 1:
      default:
        return 'Struggling';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pulse Check')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
    title: const Text('Pulse Check'),
    centerTitle: true,
    elevation: 0,
    actions: [
      IconButton(
        icon: const Icon(Icons.history),
        tooltip: 'View Past Pulses',
        onPressed: () => Navigator.pushNamed(context, '/pulse_history'),
      ),
    ],
  ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How ready do you feel today?',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _buildPulseButtons(),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _ratingDescription(),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 32),
            const Text(
              'Quick Reflection (Optional)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gratitudeController,
              decoration: const InputDecoration(
                labelText: 'One thing you\'re grateful for',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taskGoalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'How many tasks will you complete today?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _freeReflectionController,
              decoration: const InputDecoration(
                labelText: 'Anything else on your mind?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: _saveEntry,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save Pulse',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
