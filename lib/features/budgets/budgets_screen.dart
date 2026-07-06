import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/models.dart';
import '../../shared/app_cards.dart';
import '../transactions/transaction_providers.dart';
import 'budget_providers.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(transactionFilterProvider);
    final budgets = ref.watch(budgetsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Budget รายเดือน')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('เพิ่ม Budget'),
        onPressed: () => _edit(context, ref, filter.month),
      ),
      body: budgets.when(
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text(monthText(filter.month)),
              onPressed: () => _pickMonth(context, ref, filter.month),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const SizedBox(
                height: 180,
                child: EmptyState(message: 'ยังไม่มี Budget ของเดือนนี้'),
              )
            else
              ...items.map(
                (item) => _BudgetCard(
                  budget: item,
                  onTap: () => _edit(context, ref, filter.month, item),
                  onDelete: () => _delete(context, ref, item.id),
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
      ref.read(budgetViewModelProvider).setMonth(picked);
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    DateTime month, [
    BudgetSummary? item,
  ]) async {
    final categories =
        ref
            .read(categoriesProvider)
            .valueOrNull
            ?.where((category) => category.type == TransactionType.expense)
            .toList() ??
        [];
    if (categories.isEmpty) return;
    var categoryId = item?.categoryId ?? categories.first.id;
    final amount = TextEditingController(
      text: item == null ? '' : (item.limitCents / 100).toStringAsFixed(2),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item == null ? 'เพิ่ม Budget' : 'แก้ไข Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'หมวดรายจ่าย'),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => categoryId = value ?? categoryId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'วงเงิน',
                  prefixText: '฿ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    final limitCents = parseBahtToCents(amount.text);
    if (ok == true && limitCents > 0) {
      await ref
          .read(budgetViewModelProvider)
          .save(
            id: item?.id,
            draft: BudgetDraft(
              month: month,
              categoryId: categoryId,
              limitCents: limitCents,
            ),
          );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบ Budget'),
        content: const Text('ยืนยันการลบ Budget นี้?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(budgetViewModelProvider).delete(id);
    }
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.onTap,
    required this.onDelete,
  });

  final BudgetSummary budget;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = budget.isOverBudget ? scheme.error : scheme.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      budget.categoryName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'ลบ',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: budget.progress,
                minHeight: 8,
                color: statusColor,
                backgroundColor: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text('ใช้แล้ว ${moneyText(budget.spentCents)}'),
                  ),
                  Text(
                    'วงเงิน ${moneyText(budget.limitCents)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Text(
                budget.isOverBudget
                    ? 'เกิน Budget ${moneyText(-budget.remainingCents)}'
                    : 'คงเหลือ ${moneyText(budget.remainingCents)}',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
