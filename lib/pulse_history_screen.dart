// lib/pulse_history_screen.dart

import 'package:flutter/material.dart';
import 'services/pulse_service.dart';
import 'models/pulse_entry.dart';
import 'package:intl/intl.dart';

class PulseHistoryScreen extends StatefulWidget {
  const PulseHistoryScreen({Key? key}) : super(key: key);

  @override
  _PulseHistoryScreenState createState() => _PulseHistoryScreenState();
}

class _PulseHistoryScreenState extends State<PulseHistoryScreen> {
  late Future<List<PulseEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = PulseService.loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pulse History'),
      ),
      body: FutureBuilder<List<PulseEntry>>(
        future: _entriesFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? [];
          if (entries.isEmpty) {
            return const Center(child: Text('No pulses logged yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final e = entries[entries.length - 1 - i];
              final date = DateFormat.yMMMd().format(e.dateLogged);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: Text(
                    e.pulseRating.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text('$date'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e.gratitudeNote.isNotEmpty)
                      Text('🙏 ${e.gratitudeNote}'),
                    Text('🎯 Tasks goal: ${e.taskGoal}'),
                    if (e.freeReflection.isNotEmpty)
                      Text('💭 ${e.freeReflection}'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
