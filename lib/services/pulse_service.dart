// lib/services/pulse_service.dart

import '../models/pulse_entry.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


class PulseService {
  static const _storageKey = 'pulse_entries';

  /// Load all saved PulseEntry objects.
  static Future<List<PulseEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];
    final List<dynamic> decoded = json.decode(jsonString);
    return decoded
        .map((e) => PulseEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Save or update today's PulseEntry.
  static Future<void> saveEntry(PulseEntry entry) async {
    final entries = await loadEntries();
    final today = DateTime.now();
    // Replace today’s entry if it exists
    final index = entries.indexWhere((e) =>
        e.dateLogged.year == today.year &&
        e.dateLogged.month == today.month &&
        e.dateLogged.day == today.day);
    if (index != -1) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }
    final prefs = await SharedPreferences.getInstance();
    final jsonString =
        json.encode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Retrieve today's entry, if any.
 /// Retrieve today's entry, if any.
static Future<PulseEntry?> getTodayEntry() async {
  final entries = await loadEntries();
  final today = DateTime.now();
  // Manual search so we can return null if not found
  for (final e in entries) {
    if (e.dateLogged.year == today.year &&
        e.dateLogged.month == today.month &&
        e.dateLogged.day == today.day) {
      return e;
    }
  }
  return null;
}
  /// Delete all entries.
  static Future<void> deleteAllEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
