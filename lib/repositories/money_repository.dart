import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
      totalBalanceCents: wallets.fold(
        0,
        (sum, wallet) => sum + wallet.balanceCents,
      ),
      monthIncomeCents: totals.$1,
      monthExpenseCents: totals.$2,
      latestTransactions: latest,
      expenseByCategory: await _expenseByCategory(month),
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
    final rows = await db
        .customSelect('SELECT * FROM wallets ORDER BY id')
        .get();
    return rows.map((row) {
      return Wallet(
        id: row.read<int>('id'),
        name: row.read<String>('name'),
        balanceCents: row.read<int>('balance_cents'),
      );
    }).toList();
  }

  Future<void> saveCategory({
    int? id,
    required String name,
    required TransactionType type,
  }) async {
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

  Future<void> saveTransaction({
    int? id,
    required TransactionDraft draft,
  }) async {
    await ensureReady();
    final now = DateTime.now().toIso8601String();
    await db.transaction(() async {
      if (id == null) {
        await db.customStatement(
          '''
          INSERT INTO transactions(type, amount_cents, date, category_id, wallet_id, note, receipt_path, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            draft.type.value,
            draft.amountCents,
            draft.date.toIso8601String(),
            draft.categoryId,
            draft.walletId,
            draft.note,
            draft.receiptPath,
            now,
            now,
          ],
        );
        final created = await db
            .customSelect('SELECT last_insert_rowid() AS id')
            .getSingle();
        await _syncTransactionTags(created.read<int>('id'), draft.tagIds);
      } else {
        await db.customStatement(
          '''
          UPDATE transactions
          SET type = ?, amount_cents = ?, date = ?, category_id = ?, wallet_id = ?, note = ?, receipt_path = ?, updated_at = ?
          WHERE id = ?
          ''',
          [
            draft.type.value,
            draft.amountCents,
            draft.date.toIso8601String(),
            draft.categoryId,
            draft.walletId,
            draft.note,
            draft.receiptPath,
            now,
            id,
          ],
        );
        await _syncTransactionTags(id, draft.tagIds);
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
      vars.addAll([
        Variable(start.toIso8601String()),
        Variable(end.toIso8601String()),
      ]);
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
      SELECT t.*, c.name AS category_name, w.name AS wallet_name,
        COALESCE((
          SELECT GROUP_CONCAT(tags.name, ', ')
          FROM transaction_tags tt
          JOIN tags ON tags.id = tt.tag_id
          WHERE tt.transaction_id = t.id
        ), '') AS tag_names
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
    return MonthlySummary(
      incomeCents: totals.$1,
      expenseCents: totals.$2,
      expenseByCategory: await _expenseByCategory(month),
      expenseByWallet: await _expenseByWallet(month),
      trend: await _monthlyTrend(month),
    );
  }

  Future<List<BudgetSummary>> budgets(DateTime month) async {
    await ensureReady();
    final monthStart = DateTime(month.year, month.month);
    final monthKey = inputDateText(monthStart);
    final nextMonth = DateTime(month.year, month.month + 1);
    final rows = await db
        .customSelect(
          '''
      SELECT b.id, b.month, b.category_id, b.limit_cents, c.name AS category_name,
        COALESCE((
          SELECT SUM(t.amount_cents)
          FROM transactions t
          WHERE t.type = 'expense'
            AND t.category_id = b.category_id
            AND t.date >= ?
            AND t.date < ?
        ), 0) AS spent_cents
      FROM budgets b
      JOIN categories c ON c.id = b.category_id
      WHERE b.month = ?
      ORDER BY c.name
      ''',
          variables: [
            Variable(monthStart.toIso8601String()),
            Variable(nextMonth.toIso8601String()),
            Variable(monthKey),
          ],
        )
        .get();
    return rows.map((row) {
      return BudgetSummary(
        id: row.read<int>('id'),
        month: DateTime.parse(row.read<String>('month')),
        categoryId: row.read<int>('category_id'),
        categoryName: row.read<String>('category_name'),
        limitCents: row.read<int>('limit_cents'),
        spentCents: row.read<int>('spent_cents'),
      );
    }).toList();
  }

  Future<void> saveBudget({int? id, required BudgetDraft draft}) async {
    await ensureReady();
    final now = DateTime.now().toIso8601String();
    final month = inputDateText(DateTime(draft.month.year, draft.month.month));
    if (id == null) {
      await db.customStatement(
        '''
        INSERT INTO budgets(month, category_id, limit_cents, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(month, category_id)
        DO UPDATE SET limit_cents = excluded.limit_cents, updated_at = excluded.updated_at
        ''',
        [month, draft.categoryId, draft.limitCents, now, now],
      );
    } else {
      await db.customStatement(
        'UPDATE budgets SET month = ?, category_id = ?, limit_cents = ?, updated_at = ? WHERE id = ?',
        [month, draft.categoryId, draft.limitCents, now, id],
      );
    }
  }

  Future<void> deleteBudget(int id) async {
    await ensureReady();
    await db.customStatement('DELETE FROM budgets WHERE id = ?', [id]);
  }

  Future<ImportCsvResult> importCsv() async {
    await ensureReady();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = result?.files.single.path;
    if (path == null) {
      return const ImportCsvResult(importedCount: 0, skippedCount: 0);
    }
    final lines = await File(path).readAsLines();
    var imported = 0;
    var skipped = 0;
    await db.transaction(() async {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final cells = _parseCsvLine(line);
        if (i == 0 && cells.isNotEmpty && cells.first.toLowerCase() == 'date') {
          continue;
        }
        if (cells.length < 6) {
          skipped++;
          continue;
        }
        final date = DateTime.tryParse(cells[0]);
        final type = cells[1] == 'income'
            ? TransactionType.income
            : cells[1] == 'expense'
            ? TransactionType.expense
            : null;
        final amountCents = parseBahtToCents(cells[2]);
        if (date == null || type == null || amountCents <= 0) {
          skipped++;
          continue;
        }
        final categoryId = await _categoryIdByName(cells[3], type);
        final walletId = await _walletIdByName(cells[4]);
        final now = DateTime.now().toIso8601String();
        await db.customStatement(
          '''
          INSERT INTO transactions(type, amount_cents, date, category_id, wallet_id, note, receipt_path, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, '', ?, ?)
          ''',
          [
            type.value,
            amountCents,
            date.toIso8601String(),
            categoryId,
            walletId,
            cells[5],
            now,
            now,
          ],
        );
        imported++;
      }
      await db.recalculateWalletBalances();
    });
    return ImportCsvResult(importedCount: imported, skippedCount: skipped);
  }

  Future<List<Tag>> tags() async {
    await ensureReady();
    final rows = await db
        .customSelect('SELECT * FROM tags ORDER BY name')
        .get();
    return rows.map((row) {
      return Tag(
        id: row.read<int>('id'),
        name: row.read<String>('name'),
        colorValue: row.read<int>('color_value'),
      );
    }).toList();
  }

  Future<List<int>> tagIdsForTransaction(int transactionId) async {
    await ensureReady();
    final rows = await db
        .customSelect(
          'SELECT tag_id FROM transaction_tags WHERE transaction_id = ?',
          variables: [Variable(transactionId)],
        )
        .get();
    return rows.map((row) => row.read<int>('tag_id')).toList();
  }

  Future<void> saveTag({
    int? id,
    required String name,
    required int colorValue,
  }) async {
    await ensureReady();
    final now = DateTime.now().toIso8601String();
    if (id == null) {
      await db.customStatement(
        'INSERT INTO tags(name, color_value, created_at, updated_at) VALUES (?, ?, ?, ?)',
        [name, colorValue, now, now],
      );
    } else {
      await db.customStatement(
        'UPDATE tags SET name = ?, color_value = ?, updated_at = ? WHERE id = ?',
        [name, colorValue, now, id],
      );
    }
  }

  Future<void> deleteTag(int id) async {
    await ensureReady();
    await db.customStatement('DELETE FROM tags WHERE id = ?', [id]);
  }

  Future<List<RecurringTransaction>> recurringTransactions() async {
    await ensureReady();
    final rows = await db.customSelect('''
      SELECT r.*, c.name AS category_name, w.name AS wallet_name
      FROM recurring_transactions r
      JOIN categories c ON c.id = r.category_id
      JOIN wallets w ON w.id = r.wallet_id
      ORDER BY r.is_active DESC, r.day_of_month, r.name
      ''').get();
    return rows.map((row) {
      return RecurringTransaction(
        id: row.read<int>('id'),
        name: row.read<String>('name'),
        type: TransactionType.fromValue(row.read<String>('type')),
        amountCents: row.read<int>('amount_cents'),
        categoryId: row.read<int>('category_id'),
        walletId: row.read<int>('wallet_id'),
        categoryName: row.read<String>('category_name'),
        walletName: row.read<String>('wallet_name'),
        dayOfMonth: row.read<int>('day_of_month'),
        note: row.read<String>('note'),
        isActive: row.read<int>('is_active') == 1,
        lastGeneratedMonth: row.read<String>('last_generated_month'),
      );
    }).toList();
  }

  Future<void> saveRecurringTransaction({
    int? id,
    required RecurringTransactionDraft draft,
  }) async {
    await ensureReady();
    final now = DateTime.now().toIso8601String();
    if (id == null) {
      await db.customStatement(
        '''
        INSERT INTO recurring_transactions(name, type, amount_cents, category_id, wallet_id, day_of_month, note, is_active, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          draft.name,
          draft.type.value,
          draft.amountCents,
          draft.categoryId,
          draft.walletId,
          draft.dayOfMonth,
          draft.note,
          draft.isActive ? 1 : 0,
          now,
          now,
        ],
      );
    } else {
      await db.customStatement(
        '''
        UPDATE recurring_transactions
        SET name = ?, type = ?, amount_cents = ?, category_id = ?, wallet_id = ?, day_of_month = ?, note = ?, is_active = ?, updated_at = ?
        WHERE id = ?
        ''',
        [
          draft.name,
          draft.type.value,
          draft.amountCents,
          draft.categoryId,
          draft.walletId,
          draft.dayOfMonth,
          draft.note,
          draft.isActive ? 1 : 0,
          now,
          id,
        ],
      );
    }
  }

  Future<void> deleteRecurringTransaction(int id) async {
    await ensureReady();
    await db.customStatement(
      'DELETE FROM recurring_transactions WHERE id = ?',
      [id],
    );
  }

  Future<int> generateRecurringTransactions(DateTime month) async {
    await ensureReady();
    final monthStart = DateTime(month.year, month.month);
    final monthKey = inputDateText(monthStart);
    final templates = await recurringTransactions();
    var generated = 0;
    await db.transaction(() async {
      for (final item in templates.where((item) => item.isActive)) {
        if (item.lastGeneratedMonth == monthKey) continue;
        final lastDay = DateTime(month.year, month.month + 1, 0).day;
        final day = item.dayOfMonth.clamp(1, lastDay);
        final date = DateTime(month.year, month.month, day);
        final now = DateTime.now().toIso8601String();
        final note = item.note.isEmpty ? 'Recurring: ${item.name}' : item.note;
        await db.customStatement(
          '''
          INSERT INTO transactions(type, amount_cents, date, category_id, wallet_id, note, receipt_path, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, '', ?, ?)
          ''',
          [
            item.type.value,
            item.amountCents,
            date.toIso8601String(),
            item.categoryId,
            item.walletId,
            note,
            now,
            now,
          ],
        );
        await db.customStatement(
          'UPDATE recurring_transactions SET last_generated_month = ?, updated_at = ? WHERE id = ?',
          [monthKey, now, item.id],
        );
        generated++;
      }
      await db.recalculateWalletBalances();
    });
    return generated;
  }

  Future<AppLockSettings> appLockSettings() async {
    await ensureReady();
    final enabled = await _setting('pin_enabled') == 'true';
    final hasPin = (await _setting('pin_hash')).isNotEmpty;
    final biometricEnabled = await _setting('biometric_enabled') == 'true';
    return AppLockSettings(
      enabled: enabled,
      hasPin: hasPin,
      biometricEnabled: biometricEnabled,
    );
  }

  Future<void> setPin(String pin) async {
    await ensureReady();
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    await _setSetting('pin_salt', salt);
    await _setSetting('pin_hash', _pinHash(pin, salt));
    await _setSetting('pin_enabled', 'true');
  }

  Future<void> setPinEnabled(bool enabled) async {
    await ensureReady();
    await _setSetting('pin_enabled', enabled ? 'true' : 'false');
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await ensureReady();
    await _setSetting('biometric_enabled', enabled ? 'true' : 'false');
  }

  Future<bool> verifyPin(String pin) async {
    await ensureReady();
    final salt = await _setting('pin_salt');
    final hash = await _setting('pin_hash');
    return hash.isNotEmpty && _pinHash(pin, salt) == hash;
  }

  Future<ReminderSettings> reminderSettings() async {
    await ensureReady();
    final enabled = await _setting('expense_reminder_enabled') == 'true';
    final hour = int.tryParse(await _setting('expense_reminder_hour')) ?? 20;
    final minute = int.tryParse(await _setting('expense_reminder_minute')) ?? 0;
    return ReminderSettings(
      enabled: enabled,
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
    );
  }

  Future<void> saveReminderSettings(ReminderSettings settings) async {
    await ensureReady();
    await _setSetting(
      'expense_reminder_enabled',
      settings.enabled ? 'true' : 'false',
    );
    await _setSetting('expense_reminder_hour', settings.hour.toString());
    await _setSetting('expense_reminder_minute', settings.minute.toString());
  }

  Future<File> exportCsv(DateTime start, DateTime end) async {
    await ensureReady();
    final rows = await _exportRows(start, end);
    final buffer = StringBuffer('date,type,amount,category,wallet,note\n');
    for (final row in rows) {
      buffer.writeln(
        [
          inputDateText(row.date),
          row.type,
          (row.amountCents / 100).toStringAsFixed(2),
          _csv(row.category),
          _csv(row.wallet),
          _csv(row.note),
        ].join(','),
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(
        dir.path,
        'money_memo_${inputDateText(start)}_${inputDateText(end)}.csv',
      ),
    );
    await file.writeAsString(buffer.toString());
    return file;
  }

  Future<File> exportExcel(DateTime start, DateTime end) async {
    await ensureReady();
    final rows = await _exportRows(start, end);
    final excel = xls.Excel.createExcel();
    final sheet = excel['Transactions'];
    excel.setDefaultSheet('Transactions');
    sheet.appendRow([
      xls.TextCellValue('date'),
      xls.TextCellValue('type'),
      xls.TextCellValue('amount'),
      xls.TextCellValue('category'),
      xls.TextCellValue('wallet'),
      xls.TextCellValue('note'),
    ]);
    for (final row in rows) {
      sheet.appendRow([
        xls.TextCellValue(inputDateText(row.date)),
        xls.TextCellValue(row.type),
        xls.DoubleCellValue(row.amountCents / 100),
        xls.TextCellValue(row.category),
        xls.TextCellValue(row.wallet),
        xls.TextCellValue(row.note),
      ]);
    }
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Cannot create Excel file');
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(
        dir.path,
        'money_memo_${inputDateText(start)}_${inputDateText(end)}.xlsx',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> exportPdf(DateTime start, DateTime end) async {
    await ensureReady();
    final rows = await _exportRows(start, end);
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansThai-Regular.ttf',
    );
    final font = pw.Font.ttf(fontData);
    final doc = pw.Document();
    final income = rows
        .where((row) => row.type == TransactionType.income.value)
        .fold(0, (sum, row) => sum + row.amountCents);
    final expense = rows
        .where((row) => row.type == TransactionType.expense.value)
        .fold(0, (sum, row) => sum + row.amountCents);
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(base: font),
        ),
        build: (context) => [
          pw.Text(
            'Money Memo',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'ช่วงวันที่ ${inputDateText(start)} ถึง ${inputDateText(end)}',
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('รายรับ ${moneyText(income)}'),
              pw.Text('รายจ่าย ${moneyText(expense)}'),
              pw.Text('สุทธิ ${moneyText(income - expense)}'),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: [
              'วันที่',
              'ประเภท',
              'จำนวน',
              'หมวด',
              'กระเป๋า',
              'หมายเหตุ',
            ],
            data: rows.map((row) {
              return [
                inputDateText(row.date),
                TransactionType.fromValue(row.type).label,
                moneyText(row.amountCents),
                row.category,
                row.wallet,
                row.note,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerAlignments: {2: pw.Alignment.centerRight},
            cellAlignments: {2: pw.Alignment.centerRight},
          ),
        ],
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(
        dir.path,
        'money_memo_${inputDateText(start)}_${inputDateText(end)}.pdf',
      ),
    );
    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  Future<String> storeReceiptImage(String sourcePath) async {
    await ensureReady();
    final source = File(sourcePath);
    if (!await source.exists()) return sourcePath;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'receipts'));
    await dir.create(recursive: true);
    final extension = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final target = File(
      p.join(
        dir.path,
        'receipt_${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    await source.copy(target.path);
    return target.path;
  }

  Future<void> shareFile(File file, String subject) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: subject),
    );
  }

  Future<List<_ExportTransactionRow>> _exportRows(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await db
        .customSelect(
          '''
      SELECT t.date, t.type, t.amount_cents, c.name AS category, w.name AS wallet, t.note
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      JOIN wallets w ON w.id = t.wallet_id
      WHERE t.date >= ? AND t.date <= ?
      ORDER BY t.date ASC
      ''',
          variables: [
            Variable(start.toIso8601String()),
            Variable(end.toIso8601String()),
          ],
        )
        .get();
    return rows.map((row) {
      return _ExportTransactionRow(
        date: DateTime.parse(row.read<String>('date')),
        type: row.read<String>('type'),
        amountCents: row.read<int>('amount_cents'),
        category: row.read<String>('category'),
        wallet: row.read<String>('wallet'),
        note: row.read<String>('note'),
      );
    }).toList();
  }

  Future<File> createBackup() async {
    await ensureReady();
    final source = await db.databaseFile();
    final dir = await getTemporaryDirectory();
    final backup = File(
      p.join(
        dir.path,
        'money_memo_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite',
      ),
    );
    return source.copy(backup.path);
  }

  Future<File> createEncryptedBackup(String password) async {
    await ensureReady();
    final source = await db.databaseFile();
    final payload = await source.readAsBytes();
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final secretKey = await _backupKey(password, salt);
    final box = await AesGcm.with256bits().encrypt(
      payload,
      secretKey: secretKey,
      nonce: nonce,
    );
    final encoded = jsonEncode({
      'version': 1,
      'algorithm': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': 120000,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'cipherText': base64Encode(box.cipherText),
    });
    final dir = await getTemporaryDirectory();
    final backup = File(
      p.join(
        dir.path,
        'money_memo_backup_${DateTime.now().millisecondsSinceEpoch}.mmenc',
      ),
    );
    await backup.writeAsString(encoded, flush: true);
    return backup;
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

  Future<bool> restoreEncryptedBackup(String password) async {
    await ensureReady();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mmenc'],
    );
    final path = result?.files.single.path;
    if (path == null) return false;
    final data =
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    if (data['version'] != 1 || data['algorithm'] != 'AES-256-GCM') {
      throw const FormatException('Unsupported encrypted backup format');
    }
    final salt = base64Decode(data['salt'] as String);
    final nonce = base64Decode(data['nonce'] as String);
    final mac = Mac(base64Decode(data['mac'] as String));
    final cipherText = base64Decode(data['cipherText'] as String);
    final secretKey = await _backupKey(password, salt);
    final bytes = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: secretKey,
    );
    final target = await db.databaseFile();
    await db.close();
    await File(target.path).writeAsBytes(bytes, flush: true);
    _ready = false;
    return true;
  }

  Future<(int, int)> _monthTotals(DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final rows = await db
        .customSelect(
          '''
      SELECT type, SUM(amount_cents) AS total
      FROM transactions
      WHERE date >= ? AND date < ?
      GROUP BY type
      ''',
          variables: [
            Variable(start.toIso8601String()),
            Variable(end.toIso8601String()),
          ],
        )
        .get();
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

  Future<Map<String, int>> _expenseByCategory(DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final rows = await db
        .customSelect(
          '''
      SELECT c.name, SUM(t.amount_cents) AS total
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.type = 'expense' AND t.date >= ? AND t.date < ?
      GROUP BY c.name
      ORDER BY total DESC
      ''',
          variables: [
            Variable(start.toIso8601String()),
            Variable(end.toIso8601String()),
          ],
        )
        .get();
    return {
      for (final row in rows) row.read<String>('name'): row.read<int>('total'),
    };
  }

  Future<Map<String, int>> _expenseByWallet(DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final rows = await db
        .customSelect(
          '''
      SELECT w.name, SUM(t.amount_cents) AS total
      FROM transactions t
      JOIN wallets w ON w.id = t.wallet_id
      WHERE t.type = 'expense' AND t.date >= ? AND t.date < ?
      GROUP BY w.name
      ORDER BY total DESC
      ''',
          variables: [
            Variable(start.toIso8601String()),
            Variable(end.toIso8601String()),
          ],
        )
        .get();
    return {
      for (final row in rows) row.read<String>('name'): row.read<int>('total'),
    };
  }

  Future<List<MonthlyTrend>> _monthlyTrend(DateTime month) async {
    final items = <MonthlyTrend>[];
    for (var offset = 5; offset >= 0; offset--) {
      final target = DateTime(month.year, month.month - offset);
      final totals = await _monthTotals(target);
      items.add(
        MonthlyTrend(
          month: target,
          incomeCents: totals.$1,
          expenseCents: totals.$2,
        ),
      );
    }
    return items;
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
      receiptPath: row.read<String>('receipt_path'),
      tagNames: row
          .read<String>('tag_names')
          .split(',')
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList(),
      createdAt: DateTime.parse(row.read<String>('created_at')),
      updatedAt: DateTime.parse(row.read<String>('updated_at')),
    );
  }

  Future<void> _syncTransactionTags(int transactionId, List<int> tagIds) async {
    await db.customStatement(
      'DELETE FROM transaction_tags WHERE transaction_id = ?',
      [transactionId],
    );
    for (final tagId in tagIds.toSet()) {
      await db.customStatement(
        'INSERT OR IGNORE INTO transaction_tags(transaction_id, tag_id) VALUES (?, ?)',
        [transactionId, tagId],
      );
    }
  }

  Future<String> _setting(String key) async {
    final row = await db
        .customSelect(
          'SELECT value FROM app_settings WHERE key = ? LIMIT 1',
          variables: [Variable(key)],
        )
        .getSingleOrNull();
    return row?.read<String>('value') ?? '';
  }

  Future<void> _setSetting(String key, String value) async {
    await db.customStatement(
      '''
      INSERT INTO app_settings(key, value) VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [key, value],
    );
  }

  String _pinHash(String pin, String salt) {
    var hash = 2166136261;
    for (final unit in '$salt:$pin'.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<SecretKey> _backupKey(String password, List<int> salt) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 120000,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  Future<int> _categoryIdByName(String name, TransactionType type) async {
    final normalized = name.trim().isEmpty ? 'อื่นๆ' : name.trim();
    final row = await db
        .customSelect(
          'SELECT id FROM categories WHERE name = ? AND type = ? LIMIT 1',
          variables: [Variable(normalized), Variable(type.value)],
        )
        .getSingleOrNull();
    if (row != null) return row.read<int>('id');
    final now = DateTime.now().toIso8601String();
    await db.customStatement(
      'INSERT INTO categories(name, type, created_at, updated_at) VALUES (?, ?, ?, ?)',
      [normalized, type.value, now, now],
    );
    final created = await db
        .customSelect('SELECT last_insert_rowid() AS id')
        .getSingle();
    return created.read<int>('id');
  }

  Future<int> _walletIdByName(String name) async {
    final normalized = name.trim().isEmpty ? 'เงินสด' : name.trim();
    final row = await db
        .customSelect(
          'SELECT id FROM wallets WHERE name = ? LIMIT 1',
          variables: [Variable(normalized)],
        )
        .getSingleOrNull();
    if (row != null) return row.read<int>('id');
    final now = DateTime.now().toIso8601String();
    await db.customStatement(
      'INSERT INTO wallets(name, balance_cents, created_at, updated_at) VALUES (?, 0, ?, ?)',
      [normalized, now, now],
    );
    final created = await db
        .customSelect('SELECT last_insert_rowid() AS id')
        .getSingle();
    return created.read<int>('id');
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    values.add(buffer.toString());
    return values.map((value) => value.trim()).toList();
  }

  String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}

class _ExportTransactionRow {
  const _ExportTransactionRow({
    required this.date,
    required this.type,
    required this.amountCents,
    required this.category,
    required this.wallet,
    required this.note,
  });

  final DateTime date;
  final String type;
  final int amountCents;
  final String category;
  final String wallet;
  final String note;
}
