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
  const Category({required this.id, required this.name, required this.type});

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
    required this.receiptPath,
    required this.tagNames,
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
  final String receiptPath;
  final List<String> tagNames;
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
    required this.receiptPath,
    this.tagIds = const [],
  });

  final TransactionType type;
  final int amountCents;
  final DateTime date;
  final int categoryId;
  final int walletId;
  final String note;
  final String receiptPath;
  final List<int> tagIds;
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
    required this.expenseByCategory,
  });

  final int totalBalanceCents;
  final int monthIncomeCents;
  final int monthExpenseCents;
  final List<MoneyTransaction> latestTransactions;
  final Map<String, int> expenseByCategory;
}

class MonthlySummary {
  const MonthlySummary({
    required this.incomeCents,
    required this.expenseCents,
    required this.expenseByCategory,
    required this.expenseByWallet,
    required this.trend,
  });

  final int incomeCents;
  final int expenseCents;
  final Map<String, int> expenseByCategory;
  final Map<String, int> expenseByWallet;
  final List<MonthlyTrend> trend;
  int get netCents => incomeCents - expenseCents;
}

class MonthlyTrend {
  const MonthlyTrend({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
  });

  final DateTime month;
  final int incomeCents;
  final int expenseCents;
  int get netCents => incomeCents - expenseCents;
}

class BudgetSummary {
  const BudgetSummary({
    required this.id,
    required this.month,
    required this.categoryId,
    required this.categoryName,
    required this.limitCents,
    required this.spentCents,
  });

  final int id;
  final DateTime month;
  final int categoryId;
  final String categoryName;
  final int limitCents;
  final int spentCents;

  int get remainingCents => limitCents - spentCents;
  double get progress =>
      limitCents <= 0 ? 0 : (spentCents / limitCents).clamp(0, 1);
  bool get isOverBudget => spentCents > limitCents;
}

class BudgetDraft {
  const BudgetDraft({
    required this.month,
    required this.categoryId,
    required this.limitCents,
  });

  final DateTime month;
  final int categoryId;
  final int limitCents;
}

class ImportCsvResult {
  const ImportCsvResult({
    required this.importedCount,
    required this.skippedCount,
  });

  final int importedCount;
  final int skippedCount;
}

class Tag {
  const Tag({required this.id, required this.name, required this.colorValue});

  final int id;
  final String name;
  final int colorValue;
}

class AppLockSettings {
  const AppLockSettings({
    required this.enabled,
    required this.hasPin,
    required this.biometricEnabled,
  });

  final bool enabled;
  final bool hasPin;
  final bool biometricEnabled;
}

class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;
}

class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.name,
    required this.type,
    required this.amountCents,
    required this.categoryId,
    required this.walletId,
    required this.categoryName,
    required this.walletName,
    required this.dayOfMonth,
    required this.note,
    required this.isActive,
    required this.lastGeneratedMonth,
  });

  final int id;
  final String name;
  final TransactionType type;
  final int amountCents;
  final int categoryId;
  final int walletId;
  final String categoryName;
  final String walletName;
  final int dayOfMonth;
  final String note;
  final bool isActive;
  final String lastGeneratedMonth;
}

class RecurringTransactionDraft {
  const RecurringTransactionDraft({
    required this.name,
    required this.type,
    required this.amountCents,
    required this.categoryId,
    required this.walletId,
    required this.dayOfMonth,
    required this.note,
    required this.isActive,
  });

  final String name;
  final TransactionType type;
  final int amountCents;
  final int categoryId;
  final int walletId;
  final int dayOfMonth;
  final String note;
  final bool isActive;
}
