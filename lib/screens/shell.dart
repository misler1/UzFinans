import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'incomes_screen.dart';
import 'expenses_screen.dart';
import 'banks_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    IncomesScreen(),
    ExpensesScreen(),
    BanksScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Özet"),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: "Gelirler"),
          BottomNavigationBarItem(icon: Icon(Icons.trending_down), label: "Giderler"),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: "Bankalar"),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: "Rapor"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ayarlar"),
        ],
      ),
    );
  }
}
