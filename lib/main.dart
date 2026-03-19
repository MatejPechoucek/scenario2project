import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database/db_helper.dart';
import 'pages/dietpage/diet_page.dart';
import 'pages/homepage/home_page.dart';
import 'pages/profilepage/profile_page.dart';
import 'pages/qnapage/qna_page.dart';
import 'services/food_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scenario 2 Project',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _SplashScreen(),
    );
  }
}

// ── Splash screen — initialises food data + DB before showing the main UI ─────

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Run in parallel: load bundled JSON asset + warm up SQLite (runs migrations,
    // creates tables, seeds the default user if needed).
    await Future.wait([
      FoodRepository.initialize(),
      DbHelper.database,
    ]);
    // Ensure the single app user exists (idempotent).
    await DbHelper.getUser();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text('CleanEater', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 48),
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading your meal plan…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main shell — bottom nav + page switcher ───────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    HomePage(),
    DietPage(),
    QnaPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Scenario 2 Project'),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home, color: Colors.black), label: '', backgroundColor: Colors.white),
          BottomNavigationBarItem(icon: Icon(Icons.apple, color: Colors.black), label: '', backgroundColor: Colors.white),
          BottomNavigationBarItem(icon: Icon(Icons.note, color: Colors.black), label: '', backgroundColor: Colors.white),
          BottomNavigationBarItem(icon: Icon(Icons.person, color: Colors.black), label: '', backgroundColor: Colors.white),
        ],
      ),
    );
  }
}
