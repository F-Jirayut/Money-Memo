enum TransactionType {
  income('income', 'รายรับ'),
  expense('expense', 'รายจ่าย');

  const TransactionType(this.value, this.label);
  final String value;
  final String label;

  static TransactionType fromValue(String value) =>
      value == income.value ? income : expense;
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
  });

  final int id;
  final String name;
  final TransactionType type;
}

class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.balanceCents,
  });

  final int id;
  final String name;
  final int balanceCents;
}

class MoneyTransaction {
  const MoneyTransaction({
    required this.id,
    required this.type,
    required this.amountCents,
    required this.date,
    required this.categoryId,
    required this.walletId,
    required this.categoryName,
    required this.walletName,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final TransactionType type;
  final int amountCents;
  final DateTime date;
  final int categoryId;
  final int walletId;
  final String categoryName;
  final String walletName;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.amountCents,
    required this.date,
    required this.categoryId,
    required this.walletId,
    required this.note,
  });

  final TransactionType type;
  final int amountCents;
  final DateTime date;
  final int categoryId;
  final int walletId;
  final String note;
}

class TransactionFilter {
  const TransactionFilter({
    required this.month,
    this.type,
    this.categoryId,
    this.walletId,
    this.search = '',
  });

  final DateTime month;
  final TransactionType? type;
  final int? categoryId;
  final int? walletId;
  final String search;

  TransactionFilter copyWith({
    DateTime? month,
    TransactionType? type,
    bool clearType = false,
    int? categoryId,
    bool clearCategory = false,
    int? walletId,
    bool clearWallet = false,
    String? search,
  }) {
    return TransactionFilter(
      month: month ?? this.month,
      type: clearType ? null : type ?? this.type,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      walletId: clearWallet ? null : walletId ?? this.walletId,
      search: search ?? this.search,
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalBalanceCents,
    required this.monthIncomeCents,
    required this.monthExpenseCents,
    required this.latestTransactions,
  });

  final int totalBalanceCents;
  final int monthIncomeCents;
  final int monthExpenseCents;
  final List<MoneyTransaction> latestTransactions;
}

class MonthlySummary {
  const MonthlySummary({
    required this.incomeCents,
    required this.expenseCents,
    required this.expenseByCategory,
  });

  final int incomeCents;
  final int expenseCents;
  final Map<String, int> expenseByCategory;
  int get netCents => incomeCents - expenseCents;
}
