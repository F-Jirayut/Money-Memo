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
                Expanded(
                  child: InfoCard(
                    title: 'รายรับรวม',
                    value: moneyText(data.incomeCents),
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InfoCard(
                    title: 'รายจ่ายรวม',
                    value: moneyText(data.expenseCents),
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InfoCard(
              title: 'Balance สุทธิ',
              value: moneyText(data.netCents),
              icon: Icons.calculate_outlined,
            ),
            const SizedBox(height: 18),
            Text(
              'แนวโน้ม 6 เดือน',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: data.trend.map((item) {
                    final maxValue = data.trend
                        .map((trend) => trend.expenseCents)
                        .fold(0, (max, value) => value > max ? value : max);
                    final progress = maxValue == 0
                        ? 0.0
                        : item.expenseCents / maxValue;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(monthText(item.month))),
                              Text(
                                moneyText(item.netCents),
                                style: TextStyle(
                                  color: item.netCents >= 0
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'รายจ่ายแยกตามหมวดหมู่',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (data.expenseByCategory.isEmpty)
              const SizedBox(
                height: 140,
                child: EmptyState(message: 'ยังไม่มีรายจ่ายเดือนนี้'),
              )
            else
              ...data.expenseByCategory.entries.map(
                (entry) => Card(
                  child: ListTile(
                    title: Text(entry.key),
                    trailing: Text(
                      moneyText(entry.value),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              'รายจ่ายแยกตามกระเป๋า',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (data.expenseByWallet.isEmpty)
              const SizedBox(
                height: 120,
                child: EmptyState(message: 'ยังไม่มีรายจ่ายตามกระเป๋า'),
              )
            else
              ...data.expenseByWallet.entries.map(
                (entry) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(entry.key),
                    trailing: Text(
                      moneyText(entry.value),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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

  Future<void> _pickMonth(
    BuildContext context,
    WidgetRef ref,
    DateTime current,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('th', 'TH'),
    );
    if (picked != null) {
      ref
          .read(transactionViewModelProvider)
          .setFilter(
            ref
                .read(transactionFilterProvider)
                .copyWith(month: DateTime(picked.year, picked.month)),
          );
    }
  }
}
