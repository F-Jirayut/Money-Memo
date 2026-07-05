import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/money_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<MoneyRepository>((ref) {
  return MoneyRepository(ref.watch(databaseProvider));
});

final refreshProvider = StateProvider<int>((ref) => 0);
