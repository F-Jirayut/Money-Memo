import 'package:intl/intl.dart';

final _moneyFormat = NumberFormat.currency(
  locale: 'th_TH',
  symbol: '฿',
  decimalDigits: 2,
);
final _dateFormat = DateFormat('d MMM yyyy', 'th_TH');
final _monthFormat = DateFormat('MMMM yyyy', 'th_TH');
final _inputDateFormat = DateFormat('yyyy-MM-dd');

String moneyText(int cents) => _moneyFormat.format(cents / 100);
String dateText(DateTime date) => _dateFormat.format(date);
String monthText(DateTime date) => _monthFormat.format(date);
String inputDateText(DateTime date) => _inputDateFormat.format(date);

int parseBahtToCents(String value) {
  final normalized = value.replaceAll(',', '').trim();
  final amount = double.tryParse(normalized) ?? 0;
  return (amount * 100).round();
}
