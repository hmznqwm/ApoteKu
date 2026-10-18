import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _numberFormatter = NumberFormat('#,##0', 'id_ID');

  static String format(num value) {
    return _formatter.format(value);
  }

  static String formatNumber(num value) {
    return _numberFormatter.format(value);
  }

  static String formatDate(DateTime date) {
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return DateFormat('dd-MM-yyyy').format(date);
    }
  }

  static String formatReceiptDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }

  static String formatReceiptTime(DateTime date) {
    return DateFormat('HH:mm:ss').format(date);
  }

  static String formatDateTime(DateTime date) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(date);
    } catch (_) {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }
}
