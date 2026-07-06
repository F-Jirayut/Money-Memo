import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/formatters.dart';
import '../../core/models.dart';
import 'transaction_providers.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({super.key, this.transaction});

  final MoneyTransaction? transaction;

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TransactionType _type;
  late DateTime _date;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  int? _categoryId;
  int? _walletId;
  late String _receiptPath;
  final Set<int> _tagIds = {};
  bool _loadedExistingTags = false;
  bool _ocrBusy = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _type = tx?.type ?? TransactionType.expense;
    _date = tx?.date ?? DateTime.now();
    _amount = TextEditingController(
      text: tx == null ? '' : (tx.amountCents / 100).toStringAsFixed(2),
    );
    _note = TextEditingController(text: tx?.note ?? '');
    _categoryId = tx?.categoryId;
    _walletId = tx?.walletId;
    _receiptPath = tx?.receiptPath ?? '';
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
    final tags = ref.watch(tagsProvider).valueOrNull ?? [];
    final existingTagIds = widget.transaction == null
        ? const AsyncValue<List<int>>.data([])
        : ref.watch(transactionTagIdsProvider(widget.transaction!.id));
    existingTagIds.whenData((ids) {
      if (!_loadedExistingTags) {
        _tagIds
          ..clear()
          ..addAll(ids);
        _loadedExistingTags = true;
      }
    });
    final filteredCategories = categories
        .where((item) => item.type == _type)
        .toList();
    if (_categoryId == null && filteredCategories.isNotEmpty) {
      _categoryId = filteredCategories.first.id;
    }
    if (_walletId == null && wallets.isNotEmpty) {
      _walletId = wallets.first.id;
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.transaction == null ? 'เพิ่มรายการ' : 'แก้ไขรายการ',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SegmentedButton<TransactionType>(
                segments: TransactionType.values
                    .map(
                      (type) =>
                          ButtonSegment(value: type, label: Text(type.label)),
                    )
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'จำนวนเงิน',
                  prefixText: '฿ ',
                ),
                validator: (value) =>
                    parseBahtToCents(value ?? '') <= 0 ? 'กรอกจำนวนเงิน' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                items: filteredCategories
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) => value == null ? 'เลือกหมวดหมู่' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _walletId,
                decoration: const InputDecoration(labelText: 'กระเป๋าเงิน'),
                items: wallets
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
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
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined),
                title: const Text('แนบรูปสลิป/ใบเสร็จ'),
                subtitle: Text(
                  _receiptPath.isEmpty
                      ? 'ยังไม่ได้แนบรูป'
                      : _receiptPath.split('/').last,
                ),
                trailing: _receiptPath.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'ลบรูปแนบ',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _receiptPath = ''),
                      ),
                onTap: _pickReceipt,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: _ocrBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner_outlined),
                label: const Text('OCR อ่านรูปจาก Gallery'),
                onPressed: _ocrBusy ? null : _pickReceiptAndRunOcr,
              ),
              if (_receiptPath.isNotEmpty && File(_receiptPath).existsSync())
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_receiptPath),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Tags', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((tag) {
                    return FilterChip(
                      label: Text(tag.name),
                      selected: _tagIds.contains(tag.id),
                      avatar: CircleAvatar(
                        backgroundColor: Color(tag.colorValue),
                      ),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _tagIds.add(tag.id);
                        } else {
                          _tagIds.remove(tag.id);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ],
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
    await ref
        .read(transactionViewModelProvider)
        .save(
          id: widget.transaction?.id,
          draft: TransactionDraft(
            type: _type,
            amountCents: parseBahtToCents(_amount.text),
            date: _date,
            categoryId: _categoryId!,
            walletId: _walletId!,
            note: _note.text.trim(),
            receiptPath: _receiptPath,
            tagIds: _tagIds.toList(),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickReceipt() async {
    final path = await _pickAndStoreReceipt();
    if (path != null) {
      setState(() => _receiptPath = path);
    }
  }

  Future<void> _pickReceiptAndRunOcr() async {
    setState(() => _ocrBusy = true);
    try {
      final path = await _pickAndStoreReceipt();
      if (path == null) return;
      final result = await ref
          .read(transactionViewModelProvider)
          .recognizeReceipt(path);
      if (!mounted) return;
      setState(() {
        _receiptPath = path;
        if (result.amountCents != null) {
          _amount.text = (result.amountCents! / 100).toStringAsFixed(2);
        }
        final summary = _ocrNoteSummary(result.rawText);
        if (_note.text.trim().isEmpty && summary.isNotEmpty) {
          _note.text = summary;
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.amountCents == null
                ? 'OCR อ่านข้อความได้ แต่ยังเดายอดเงินไม่ได้'
                : 'OCR เติมยอดเงินให้แล้ว',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR ไม่สำเร็จ กรุณาลองรูปอื่น')),
        );
      }
    } finally {
      if (mounted) setState(() => _ocrBusy = false);
    }
  }

  Future<String?> _pickAndStoreReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path != null) {
      return ref.read(transactionViewModelProvider).storeReceiptImage(path);
    }
    return null;
  }

  String _ocrNoteSummary(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(3)
        .join(' | ');
    if (lines.isEmpty) return '';
    return 'OCR: $lines';
  }
}
