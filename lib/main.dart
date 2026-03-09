import 'package:flutter/material.dart';

import 'pages/diet_page.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/qna_page.dart';

void main() {
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
      home: const MainShell(),
    );
  }
}

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
          BottomNavigationBarItem(icon: Icon(Icons.home, color: Colors.black), label: "", backgroundColor: Colors.white),
          BottomNavigationBarItem(icon: Icon(Icons.apple, color: Colors.black), label: "", backgroundColor: Colors.white),
          BottomNavigationBarItem(icon: Icon(Icons.note, color: Colors.black), label: "", backgroundColor: Colors.white),
          BottomNavigationBarItem(icon: Icon(Icons.person, color: Colors.black), label: "", backgroundColor: Colors.white),
        ],
      ),
    );
  }
}