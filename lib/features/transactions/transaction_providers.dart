import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';

final transactionFilterProvider = StateProvider<TransactionFilter>((ref) {
  final now = DateTime.now();
  return TransactionFilter(month: DateTime(now.year, now.month));
});

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  ref.watch(refreshProvider);
  return ref.watch(repositoryProvider).dashboard();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.watch(refreshProvider);
  return ref.watch(repositoryProvider).getCategories();
});

final walletsProvider = FutureProvider<List<Wallet>>((ref) async {
  ref.watch(refreshProvider);
  return ref.watch(repositoryProvider).getWallets();
});

final transactionsProvider = FutureProvider<List<MoneyTransaction>>((ref) async {
  ref.watch(refreshProvider);
  final filter = ref.watch(transactionFilterProvider);
  return ref.watch(repositoryProvider).transactions(filter);
});

final monthlySummaryProvider = FutureProvider<MonthlySummary>((ref) async {
  ref.watch(refreshProvider);
  final month = ref.watch(transactionFilterProvider).month;
  return ref.watch(repositoryProvider).monthlySummary(month);
});
