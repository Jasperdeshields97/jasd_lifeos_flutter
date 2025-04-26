import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'pulse_check_screen.dart';
import 'pulse_history_screen.dart';
import 'stats_manager.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StatsManager.rolloverTasksIfNeeded();
  runApp(const JasdLifeOS());
}

class JasdLifeOS extends StatelessWidget {
  const JasdLifeOS({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JASD LifeOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.deepPurple,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.deepPurple,
          centerTitle: true,
        ),
        tabBarTheme: const TabBarTheme(
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(width: 3, color: Colors.deepPurple),
          ),
        ),
      ),
      // App entry point
      home: const HomeScreen(),

      // Named routes
      routes: {
        // Keep your existing home route if you ever want to navigate by name:
        // '/': (_) => const HomeScreen(),

        // New Pulse Check screen
        '/pulse': (_) => const PulseCheckScreen(),
        '/pulse_history': (_) => const PulseHistoryScreen(),  // ← add this line
      },
    );
  }
}

