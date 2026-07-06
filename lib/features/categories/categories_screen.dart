import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../shared/app_cards.dart';
import '../transactions/transaction_providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('หมวดหมู่')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'เพิ่มหมวดหมู่',
        child: const Icon(Icons.add),
        onPressed: () => _edit(context, ref),
      ),
      body: categories.when(
        data: (items) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: Icon(
                item.type == TransactionType.income
                    ? Icons.add_circle_outline
                    : Icons.remove_circle_outline,
              ),
              title: Text(item.name),
              subtitle: Text(item.type.label),
              onTap: () => _edit(context, ref, item),
              trailing: IconButton(
                tooltip: 'ลบ',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, ref, item.id),
              ),
            );
          },
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemCount: items.length,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(message: error.toString()),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    Category? item,
  ]) async {
    final name = TextEditingController(text: item?.name ?? '');
    var type = item?.type ?? TransactionType.expense;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item == null ? 'เพิ่มหมวดหมู่' : 'แก้ไขหมวดหมู่'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'ชื่อหมวดหมู่'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<TransactionType>(
                segments: TransactionType.values
                    .map((e) => ButtonSegment(value: e, label: Text(e.label)))
                    .toList(),
                selected: {type},
                onSelectionChanged: (value) =>
                    setState(() => type = value.first),
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
    if (ok == true && name.text.trim().isNotEmpty) {
      await ref
          .read(categoryViewModelProvider)
          .save(id: item?.id, name: name.text.trim(), type: type);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref.read(categoryViewModelProvider).delete(id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบไม่ได้ เพราะมีรายการใช้หมวดหมู่นี้อยู่'),
          ),
        );
      }
    }
  }
}
