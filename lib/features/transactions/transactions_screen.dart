import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/models.dart';
import '../../shared/app_cards.dart';
import 'transaction_form.dart';
import 'transaction_providers.dart';
import 'transaction_tile.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(transactionFilterProvider);
    final txs = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('รายการย้อนหลัง')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('เพิ่ม'),
        onPressed: () => _openForm(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text(monthText(filter.month)),
                  onPressed: () => _pickMonth(context, ref, filter.month),
                ),
                DropdownButton<TransactionType?>(
                  value: filter.type,
                  hint: const Text('ทุกประเภท'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('ทุกประเภท')),
                    DropdownMenuItem(
                      value: TransactionType.income,
                      child: Text('รายรับ'),
                    ),
                    DropdownMenuItem(
                      value: TransactionType.expense,
                      child: Text('รายจ่าย'),
                    ),
                  ],
                  onChanged: (value) =>
                      ref
                          .read(transactionFilterProvider.notifier)
                          .state = filter.copyWith(
                        type: value,
                        clearType: value == null,
                      ),
                ),
                DropdownButton<int?>(
                  value: filter.categoryId,
                  hint: const Text('ทุกหมวด'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('ทุกหมวด')),
                    ...categories.map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      ref
                          .read(transactionFilterProvider.notifier)
                          .state = filter.copyWith(
                        categoryId: value,
                        clearCategory: value == null,
                      ),
                ),
                DropdownButton<int?>(
                  value: filter.walletId,
                  hint: const Text('ทุกกระเป๋า'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('ทุกกระเป๋า'),
                    ),
                    ...wallets.map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      ref
                          .read(transactionFilterProvider.notifier)
                          .state = filter.copyWith(
                        walletId: value,
                        clearWallet: value == null,
                      ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ค้นหาจากหมายเหตุ',
              ),
              onChanged: (value) =>
                  ref.read(transactionFilterProvider.notifier).state = filter
                      .copyWith(search: value),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: txs.when(
              data: (items) => items.isEmpty
                  ? const EmptyState(message: 'ยังไม่มีรายการในเงื่อนไขนี้')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => TransactionTile(
                        transaction: items[index],
                        onTap: () => _openForm(context, items[index]),
                        onDelete: () => _delete(context, ref, items[index].id),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(message: error.toString()),
            ),
          ),
        ],
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

  void _openForm(BuildContext context, [MoneyTransaction? tx]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TransactionFormSheet(transaction: tx),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบรายการ'),
        content: const Text('ยืนยันการลบรายการนี้?'),
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
    if (ok != true) return;
    await ref.read(transactionViewModelProvider).delete(id);
  }
}
