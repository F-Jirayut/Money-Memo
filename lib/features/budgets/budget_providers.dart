import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../transactions/transaction_providers.dart';

final budgetsProvider = FutureProvider<List<BudgetSummary>>((ref) async {
  ref.watch(refreshProvider);
  final month = ref.watch(transactionFilterProvider).month;
  return ref.watch(repositoryProvider).budgets(month);
});

final budgetViewModelProvider = Provider<BudgetViewModel>((ref) {
  return BudgetViewModel(ref);
});

class BudgetViewModel {
  BudgetViewModel(this.ref);

  final Ref ref;

  void setMonth(DateTime month) {
    final filter = ref.read(transactionFilterProvider);
    ref.read(transactionFilterProvider.notifier).state = filter.copyWith(
      month: DateTime(month.year, month.month),
    );
  }

  Future<void> save({int? id, required BudgetDraft draft}) async {
    await ref.read(repositoryProvider).saveBudget(id: id, draft: draft);
    refresh();
  }

  Future<void> delete(int id) async {
    await ref.read(repositoryProvider).deleteBudget(id);
    refresh();
  }

  void refresh() {
    ref.read(refreshProvider.notifier).state++;
  }
}
