import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../notifications/expense_reminder_service.dart';
import '../ocr/receipt_ocr_service.dart';
import '../security/biometric_auth_service.dart';

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

final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  ref.watch(refreshProvider);
  return ref.watch(repositoryProvider).tags();
});

final transactionTagIdsProvider = FutureProvider.family<List<int>, int>((
  ref,
  transactionId,
) async {
  ref.watch(refreshProvider);
  return ref.watch(repositoryProvider).tagIdsForTransaction(transactionId);
});

final transactionsProvider = FutureProvider<List<MoneyTransaction>>((
  ref,
) async {
  ref.watch(refreshProvider);
  final filter = ref.watch(transactionFilterProvider);
  return ref.watch(repositoryProvider).transactions(filter);
});

final monthlySummaryProvider = FutureProvider<MonthlySummary>((ref) async {
  ref.watch(refreshProvider);
  final month = ref.watch(transactionFilterProvider).month;
  return ref.watch(repositoryProvider).monthlySummary(month);
});

final transactionViewModelProvider = Provider<TransactionViewModel>((ref) {
  return TransactionViewModel(ref);
});

final receiptOcrServiceProvider = Provider<ReceiptOcrService>((ref) {
  return ReceiptOcrService();
});

final categoryViewModelProvider = Provider<CategoryViewModel>((ref) {
  return CategoryViewModel(ref);
});

final walletViewModelProvider = Provider<WalletViewModel>((ref) {
  return WalletViewModel(ref);
});

final backupViewModelProvider = Provider<BackupViewModel>((ref) {
  return BackupViewModel(ref);
});

final dataExchangeViewModelProvider = Provider<DataExchangeViewModel>((ref) {
  return DataExchangeViewModel(ref);
});

final tagViewModelProvider = Provider<TagViewModel>((ref) {
  return TagViewModel(ref);
});

final recurringTransactionsProvider =
    FutureProvider<List<RecurringTransaction>>((ref) async {
      ref.watch(refreshProvider);
      return ref.watch(repositoryProvider).recurringTransactions();
    });

final recurringViewModelProvider = Provider<RecurringViewModel>((ref) {
  return RecurringViewModel(ref);
});

final appLockSettingsProvider = FutureProvider<AppLockSettings>((ref) async {
  ref.watch(refreshProvider);
  return ref.watch(repositoryProvider).appLockSettings();
});

final reminderSettingsProvider = FutureProvider<ReminderSettings>((ref) async {
  ref.watch(refreshProvider);
  return ref.watch(repositoryProvider).reminderSettings();
});

final appLockViewModelProvider = Provider<AppLockViewModel>((ref) {
  return AppLockViewModel(ref);
});

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService();
});

final expenseReminderServiceProvider = Provider<ExpenseReminderService>((ref) {
  return ExpenseReminderService();
});

final reminderViewModelProvider = Provider<ReminderViewModel>((ref) {
  return ReminderViewModel(ref);
});

class TransactionViewModel {
  TransactionViewModel(this.ref);

  final Ref ref;

  void setFilter(TransactionFilter filter) {
    ref.read(transactionFilterProvider.notifier).state = filter;
  }

  Future<void> save({int? id, required TransactionDraft draft}) async {
    await ref.read(repositoryProvider).saveTransaction(id: id, draft: draft);
    refresh();
  }

  Future<String> storeReceiptImage(String sourcePath) {
    return ref.read(repositoryProvider).storeReceiptImage(sourcePath);
  }

  Future<ReceiptOcrResult> recognizeReceipt(String imagePath) {
    return ref.read(receiptOcrServiceProvider).recognize(imagePath);
  }

  Future<void> delete(int id) async {
    await ref.read(repositoryProvider).deleteTransaction(id);
    refresh();
  }

  void refresh() {
    ref.read(refreshProvider.notifier).state++;
  }
}

class CategoryViewModel {
  CategoryViewModel(this.ref);

  final Ref ref;

  Future<void> save({
    int? id,
    required String name,
    required TransactionType type,
  }) async {
    await ref
        .read(repositoryProvider)
        .saveCategory(id: id, name: name, type: type);
    refresh();
  }

  Future<void> delete(int id) async {
    await ref.read(repositoryProvider).deleteCategory(id);
    refresh();
  }

  void refresh() {
    ref.read(refreshProvider.notifier).state++;
  }
}

class WalletViewModel {
  WalletViewModel(this.ref);

  final Ref ref;

  Future<void> save({int? id, required String name}) async {
    await ref.read(repositoryProvider).saveWallet(id: id, name: name);
    refresh();
  }

  Future<void> delete(int id) async {
    await ref.read(repositoryProvider).deleteWallet(id);
    refresh();
  }

  void refresh() {
    ref.read(refreshProvider.notifier).state++;
  }
}

class BackupViewModel {
  BackupViewModel(this.ref);

  final Ref ref;

  Future<void> backup() async {
    final repo = ref.read(repositoryProvider);
    final file = await repo.createBackup();
    await repo.shareFile(file, 'Money Memo Backup');
  }

  Future<void> encryptedBackup(String password) async {
    final repo = ref.read(repositoryProvider);
    final file = await repo.createEncryptedBackup(password);
    await repo.shareFile(file, 'Money Memo Encrypted Backup');
  }

  Future<bool> restore() async {
    final restored = await ref.read(repositoryProvider).restoreBackup();
    if (restored) {
      ref.read(refreshProvider.notifier).state++;
    }
    return restored;
  }

  Future<bool> restoreEncrypted(String password) async {
    final restored = await ref
        .read(repositoryProvider)
        .restoreEncryptedBackup(password);
    if (restored) {
      ref.read(refreshProvider.notifier).state++;
    }
    return restored;
  }
}

class DataExchangeViewModel {
  DataExchangeViewModel(this.ref);

  final Ref ref;

  Future<void> exportCsv(DateTime start, DateTime end) async {
    final repo = ref.read(repositoryProvider);
    final file = await repo.exportCsv(start, end);
    await repo.shareFile(file, 'Money Memo CSV');
  }

  Future<void> exportExcel(DateTime start, DateTime end) async {
    final repo = ref.read(repositoryProvider);
    final file = await repo.exportExcel(start, end);
    await repo.shareFile(file, 'Money Memo Excel');
  }

  Future<void> exportPdf(DateTime start, DateTime end) async {
    final repo = ref.read(repositoryProvider);
    final file = await repo.exportPdf(start, end);
    await repo.shareFile(file, 'Money Memo PDF');
  }

  Future<ImportCsvResult> importCsv() async {
    final result = await ref.read(repositoryProvider).importCsv();
    if (result.importedCount > 0) {
      ref.read(refreshProvider.notifier).state++;
    }
    return result;
  }
}

class TagViewModel {
  TagViewModel(this.ref);

  final Ref ref;

  Future<void> save({
    int? id,
    required String name,
    required int colorValue,
  }) async {
    await ref
        .read(repositoryProvider)
        .saveTag(id: id, name: name, colorValue: colorValue);
    refresh();
  }

  Future<void> delete(int id) async {
    await ref.read(repositoryProvider).deleteTag(id);
    refresh();
  }

  void refresh() {
    ref.read(refreshProvider.notifier).state++;
  }
}

class RecurringViewModel {
  RecurringViewModel(this.ref);

  final Ref ref;

  Future<void> save({int? id, required RecurringTransactionDraft draft}) async {
    await ref
        .read(repositoryProvider)
        .saveRecurringTransaction(id: id, draft: draft);
    refresh();
  }

  Future<void> delete(int id) async {
    await ref.read(repositoryProvider).deleteRecurringTransaction(id);
    refresh();
  }

  Future<int> generate(DateTime month) async {
    final count = await ref
        .read(repositoryProvider)
        .generateRecurringTransactions(month);
    if (count > 0) refresh();
    return count;
  }

  void refresh() {
    ref.read(refreshProvider.notifier).state++;
  }
}

class AppLockViewModel {
  AppLockViewModel(this.ref);

  final Ref ref;

  Future<void> setPin(String pin) async {
    await ref.read(repositoryProvider).setPin(pin);
    refresh();
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(repositoryProvider).setPinEnabled(enabled);
    refresh();
  }

  Future<bool> isBiometricAvailable() {
    return ref.read(biometricAuthServiceProvider).isAvailable();
  }

  Future<bool> authenticateWithBiometric() {
    return ref.read(biometricAuthServiceProvider).authenticate();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await ref.read(repositoryProvider).setBiometricEnabled(enabled);
    refresh();
  }

  Future<bool> verify(String pin) {
    return ref.read(repositoryProvider).verifyPin(pin);
  }

  void refresh() {
    ref.read(refreshProvider.notifier).state++;
  }
}

class ReminderViewModel {
  ReminderViewModel(this.ref);

  final Ref ref;

  Future<void> save(ReminderSettings settings) async {
    await ref.read(repositoryProvider).saveReminderSettings(settings);
    if (settings.enabled) {
      await ref
          .read(expenseReminderServiceProvider)
          .scheduleDaily(hour: settings.hour, minute: settings.minute);
    } else {
      await ref.read(expenseReminderServiceProvider).cancel();
    }
    refresh();
  }

  Future<void> showTest() {
    return ref.read(expenseReminderServiceProvider).showTest();
  }

  void refresh() {
    ref.read(refreshProvider.notifier).state++;
  }
}
