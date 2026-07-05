import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../shared/app_cards.dart';
import '../transactions/transaction_providers.dart';

class MonthlySummaryScreen extends ConsumerWidget {
  const MonthlySummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(transactionFilterProvider);
    final summary = ref.watch(monthlySummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('สรุปรายเดือน')),
      body: summary.when(
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text(monthText(filter.month)),
              onPressed: () => _pickMonth(context, ref, filter.month),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: InfoCard(title: 'รายรับรวม', value: moneyText(data.incomeCents), color: Colors.teal.shade700)),
                const SizedBox(width: 12),
                Expanded(child: InfoCard(title: 'รายจ่ายรวม', value: moneyText(data.expenseCents), color: Colors.red.shade700)),
              ],
            ),
            const SizedBox(height: 12),
            InfoCard(title: 'Balance สุทธิ', value: moneyText(data.netCents), icon: Icons.calculate_outlined),
            const SizedBox(height: 18),
            Text('รายจ่ายแยกตามหมวดหมู่', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (data.expenseByCategory.isEmpty)
              const SizedBox(height: 140, child: EmptyState(message: 'ยังไม่มีรายจ่ายเดือนนี้'))
            else
              ...data.expenseByCategory.entries.map(
                (entry) => Card(
                  child: ListTile(
                    title: Text(entry.key),
                    trailing: Text(moneyText(entry.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(message: error.toString()),
      ),
    );
  }

  Future<void> _pickMonth(BuildContext context, WidgetRef ref, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('th', 'TH'),
    );
    if (picked != null) {
      ref.read(transactionFilterProvider.notifier).state =
          ref.read(transactionFilterProvider).copyWith(month: DateTime(picked.year, picked.month));
    }
  }
}
