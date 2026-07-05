import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import 'transaction_providers.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({super.key, this.transaction});

  final MoneyTransaction? transaction;

  @override
  ConsumerState<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TransactionType _type;
  late DateTime _date;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  int? _categoryId;
  int? _walletId;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _type = tx?.type ?? TransactionType.expense;
    _date = tx?.date ?? DateTime.now();
    _amount = TextEditingController(text: tx == null ? '' : (tx.amountCents / 100).toStringAsFixed(2));
    _note = TextEditingController(text: tx?.note ?? '');
    _categoryId = tx?.categoryId;
    _walletId = tx?.walletId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    final filteredCategories = categories.where((item) => item.type == _type).toList();
    if (_categoryId == null && filteredCategories.isNotEmpty) {
      _categoryId = filteredCategories.first.id;
    }
    if (_walletId == null && wallets.isNotEmpty) {
      _walletId = wallets.first.id;
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.transaction == null ? 'เพิ่มรายการ' : 'แก้ไขรายการ', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              SegmentedButton<TransactionType>(
                segments: TransactionType.values
                    .map((type) => ButtonSegment(value: type, label: Text(type.label)))
                    .toList(),
                selected: {_type},
                onSelectionChanged: (value) => setState(() {
                  _type = value.first;
                  _categoryId = null;
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'จำนวนเงิน', prefixText: '฿ '),
                validator: (value) => parseBahtToCents(value ?? '') <= 0 ? 'กรอกจำนวนเงิน' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                items: filteredCategories.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) => value == null ? 'เลือกหมวดหมู่' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _walletId,
                decoration: const InputDecoration(labelText: 'กระเป๋าเงิน'),
                items: wallets.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                onChanged: (value) => setState(() => _walletId = value),
                validator: (value) => value == null ? 'เลือกกระเป๋าเงิน' : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(inputDateText(_date)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    locale: const Locale('th', 'TH'),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'หมายเหตุ'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('บันทึก'),
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(repositoryProvider).saveTransaction(
          id: widget.transaction?.id,
          draft: TransactionDraft(
            type: _type,
            amountCents: parseBahtToCents(_amount.text),
            date: _date,
            categoryId: _categoryId!,
            walletId: _walletId!,
            note: _note.text.trim(),
          ),
        );
    ref.read(refreshProvider.notifier).state++;
    if (mounted) Navigator.pop(context);
  }
}
