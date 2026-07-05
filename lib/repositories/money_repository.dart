import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/formatters.dart';
import '../core/models.dart';
import '../database/app_database.dart';

class MoneyRepository {
  MoneyRepository(this.db);

  final AppDatabase db;
  bool _ready = false;

  Future<void> ensureReady() async {
    if (_ready) return;
    await db.initialize();
    _ready = true;
  }

  Future<DashboardSummary> dashboard() async {
    await ensureReady();
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final wallets = await getWallets();
    final totals = await _monthTotals(month);
    final latest = await transactions(
      TransactionFilter(month: month),
      limit: 5,
      ignoreMonth: true,
    );
    return DashboardSummary(
      totalBalanceCents: wallets.fold(0, (sum, wallet) => sum + wallet.balanceCents),
      monthIncomeCents: totals.$1,
      monthExpenseCents: totals.$2,
      latestTransactions: latest,
    );
  }

  Future<List<Category>> getCategories([TransactionType? type]) async {
    await ensureReady();
    final sql = StringBuffer('SELECT * FROM categories');
    final vars = <Variable>[];
    if (type != null) {
      sql.write(' WHERE type = ?');
      vars.add(Variable(type.value));
    }
    sql.write(' ORDER BY type, name');
    final rows = await db.customSelect(sql.toString(), variables: vars).get();
    return rows.map((row) {
      return Category(
        id: row.read<int>('id'),
        name: row.read<String>('name'),
        type: TransactionType.fromValue(row.read<String>('type')),
      );
    }).toList();
  }

  Future<List<Wallet>> getWallets() async {
    await ensureReady();
    final rows = await db.customSelect('SELECT * FROM wallets ORDER BY id').get();
    return rows.map((row) {
      return Wallet(
        id: row.read<int>('id'),
        name: row.read<String>('name'),
        balanceCents: row.read<int>('balance_cents'),
      );
    }).toList();
  }

  Future<void> saveCategory({int? id, required String name, required TransactionType type}) async {
    await ensureReady();
    final now = DateTime.now().toIso8601String();
    if (id == null) {
      await db.customStatement(
        'INSERT INTO categories(name, type, created_at, updated_at) VALUES (?, ?, ?, ?)',
        [name, type.value, now, now],
      );
    } else {
      await db.customStatement(
        'UPDATE categories SET name = ?, type = ?, updated_at = ? WHERE id = ?',
        [name, type.value, now, id],
      );
    }
  }

  Future<void> deleteCategory(int id) async {
    await ensureReady();
    await db.customStatement('DELETE FROM categories WHERE id = ?', [id]);
  }

  Future<void> saveWallet({int? id, required String name}) async {
    await ensureReady();
    final now = DateTime.now().toIso8601String();
    if (id == null) {
      await db.customStatement(
        'INSERT INTO wallets(name, balance_cents, created_at, updated_at) VALUES (?, 0, ?, ?)',
        [name, now, now],
      );
    } else {
      await db.customStatement(
        'UPDATE wallets SET name = ?, updated_at = ? WHERE id = ?',
        [name, now, id],
      );
    }
  }

  Future<void> deleteWallet(int id) async {
    await ensureReady();
    await db.customStatement('DELETE FROM wallets WHERE id = ?', [id]);
  }

  Future<void> saveTransaction({int? id, required TransactionDraft draft}) async {
    await ensureReady();
    final now = DateTime.now().toIso8601String();
    await db.transaction(() async {
      if (id == null) {
        await db.customStatement(
          '''
          INSERT INTO transactions(type, amount_cents, date, category_id, wallet_id, note, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            draft.type.value,
            draft.amountCents,
            draft.date.toIso8601String(),
            draft.categoryId,
            draft.walletId,
            draft.note,
            now,
            now,
          ],
        );
      } else {
        await db.customStatement(
          '''
          UPDATE transactions
          SET type = ?, amount_cents = ?, date = ?, category_id = ?, wallet_id = ?, note = ?, updated_at = ?
          WHERE id = ?
          ''',
          [
            draft.type.value,
            draft.amountCents,
            draft.date.toIso8601String(),
            draft.categoryId,
            draft.walletId,
            draft.note,
            now,
            id,
          ],
        );
      }
      await db.recalculateWalletBalances();
    });
  }

  Future<void> deleteTransaction(int id) async {
    await ensureReady();
    await db.transaction(() async {
      await db.customStatement('DELETE FROM transactions WHERE id = ?', [id]);
      await db.recalculateWalletBalances();
    });
  }

  Future<List<MoneyTransaction>> transactions(
    TransactionFilter filter, {
    int? limit,
    bool ignoreMonth = false,
  }) async {
    await ensureReady();
    final where = <String>[];
    final vars = <Variable>[];
    if (!ignoreMonth) {
      final start = DateTime(filter.month.year, filter.month.month);
      final end = DateTime(filter.month.year, filter.month.month + 1);
      where.add('t.date >= ? AND t.date < ?');
      vars.addAll([Variable(start.toIso8601String()), Variable(end.toIso8601String())]);
    }
    if (filter.type != null) {
      where.add('t.type = ?');
      vars.add(Variable(filter.type!.value));
    }
    if (filter.categoryId != null) {
      where.add('t.category_id = ?');
      vars.add(Variable(filter.categoryId));
    }
    if (filter.walletId != null) {
      where.add('t.wallet_id = ?');
      vars.add(Variable(filter.walletId));
    }
    if (filter.search.trim().isNotEmpty) {
      where.add('t.note LIKE ?');
      vars.add(Variable('%${filter.search.trim()}%'));
    }
    final sql = StringBuffer('''
      SELECT t.*, c.name AS category_name, w.name AS wallet_name
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      JOIN wallets w ON w.id = t.wallet_id
    ''');
    if (where.isNotEmpty) {
      sql.write(' WHERE ${where.join(' AND ')}');
    }
    sql.write(' ORDER BY t.date DESC, t.id DESC');
    if (limit != null) {
      sql.write(' LIMIT $limit');
    }
    final rows = await db.customSelect(sql.toString(), variables: vars).get();
    return rows.map(_transactionFromRow).toList();
  }

  Future<MonthlySummary> monthlySummary(DateTime month) async {
    await ensureReady();
    final totals = await _monthTotals(month);
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final rows = await db.customSelect(
      '''
      SELECT c.name, SUM(t.amount_cents) AS total
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.type = 'expense' AND t.date >= ? AND t.date < ?
      GROUP BY c.name
      ORDER BY total DESC
      ''',
      variables: [Variable(start.toIso8601String()), Variable(end.toIso8601String())],
    ).get();
    return MonthlySummary(
      incomeCents: totals.$1,
      expenseCents: totals.$2,
      expenseByCategory: {
        for (final row in rows) row.read<String>('name'): row.read<int>('total'),
      },
    );
  }

  Future<File> exportCsv(DateTime start, DateTime end) async {
    await ensureReady();
    final rows = await db.customSelect(
      '''
      SELECT t.date, t.type, t.amount_cents, c.name AS category, w.name AS wallet, t.note
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      JOIN wallets w ON w.id = t.wallet_id
      WHERE t.date >= ? AND t.date <= ?
      ORDER BY t.date ASC
      ''',
      variables: [Variable(start.toIso8601String()), Variable(end.toIso8601String())],
    ).get();
    final buffer = StringBuffer('date,type,amount,category,wallet,note\n');
    for (final row in rows) {
      buffer.writeln([
        inputDateText(DateTime.parse(row.read<String>('date'))),
        row.read<String>('type'),
        (row.read<int>('amount_cents') / 100).toStringAsFixed(2),
        _csv(row.read<String>('category')),
        _csv(row.read<String>('wallet')),
        _csv(row.read<String>('note')),
      ].join(','));
    }
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'money_memo_${inputDateText(start)}_${inputDateText(end)}.csv'));
    await file.writeAsString(buffer.toString());
    return file;
  }

  Future<void> shareFile(File file, String subject) async {
    await Share.shareXFiles([XFile(file.path)], subject: subject);
  }

  Future<File> createBackup() async {
    await ensureReady();
    final source = await db.databaseFile();
    final dir = await getTemporaryDirectory();
    final backup = File(p.join(dir.path, 'money_memo_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite'));
    return source.copy(backup.path);
  }

  Future<bool> restoreBackup() async {
    await ensureReady();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sqlite', 'db', 'backup'],
    );
    final path = result?.files.single.path;
    if (path == null) return false;
    final target = await db.databaseFile();
    await db.close();
    await File(path).copy(target.path);
    _ready = false;
    return true;
  }

  Future<(int, int)> _monthTotals(DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final rows = await db.customSelect(
      '''
      SELECT type, SUM(amount_cents) AS total
      FROM transactions
      WHERE date >= ? AND date < ?
      GROUP BY type
      ''',
      variables: [Variable(start.toIso8601String()), Variable(end.toIso8601String())],
    ).get();
    var income = 0;
    var expense = 0;
    for (final row in rows) {
      if (row.read<String>('type') == 'income') {
        income = row.read<int>('total');
      } else {
        expense = row.read<int>('total');
      }
    }
    return (income, expense);
  }

  MoneyTransaction _transactionFromRow(QueryRow row) {
    return MoneyTransaction(
      id: row.read<int>('id'),
      type: TransactionType.fromValue(row.read<String>('type')),
      amountCents: row.read<int>('amount_cents'),
      date: DateTime.parse(row.read<String>('date')),
      categoryId: row.read<int>('category_id'),
      walletId: row.read<int>('wallet_id'),
      categoryName: row.read<String>('category_name'),
      walletName: row.read<String>('wallet_name'),
      note: row.read<String>('note'),
      createdAt: DateTime.parse(row.read<String>('created_at')),
      updatedAt: DateTime.parse(row.read<String>('updated_at')),
    );
  }

  String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
