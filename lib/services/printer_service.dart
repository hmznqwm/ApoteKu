import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_bluetooth_thermal_plus/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaksi_model.dart';
import '../core/utils/currency_formatter.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._init();
  PrinterService._init();

  static const String _prefMacKey = 'saved_printer_mac';
  static const String _prefNameKey = 'saved_printer_name';
  static const String _prefPaperSizeKey = 'saved_printer_paper_size';

  // Store metadata constants
  static const String storeName = 'Apotek Tia Farma';
  static const String storeAddress = 'Jl Arif Rahman Hakim 4A  Malang';
  static const String storePhone = 'Telepon 0341-300123';
  static const String footerNote1 = 'Barang yang sudah dibeli tidak';
  static const String footerNote2 = 'dapat ditukar / dikembalikan.';
  static const String footerThankYou = '* Terima kasih *';

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _connectedMac;
  String? get connectedMac => _connectedMac;

  String? _connectedName;
  String? get connectedName => _connectedName;

  /// Get current paper size preference (58mm or 80mm)
  Future<PaperSize> getPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    final size = prefs.getString(_prefPaperSizeKey) ?? '58';
    return size == '80' ? PaperSize.mm80 : PaperSize.mm58;
  }

  /// Save paper size preference ('58' or '80')
  Future<void> setPaperSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPaperSizeKey, size);
  }

  /// Check connection status
  Future<bool> checkConnection() async {
    try {
      _isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!_isConnected) {
        _connectedMac = null;
        _connectedName = null;
      }
      return _isConnected;
    } catch (e) {
      debugPrint('Error checking bluetooth connection: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Get paired bluetooth devices
  Future<List<BluetoothInfo>> getBondedDevices() async {
    try {
      final List<BluetoothInfo> listResult =
          await PrintBluetoothThermal.pairedBluetooths;
      return listResult;
    } catch (e) {
      debugPrint('Error getting paired bluetooth devices: $e');
      return [];
    }
  }

  /// Connect to bluetooth printer by MAC address
  Future<bool> connect(String macAddress, {String name = 'Printer Thermal'}) async {
    try {
      if (_isConnected) {
        await PrintBluetoothThermal.disconnect;
      }

      final bool result =
          await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      _isConnected = result;

      if (result) {
        _connectedMac = macAddress;
        _connectedName = name;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefMacKey, macAddress);
        await prefs.setString(_prefNameKey, name);
      }
      return result;
    } catch (e) {
      debugPrint('Error connecting to printer: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Auto-connect using saved MAC address
  Future<bool> autoConnect() async {
    try {
      if (await checkConnection()) return true;

      final prefs = await SharedPreferences.getInstance();
      final savedMac = prefs.getString(_prefMacKey);
      final savedName = prefs.getString(_prefNameKey) ?? 'Printer Thermal';

      if (savedMac != null && savedMac.isNotEmpty) {
        return await connect(savedMac, name: savedName);
      }
      return false;
    } catch (e) {
      debugPrint('Error auto connecting printer: $e');
      return false;
    }
  }

  /// Disconnect printer
  Future<bool> disconnect() async {
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      _isConnected = false;
      _connectedMac = null;
      _connectedName = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefMacKey);
      await prefs.remove(_prefNameKey);

      return result;
    } catch (e) {
      debugPrint('Error disconnecting printer: $e');
      return false;
    }
  }

  /// Get saved printer name if any
  Future<String?> getSavedPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefNameKey);
  }

  /// Generate ESC/POS thermal receipt bytes matching reference design
  Future<List<int>> generateReceiptBytes(
    TransaksiModel trx, {
    PaperSize? paperSize,
  }) async {
    final effectivePaperSize = paperSize ?? await getPaperSize();
    final profile = await CapabilityProfile.load();
    final generator = Generator(effectivePaperSize, profile);
    List<int> bytes = [];

    final maxChars = effectivePaperSize == PaperSize.mm80 ? 48 : 32;

    // Helper for formatting two-column row with exact width
    String formatTwoColumn(String left, String right) {
      final totalSpace = maxChars - left.length - right.length;
      if (totalSpace <= 0) {
        return '$left $right';
      }
      return left + (' ' * totalSpace) + right;
    }

    // Helper for dashed line
    String dashedLine() => '-' * maxChars;

    // Date & Time formatting
    DateTime trxDate;
    try {
      trxDate = DateTime.parse(trx.createdAt);
    } catch (_) {
      trxDate = DateTime.now();
    }
    final dateStr = CurrencyFormatter.formatReceiptDate(trxDate);
    final timeStr = CurrencyFormatter.formatReceiptTime(trxDate);

    // Reset printer
    bytes += generator.reset();

    // 1. Header (Centered, NO LOGO)
    bytes += generator.text(
      storeName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      ),
    );
    bytes += generator.text(
      storeAddress,
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      storePhone,
      styles: const PosStyles(align: PosAlign.center),
    );

    // 2. Dashed Line
    bytes += generator.text(dashedLine(), styles: const PosStyles(align: PosAlign.center));

    // 3. Metadata (Nomor & Tanggal, Kasir & Jam)
    bytes += generator.text(formatTwoColumn('Nomor: ${trx.invoice}', dateStr));
    bytes += generator.text(formatTwoColumn('Kasir: ${trx.kasirName}', timeStr));

    // Empty space between info and items
    bytes += generator.emptyLines(1);

    // 4. Column Header: Keterangan | Jumlah
    bytes += generator.text(formatTwoColumn('Keterangan', 'Jumlah'));
    bytes += generator.text(dashedLine(), styles: const PosStyles(align: PosAlign.center));

    // 5. Items loop
    int totalQty = 0;
    for (var item in trx.details) {
      totalQty += item.qty;
      final subtotalStr = CurrencyFormatter.formatNumber(item.subtotal);
      final hargaStr = CurrencyFormatter.formatNumber(item.harga);

      // Line 1: Item Name & Subtotal
      bytes += generator.text(formatTwoColumn(item.nama, subtotalStr));
      // Line 2: Qty Satuan X UnitPrice
      bytes += generator.text('    ${item.qty} Pcs  X  $hargaStr');
    }

    // 6. Dashed Line
    bytes += generator.text(dashedLine(), styles: const PosStyles(align: PosAlign.center));

    // 7. Totals & Summary
    // Alignment helper for summary
    String formatSummaryRow(String label, String value) {
      if (maxChars == 48) {
        // 80mm layout
        final prefix = ' ' * 16;
        final leftLabel = label.padRight(16);
        final rightVal = value.padLeft(12);
        return '$prefix$leftLabel: $rightVal';
      } else {
        // 58mm layout (32 chars)
        final leftLabel = label.padRight(14);
        final rightVal = value.padLeft(10);
        return '    $leftLabel: $rightVal';
      }
    }

    bytes += generator.text(
      formatSummaryRow('Total', CurrencyFormatter.formatNumber(trx.total)),
      styles: const PosStyles(bold: true),
    );

    if (trx.diskon > 0) {
      bytes += generator.text(
        formatSummaryRow('Diskon', '-${CurrencyFormatter.formatNumber(trx.diskon)}'),
      );
    }

    bytes += generator.text(
      formatSummaryRow('Jumlah barang', '${trx.details.length} : $totalQty'),
    );

    bytes += generator.text(
      formatSummaryRow('Bayar', CurrencyFormatter.formatNumber(trx.bayar)),
    );

    bytes += generator.text(
      formatSummaryRow('Kembali', CurrencyFormatter.formatNumber(trx.kembalian)),
    );

    // 8. Dashed Line
    bytes += generator.text(dashedLine(), styles: const PosStyles(align: PosAlign.center));

    // 9. Footer Note (Centered)
    bytes += generator.text(
      footerNote1,
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      footerNote2,
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      footerThankYou,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    // Feed and Cut
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  /// Print test receipt via Bluetooth ESC/POS
  Future<bool> printTestReceipt() async {
    try {
      final connected = await checkConnection();
      if (!connected) return false;

      final paperSize = await getPaperSize();
      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      final maxChars = paperSize == PaperSize.mm80 ? 48 : 32;
      String dashedLine() => '-' * maxChars;

      bytes += generator.reset();
      bytes += generator.text(
        storeName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );
      bytes += generator.text(
        storeAddress,
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        storePhone,
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(dashedLine(), styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(
        'TES CETAK PRINTER OK',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text('Ukuran Kertas: ${paperSize == PaperSize.mm80 ? "80mm" : "58mm"}');
      bytes += generator.text('Status: Terhubung & Siap Cetak');
      bytes += generator.text(dashedLine(), styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(
        footerThankYou,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.feed(3);
      bytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint('Error printing test receipt: $e');
      return false;
    }
  }

  /// Print receipt via Bluetooth ESC/POS
  Future<bool> printReceipt(TransaksiModel trx) async {
    try {
      bool connected = await checkConnection();
      if (!connected) {
        connected = await autoConnect();
      }
      if (!connected) return false;

      final bytes = await generateReceiptBytes(trx);
      final bool result = await PrintBluetoothThermal.writeBytes(bytes);
      return result;
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      return false;
    }
  }

  /// Print receipt via USB / Android System Print Manager (Supports USB OTG, USB POS, LAN, & Save PDF)
  Future<bool> printUsbOrSystemReceipt(TransaksiModel trx) async {
    try {
      final paperSize = await getPaperSize();
      final is80mm = paperSize == PaperSize.mm80;
      final pageWidth = is80mm ? 76.0 * PdfPageFormat.mm : 56.0 * PdfPageFormat.mm;

      final doc = pw.Document();

      // Date & Time formatting
      DateTime trxDate;
      try {
        trxDate = DateTime.parse(trx.createdAt);
      } catch (_) {
        trxDate = DateTime.now();
      }
      final dateStr = CurrencyFormatter.formatReceiptDate(trxDate);
      final timeStr = CurrencyFormatter.formatReceiptTime(trxDate);

      int totalQty = 0;
      for (var item in trx.details) {
        totalQty += item.qty;
      }

      final monoFont = pw.Font.courier();
      final monoBoldFont = pw.Font.courierBold();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidth, double.infinity, marginAll: 2 * PdfPageFormat.mm),
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  // Store Header (Centered, NO LOGO)
                  pw.Text(
                    storeName,
                    style: pw.TextStyle(font: monoBoldFont, fontSize: 13),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    storeAddress,
                    style: pw.TextStyle(font: monoFont, fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    storePhone,
                    style: pw.TextStyle(font: monoFont, fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),

                  // Dashed separator
                  pw.Text(
                    '-' * (is80mm ? 48 : 32),
                    style: pw.TextStyle(font: monoFont, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 3),

                  // Metadata row 1
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Nomor: ${trx.invoice}', style: pw.TextStyle(font: monoFont, fontSize: 9)),
                      pw.Text(dateStr, style: pw.TextStyle(font: monoFont, fontSize: 9)),
                    ],
                  ),
                  // Metadata row 2
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Kasir: ${trx.kasirName}', style: pw.TextStyle(font: monoFont, fontSize: 9)),
                      pw.Text(timeStr, style: pw.TextStyle(font: monoFont, fontSize: 9)),
                    ],
                  ),
                  pw.SizedBox(height: 4),

                  // Column header: Keterangan | Jumlah
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Keterangan', style: pw.TextStyle(font: monoBoldFont, fontSize: 9)),
                      pw.Text('Jumlah', style: pw.TextStyle(font: monoBoldFont, fontSize: 9)),
                    ],
                  ),
                  pw.Text(
                    '-' * (is80mm ? 48 : 32),
                    style: pw.TextStyle(font: monoFont, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),

                  // Item list
                  ...trx.details.map((item) {
                    final subtotalStr = CurrencyFormatter.formatNumber(item.subtotal);
                    final hargaStr = CurrencyFormatter.formatNumber(item.harga);
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Expanded(
                                child: pw.Text(
                                  item.nama,
                                  style: pw.TextStyle(font: monoBoldFont, fontSize: 9),
                                ),
                              ),
                              pw.Text(subtotalStr, style: pw.TextStyle(font: monoFont, fontSize: 9)),
                            ],
                          ),
                          pw.Text(
                            '    ${item.qty} Pcs  X  $hargaStr',
                            style: pw.TextStyle(font: monoFont, fontSize: 8.5),
                          ),
                        ],
                      ),
                    );
                  }),

                  pw.SizedBox(height: 2),
                  pw.Text(
                    '-' * (is80mm ? 48 : 32),
                    style: pw.TextStyle(font: monoFont, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 3),

                  // Summary Totals
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('Total          : ', style: pw.TextStyle(font: monoBoldFont, fontSize: 9)),
                      pw.Text(
                        CurrencyFormatter.formatNumber(trx.total),
                        style: pw.TextStyle(font: monoBoldFont, fontSize: 9),
                      ),
                    ],
                  ),
                  if (trx.diskon > 0)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text('Diskon         : ', style: pw.TextStyle(font: monoFont, fontSize: 9)),
                        pw.Text(
                          '-${CurrencyFormatter.formatNumber(trx.diskon)}',
                          style: pw.TextStyle(font: monoFont, fontSize: 9),
                        ),
                      ],
                    ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('Jumlah barang  : ', style: pw.TextStyle(font: monoFont, fontSize: 9)),
                      pw.Text(
                        '${trx.details.length} : $totalQty',
                        style: pw.TextStyle(font: monoFont, fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('Bayar          : ', style: pw.TextStyle(font: monoFont, fontSize: 9)),
                      pw.Text(
                        CurrencyFormatter.formatNumber(trx.bayar),
                        style: pw.TextStyle(font: monoFont, fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('Kembali        : ', style: pw.TextStyle(font: monoFont, fontSize: 9)),
                      pw.Text(
                        CurrencyFormatter.formatNumber(trx.kembalian),
                        style: pw.TextStyle(font: monoFont, fontSize: 9),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 3),
                  pw.Text(
                    '-' * (is80mm ? 48 : 32),
                    style: pw.TextStyle(font: monoFont, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),

                  // Footer Notes
                  pw.Text(
                    footerNote1,
                    style: pw.TextStyle(font: monoFont, fontSize: 8.5),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    footerNote2,
                    style: pw.TextStyle(font: monoFont, fontSize: 8.5),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    footerThankYou,
                    style: pw.TextStyle(font: monoBoldFont, fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        name: 'Struk_${trx.invoice}',
        onLayout: (PdfPageFormat format) async => doc.save(),
      );
      return true;
    } catch (e) {
      debugPrint('Error printing USB/System receipt: $e');
      return false;
    }
  }
}
