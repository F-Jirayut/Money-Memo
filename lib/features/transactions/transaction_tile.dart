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
    final color = isIncome
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.error;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          isIncome ? Icons.trending_up : Icons.trending_down,
          color: color,
        ),
      ),
      title: Text(transaction.categoryName, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${dateText(transaction.date)} • ${transaction.walletName}${transaction.note.isEmpty ? '' : ' • ${transaction.note}'}${transaction.tagNames.isEmpty ? '' : ' • #${transaction.tagNames.join(' #')}'}',
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
          if (transaction.receiptPath.isNotEmpty)
            Icon(
              Icons.image_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
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
