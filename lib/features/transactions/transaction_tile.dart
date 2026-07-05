import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/models.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  final MoneyTransaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? Colors.teal.shade700 : Colors.red.shade700;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(isIncome ? Icons.trending_up : Icons.trending_down, color: color),
      ),
      title: Text(transaction.categoryName, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${dateText(transaction.date)} • ${transaction.walletName}${transaction.note.isEmpty ? '' : ' • ${transaction.note}'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isIncome ? '+' : '-'}${moneyText(transaction.amountCents)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'ลบ',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
