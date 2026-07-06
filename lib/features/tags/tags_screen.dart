import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../shared/app_cards.dart';
import '../transactions/transaction_providers.dart';

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  static const _colors = [
    0xFFD6B46A,
    0xFF55D6BE,
    0xFF8CB4FF,
    0xFFFF8A8A,
    0xFFCBA6F7,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'เพิ่ม Tag',
        onPressed: () => _edit(context, ref),
        child: const Icon(Icons.add),
      ),
      body: tags.when(
        data: (items) => items.isEmpty
            ? const EmptyState(message: 'ยังไม่มี Tag')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(item.colorValue),
                    ),
                    title: Text(item.name),
                    onTap: () => _edit(context, ref, item),
                    trailing: IconButton(
                      tooltip: 'ลบ',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          ref.read(tagViewModelProvider).delete(item.id),
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

  Future<void> _edit(BuildContext context, WidgetRef ref, [Tag? item]) async {
    final name = TextEditingController(text: item?.name ?? '');
    var colorValue = item?.colorValue ?? _colors.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item == null ? 'เพิ่ม Tag' : 'แก้ไข Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'ชื่อ Tag'),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: _colors.map((value) {
                  final selected = colorValue == value;
                  return ChoiceChip(
                    label: const SizedBox(width: 18, height: 18),
                    selected: selected,
                    backgroundColor: Color(value),
                    selectedColor: Color(value),
                    onSelected: (_) => setState(() => colorValue = value),
                  );
                }).toList(),
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
          .read(tagViewModelProvider)
          .save(id: item?.id, name: name.text.trim(), colorValue: colorValue);
    }
  }
}
