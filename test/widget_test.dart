import 'package:flutter_test/flutter_test.dart';
import 'package:money_memo/core/formatters.dart';
import 'package:money_memo/core/models.dart';

void main() {
  test('parse baht amount to cents', () {
    expect(parseBahtToCents('123.45'), 12345);
    expect(parseBahtToCents('1,000'), 100000);
  });

  test('transaction type parses stored values', () {
    expect(TransactionType.fromValue('income'), TransactionType.income);
    expect(TransactionType.fromValue('expense'), TransactionType.expense);
  });
}
