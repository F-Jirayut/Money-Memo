import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/models.dart';
import '../../shared/app_cards.dart';
import '../transactions/transaction_providers.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringTransactionsProvider);
    final month = ref.watch(transactionFilterProvider).month;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          IconButton(
            tooltip: 'สร้างรายการเดือนนี้',
            icon: const Icon(Icons.playlist_add_check),
            onPressed: () => _generate(context, ref, month),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'เพิ่มรายการประจำ',
        onPressed: () => _edit(context, ref),
        child: const Icon(Icons.add),
      ),
      body: items.when(
        data: (data) => data.isEmpty
            ? const EmptyState(message: 'ยังไม่มีรายการประจำ')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                itemCount: data.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = data[index];
                  return ListTile(
                    leading: Icon(
                      item.isActive ? Icons.repeat : Icons.pause_circle_outline,
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      'ทุกวันที่ ${item.dayOfMonth} • ${item.categoryName} • ${item.walletName}',
                    ),
                    trailing: Text(
                      '${item.type == TransactionType.income ? '+' : '-'}${moneyText(item.amountCents)}',
                      style: TextStyle(
                        color: item.type == TransactionType.income
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => _edit(context, ref, item),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(message: error.toString()),
      ),
    );
  }

  Future<void> _generate(
    BuildContext context,
    WidgetRef ref,
    DateTime month,
  ) async {
    final count = await ref.read(recurringViewModelProvider).generate(month);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('สร้างรายการประจำ $count รายการ')));
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    RecurringTransaction? item,
  ]) async {
    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final wallets = ref.read(walletsProvider).valueOrNull ?? [];
    if (categories.isEmpty || wallets.isEmpty) return;

    final name = TextEditingController(text: item?.name ?? '');
    final amount = TextEditingController(
      text: item == null ? '' : (item.amountCents / 100).toStringAsFixed(2),
    );
    final note = TextEditingController(text: item?.note ?? '');
    var type = item?.type ?? TransactionType.expense;
    var filteredCategories = categories
        .where((category) => category.type == type)
        .toList();
    var categoryId = item?.categoryId ?? filteredCategories.first.id;
    var walletId = item?.walletId ?? wallets.first.id;
    var day = item?.dayOfMonth ?? 1;
    var active = item?.isActive ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item == null ? 'เพิ่มรายการประจำ' : 'แก้ไขรายการประจำ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'ชื่อ'),
                ),
                const SizedBox(height: 12),
                SegmentedButton<TransactionType>(
                  segments: TransactionType.values
                      .map(
                        (value) => ButtonSegment(
                          value: value,
                          label: Text(value.label),
                        ),
                      )
                      .toList(),
                  selected: {type},
                  onSelectionChanged: (value) => setState(() {
                    type = value.first;
                    filteredCategories = categories
                        .where((category) => category.type == type)
                        .toList();
                    categoryId = filteredCategories.first.id;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'จำนวนเงิน',
                    prefixText: '฿ ',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                  items: filteredCategories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => categoryId = value ?? categoryId),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: walletId,
                  decoration: const InputDecoration(labelText: 'กระเป๋า'),
                  items: wallets
                      .map(
                        (wallet) => DropdownMenuItem(
                          value: wallet.id,
                          child: Text(wallet.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => walletId = value ?? walletId),
                ),
                const SizedBox(height: 12),
                StepperControl(
                  value: day,
                  onChanged: (value) => setState(() => day = value),
                ),
                SwitchListTile(
                  value: active,
                  title: const Text('เปิดใช้งาน'),
                  onChanged: (value) => setState(() => active = value),
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'หมายเหตุ'),
                ),
              ],
            ),
          ),
          actions: [
            if (item != null)
              TextButton(
                onPressed: () async {
                  await ref.read(recurringViewModelProvider).delete(item.id);
                  if (context.mounted) Navigator.pop(context, false);
                },
                child: const Text('ลบ'),
              ),
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
    final amountCents = parseBahtToCents(amount.text);
    if (ok == true && name.text.trim().isNotEmpty && amountCents > 0) {
      await ref
          .read(recurringViewModelProvider)
          .save(
            id: item?.id,
            draft: RecurringTransactionDraft(
              name: name.text.trim(),
              type: type,
              amountCents: amountCents,
              categoryId: categoryId,
              walletId: walletId,
              dayOfMonth: day,
              note: note.text.trim(),
              isActive: active,
            ),
          );
    }
  }
}

class StepperControl extends StatelessWidget {
  const StepperControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Text('วันที่ของเดือน')),
        IconButton(
          tooltip: 'ลด',
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value <= 1 ? null : () => onChanged(value - 1),
        ),
        SizedBox(width: 36, child: Center(child: Text('$value'))),
        IconButton(
          tooltip: 'เพิ่ม',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value >= 31 ? null : () => onChanged(value + 1),
        ),
      ],
    );
  }
}
