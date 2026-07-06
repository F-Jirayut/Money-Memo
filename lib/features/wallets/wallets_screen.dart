import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/models.dart';
import '../../shared/app_cards.dart';
import '../transactions/transaction_providers.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('กระเป๋าเงิน')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'เพิ่มกระเป๋า',
        child: const Icon(Icons.add),
        onPressed: () => _edit(context, ref),
      ),
      body: wallets.when(
        data: (items) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(item.name),
              subtitle: Text('Balance ${moneyText(item.balanceCents)}'),
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
    Wallet? item,
  ]) async {
    final name = TextEditingController(text: item?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'เพิ่มกระเป๋า' : 'แก้ไขกระเป๋า'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'ชื่อกระเป๋า'),
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
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await ref
          .read(walletViewModelProvider)
          .save(id: item?.id, name: name.text.trim());
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref.read(walletViewModelProvider).delete(id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบไม่ได้ เพราะมีรายการใช้กระเป๋านี้อยู่'),
          ),
        );
      }
    }
  }
}
