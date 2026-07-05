import 'package:flutter/material.dart';

import '../backup/backup_screen.dart';
import '../categories/categories_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../export/export_screen.dart';
import '../reports/monthly_summary_screen.dart';
import '../transactions/transactions_screen.dart';
import '../wallets/wallets_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    DashboardScreen(),
    TransactionsScreen(),
    MonthlySummaryScreen(),
    WalletsScreen(),
    CategoriesScreen(),
    ExportScreen(),
    BackupScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'หน้าหลัก'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'รายการ'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'สรุป'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'กระเป๋า'),
          NavigationDestination(icon: Icon(Icons.category_outlined), selectedIcon: Icon(Icons.category), label: 'หมวด'),
          NavigationDestination(icon: Icon(Icons.ios_share_outlined), selectedIcon: Icon(Icons.ios_share), label: 'CSV'),
          NavigationDestination(icon: Icon(Icons.settings_backup_restore), label: 'Backup'),
        ],
      ),
    );
  }
}
