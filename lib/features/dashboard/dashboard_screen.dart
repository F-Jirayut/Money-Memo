import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../shared/app_cards.dart';
import '../transactions/transaction_form.dart';
import '../transactions/transaction_providers.dart';
import '../transactions/transaction_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Money Memo')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มรายการ'),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const TransactionFormSheet(),
        ),
      ),
      body: dashboard.when(
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
          children: [
            InfoCard(
              title: 'ยอดคงเหลือทั้งหมด',
              value: moneyText(data.totalBalanceCents),
              icon: Icons.savings_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InfoCard(
                    title: 'รายรับเดือนนี้',
                    value: moneyText(data.monthIncomeCents),
                    icon: Icons.trending_up,
                    color: Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InfoCard(
                    title: 'รายจ่ายเดือนนี้',
                    value: moneyText(data.monthExpenseCents),
                    icon: Icons.trending_down,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('รายการล่าสุด', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: data.latestTransactions.isEmpty
                  ? const SizedBox(height: 140, child: EmptyState(message: 'ยังไม่มีรายการ'))
                  : Column(
                      children: data.latestTransactions
                          .map((tx) => TransactionTile(transaction: tx))
                          .toList(),
                    ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(message: error.toString()),
      ),
    );
  }
}
