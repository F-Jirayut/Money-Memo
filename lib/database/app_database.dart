import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  Future<void> initialize() async {
    await customStatement('PRAGMA foreign_keys = ON');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        balance_cents INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        amount_cents INTEGER NOT NULL,
        date TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        wallet_id INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        receipt_path TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE RESTRICT,
        FOREIGN KEY(wallet_id) REFERENCES wallets(id) ON DELETE RESTRICT
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        limit_cents INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(month, category_id),
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color_value INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS transaction_tags (
        transaction_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY(transaction_id, tag_id),
        FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
        FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        amount_cents INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        wallet_id INTEGER NOT NULL,
        day_of_month INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        last_generated_month TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE RESTRICT,
        FOREIGN KEY(wallet_id) REFERENCES wallets(id) ON DELETE RESTRICT
      )
    ''');
    await _ensureTransactionReceiptColumn();
    await _seedDefaults();
    await recalculateWalletBalances();
  }

  Future<void> _ensureTransactionReceiptColumn() async {
    final columns = await customSelect('PRAGMA table_info(transactions)').get();
    final hasReceiptPath = columns.any(
      (row) => row.read<String>('name') == 'receipt_path',
    );
    if (!hasReceiptPath) {
      await customStatement(
        "ALTER TABLE transactions ADD COLUMN receipt_path TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  Future<void> _seedDefaults() async {
    final categoryCount = await customSelect(
      'SELECT COUNT(*) AS count FROM categories',
    ).getSingle();
    final walletCount = await customSelect(
      'SELECT COUNT(*) AS count FROM wallets',
    ).getSingle();
    final now = DateTime.now().toIso8601String();
    if (categoryCount.data['count'] == 0) {
      const expense = [
        'อาหาร',
        'เดินทาง',
        'ช้อปปิ้ง',
        'บ้าน/ที่พัก',
        'สุขภาพ',
        'อินเทอร์เน็ต/โทรศัพท์',
        'บันเทิง',
        'อื่นๆ',
      ];
      const income = ['เงินเดือน', 'งานเสริม', 'โบนัส', 'การลงทุน', 'อื่นๆ'];
      for (final name in expense) {
        await customStatement(
          'INSERT INTO categories(name, type, created_at, updated_at) VALUES (?, ?, ?, ?)',
          [name, 'expense', now, now],
        );
      }
      for (final name in income) {
        await customStatement(
          'INSERT INTO categories(name, type, created_at, updated_at) VALUES (?, ?, ?, ?)',
          [name, 'income', now, now],
        );
      }
    }
    if (walletCount.data['count'] == 0) {
      for (final name in ['เงินสด', 'บัญชีธนาคาร', 'TrueMoney']) {
        await customStatement(
          'INSERT INTO wallets(name, balance_cents, created_at, updated_at) VALUES (?, 0, ?, ?)',
          [name, now, now],
        );
      }
    }
  }

  Future<void> recalculateWalletBalances() async {
    await customStatement('UPDATE wallets SET balance_cents = 0');
    await customStatement('''
      UPDATE wallets
      SET balance_cents = COALESCE((
        SELECT SUM(CASE WHEN type = 'income' THEN amount_cents ELSE -amount_cents END)
        FROM transactions
        WHERE transactions.wallet_id = wallets.id
      ), 0)
    ''');
  }

  Future<File> databaseFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'money_memo.sqlite'));
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'money_memo');
}
