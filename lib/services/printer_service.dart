import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:image/image.dart' as img;
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

  // Store metadata constants (Dapat diperbarui otomatis via cloud sync)
  static String customStoreName = 'APOTEK TIA FARMA';
  static String customStoreSlogan = 'PELAYANAN KESEHATAN KELUARGA';
  static String customStoreAddress = 'Ds. Klotok Plumpang Tuban';
  static String customStorePhone = '';
  static String customFooterThankYou = '* Terima kasih *';

  static String get storeName => customStoreName;
  static String get storeSlogan => customStoreSlogan;
  static String get storeAddress => customStoreAddress;
  static String get storePhone => customStorePhone;
  static const String footerNote1 = 'Barang yang sudah dibeli tidak';
  static const String footerNote2 = 'dapat ditukar / dikembalikan.';
  static String get footerThankYou => customFooterThankYou;

  static Future<void> loadStoreInfoFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final n = prefs.getString('setting_nama_apotek');
      if (n != null && n.isNotEmpty) customStoreName = n;
      final sl = prefs.getString('setting_slogan_apotek');
      if (sl != null && sl.isNotEmpty) customStoreSlogan = sl;
      final a = prefs.getString('setting_alamat_apotek');
      if (a != null && a.isNotEmpty) customStoreAddress = a;
      final t = prefs.getString('setting_telepon_apotek');
      if (t != null) customStorePhone = t;
      final f = prefs.getString('setting_footer_struk');
      if (f != null && f.isNotEmpty) customFooterThankYou = f;
    } catch (_) {}
  }

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
      _isConnected = await PrintBluetoothThermal.connectionStatus
          .timeout(const Duration(milliseconds: 1500), onTimeout: () => false);
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
          await PrintBluetoothThermal.pairedBluetooths
              .timeout(const Duration(seconds: 2), onTimeout: () => []);
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
        await PrintBluetoothThermal.disconnect
            .timeout(const Duration(milliseconds: 1000), onTimeout: () => false);
      }

      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress)
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
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

    // Helper to wrap long text into lines of max width without cutting off words
    List<String> wrapText(String text, int width) {
      if (text.length <= width) return [text];
      List<String> lines = [];
      List<String> words = text.split(' ');
      String currentLine = '';

      for (var word in words) {
        if (word.length > width) {
          if (currentLine.isNotEmpty) {
            lines.add(currentLine);
            currentLine = '';
          }
          int start = 0;
          while (start < word.length) {
            int end = (start + width < word.length) ? start + width : word.length;
            lines.add(word.substring(start, end));
            start += width;
          }
          continue;
        }

        if (currentLine.isEmpty) {
          currentLine = word;
        } else if (currentLine.length + 1 + word.length <= width) {
          currentLine += ' $word';
        } else {
          lines.add(currentLine);
          currentLine = word;
        }
      }
      if (currentLine.isNotEmpty) {
        lines.add(currentLine);
      }
      return lines;
    }

    // Helper for formatting two-column row with exact width without overflowing
    String formatTwoColumn(String left, String right) {
      final availableForLeft = maxChars - right.length - 1;
      if (left.length > availableForLeft) {
        left = left.substring(0, availableForLeft > 0 ? availableForLeft : 1);
      }
      final totalSpace = maxChars - left.length - right.length;
      final spaceCount = totalSpace > 0 ? totalSpace : 1;
      return left + (' ' * spaceCount) + right;
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

    // 0. Print Logo Apotek (Jika didukung & berhasil dibaca)
    try {
      final ByteData data = await rootBundle.load('assets/images/apotek-logo.png');
      final Uint8List imgBytes = data.buffer.asUint8List();
      final img.Image? decoded = img.decodeImage(imgBytes);
      if (decoded != null) {
        final img.Image resized = img.copyResize(decoded, width: paperSize == PaperSize.mm80 ? 160 : 130);
        bytes += generator.imageRaster(resized, align: PosAlign.center);
      }
    } catch (_) {}

    // 1. Header (Nama, Slogan, Alamat)
    for (var line in wrapText(storeName, maxChars)) {
      bytes += generator.text(
        line,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      );
    }
    for (var line in wrapText(storeSlogan, maxChars)) {
      bytes += generator.text(
        line,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }
    for (var line in wrapText(storeAddress, maxChars)) {
      bytes += generator.text(
        line,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (storePhone.isNotEmpty) {
      for (var line in wrapText(storePhone, maxChars)) {
        bytes += generator.text(
          line,
          styles: const PosStyles(align: PosAlign.center),
        );
      }
    }

    // 2. Dashed Line
    bytes += generator.text(dashedLine(), styles: const PosStyles(align: PosAlign.center));

    // 3. Metadata (Nomor, Tanggal/Waktu, Kasir)
    bytes += generator.text('No. Nota : ${trx.invoice}');
    bytes += generator.text('Waktu    : $dateStr $timeStr');
    bytes += generator.text('Kasir    : ${trx.kasirName}');

    // 4. Column Header: Keterangan | Jumlah
    bytes += generator.text(dashedLine(), styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(formatTwoColumn('Keterangan', 'Jumlah'));
    bytes += generator.text(dashedLine(), styles: const PosStyles(align: PosAlign.center));

    // 5. Items loop with auto text wrapping (never overflows 32/48 chars)
    int totalQty = 0;
    for (var item in trx.details) {
      totalQty += item.qty;
      final subtotalStr = CurrencyFormatter.formatNumber(item.subtotal);
      final hargaStr = CurrencyFormatter.formatNumber(item.harga);
      final qtyPriceStr = '  ${item.qty} Pcs x $hargaStr';

      for (var nl in wrapText(item.nama, maxChars)) {
        bytes += generator.text(nl, styles: const PosStyles(bold: true));
      }
      bytes += generator.text(formatTwoColumn(qtyPriceStr, subtotalStr));
    }

    // 6. Dashed Line
    bytes += generator.text(dashedLine(), styles: const PosStyles(align: PosAlign.center));

    // 7. Totals & Summary
    bytes += generator.text(
      formatTwoColumn('Total Belanja', CurrencyFormatter.formatNumber(trx.total)),
      styles: const PosStyles(bold: true),
    );

    if (trx.diskon > 0) {
      bytes += generator.text(
        formatTwoColumn('Diskon', '-${CurrencyFormatter.formatNumber(trx.diskon)}'),
      );
    }

    bytes += generator.text(
      formatTwoColumn('Total Item', '$totalQty Pcs'),
    );

    bytes += generator.text(
      formatTwoColumn('Tunai (Bayar)', CurrencyFormatter.formatNumber(trx.bayar)),
    );

    bytes += generator.text(
      formatTwoColumn('Kembalian', CurrencyFormatter.formatNumber(trx.kembalian)),
    );

    // 8. Dashed Line
    bytes += generator.text(dashedLine(), styles: const PosStyles(align: PosAlign.center));

    // 9. Footer Note (Centered with word wrap)
    for (var line in wrapText(footerNote1, maxChars)) {
      bytes += generator.text(
        line,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    for (var line in wrapText(footerNote2, maxChars)) {
      bytes += generator.text(
        line,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
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
      try {
        final ByteData data = await rootBundle.load('assets/images/apotek-logo.png');
        final Uint8List imgBytes = data.buffer.asUint8List();
        final img.Image? decoded = img.decodeImage(imgBytes);
        if (decoded != null) {
          final img.Image resized = img.copyResize(decoded, width: paperSize == PaperSize.mm80 ? 160 : 130);
          bytes += generator.imageRaster(resized, align: PosAlign.center);
        }
      } catch (_) {}
      bytes += generator.text(
        storeName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );
      bytes += generator.text(
        storeSlogan,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        storeAddress,
        styles: const PosStyles(align: PosAlign.center),
      );
      if (storePhone.isNotEmpty) {
        bytes += generator.text(
          storePhone,
          styles: const PosStyles(align: PosAlign.center),
        );
      }
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
      final bool result = await PrintBluetoothThermal.writeBytes(bytes)
          .timeout(const Duration(seconds: 4), onTimeout: () => false);
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
      final pageWidth = is80mm ? 76.0 * PdfPageFormat.mm : 58.0 * PdfPageFormat.mm;

      // Ketentuan Panjang Struk Dinamis:
      // Semakin banyak item yang dibeli, panjang struk otomatis bertambah secara proporsional.
      // Mencegah kertas kosong berlebih dan mencegah teks terpotong pada Android Print Spooler.
      double itemsHeightMm = 0;
      for (var item in trx.details) {
        final int nameCharsPerLine = is80mm ? 38 : 22;
        final int nameLines = (item.nama.length / nameCharsPerLine).ceil().clamp(1, 4);
        itemsHeightMm += (nameLines * 4.2) + 5.2;
      }

      double totalHeightMm = 18.0 + 15.0 + 6.0 + 12.5 + itemsHeightMm + 18.0 + 16.0 + 12.0;
      if (trx.diskon > 0) totalHeightMm += 4.0;
      if (totalHeightMm < 95.0) totalHeightMm = 95.0;

      final pageHeight = totalHeightMm * PdfPageFormat.mm;

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

      pw.Widget buildDashedDivider() {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Divider(
            thickness: 0.7,
            color: PdfColors.black,
            borderStyle: pw.BorderStyle.dashed,
          ),
        );
      }

      pw.Widget buildSummaryRow(String label, String value, {bool isBold = false}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  font: isBold ? monoBoldFont : monoFont,
                  fontSize: is80mm ? 9 : 8,
                ),
              ),
              pw.Text(
                value,
                style: pw.TextStyle(
                  font: isBold ? monoBoldFont : monoFont,
                  fontSize: is80mm ? 9 : 8,
                ),
              ),
            ],
          ),
        );
      }

      pw.MemoryImage? logoImage;
      try {
        final ByteData logoData = await rootBundle.load('assets/images/apotek-logo.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidth, pageHeight, marginAll: 2 * PdfPageFormat.mm),
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  // Store Header dengan Logo Apotek
                  if (logoImage != null) ...[
                    pw.Center(
                      child: pw.Image(
                        logoImage,
                        height: is80mm ? 36 : 28,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                  ],
                  pw.Text(
                    storeName,
                    style: pw.TextStyle(font: monoBoldFont, fontSize: is80mm ? 12 : 11),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 0.5),
                  pw.Text(
                    storeSlogan,
                    style: pw.TextStyle(font: monoBoldFont, fontSize: is80mm ? 8.5 : 7.5),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    storeAddress,
                    style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8 : 7),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (storePhone.isNotEmpty) ...[
                    pw.Text(
                      storePhone,
                      style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8 : 7),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                  pw.SizedBox(height: 2),

                  // Dashed separator
                  buildDashedDivider(),

                  // Metadata (No. Nota, Waktu, Kasir)
                  pw.Row(
                    children: [
                      pw.SizedBox(
                        width: is80mm ? 65 : 46,
                        child: pw.Text('No. Nota', style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8.5 : 7.5)),
                      ),
                      pw.Text(': ', style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8.5 : 7.5)),
                      pw.Expanded(
                        child: pw.Text(
                          trx.invoice,
                          style: pw.TextStyle(font: monoBoldFont, fontSize: is80mm ? 8.5 : 7.5),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 1),
                  pw.Row(
                    children: [
                      pw.SizedBox(
                        width: is80mm ? 65 : 46,
                        child: pw.Text('Waktu', style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8.5 : 7.5)),
                      ),
                      pw.Text(': ', style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8.5 : 7.5)),
                      pw.Expanded(
                        child: pw.Text(
                          '$dateStr $timeStr',
                          style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8.5 : 7.5),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 1),
                  pw.Row(
                    children: [
                      pw.SizedBox(
                        width: is80mm ? 65 : 46,
                        child: pw.Text('Kasir', style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8.5 : 7.5)),
                      ),
                      pw.Text(': ', style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8.5 : 7.5)),
                      pw.Expanded(
                        child: pw.Text(
                          trx.kasirName,
                          style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8.5 : 7.5),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),

                  // Column header: Keterangan | Jumlah
                  buildDashedDivider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Keterangan / Obat', style: pw.TextStyle(font: monoBoldFont, fontSize: is80mm ? 8.5 : 7.5)),
                      pw.Text('Jumlah', style: pw.TextStyle(font: monoBoldFont, fontSize: is80mm ? 8.5 : 7.5)),
                    ],
                  ),
                  buildDashedDivider(),

                  // Item list
                  ...trx.details.map((item) {
                    final subtotalStr = CurrencyFormatter.formatNumber(item.subtotal);
                    final hargaStr = CurrencyFormatter.formatNumber(item.harga);
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            item.nama,
                            style: pw.TextStyle(font: monoBoldFont, fontSize: is80mm ? 8.5 : 7.5),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                '  ${item.qty} Pcs x $hargaStr',
                                style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8.0 : 7.0),
                              ),
                              pw.Text(
                                subtotalStr,
                                style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8.5 : 7.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  // Summary Totals
                  buildDashedDivider(),
                  buildSummaryRow('Total Belanja', CurrencyFormatter.formatNumber(trx.total), isBold: true),
                  if (trx.diskon > 0)
                    buildSummaryRow('Diskon', '-${CurrencyFormatter.formatNumber(trx.diskon)}'),
                  buildSummaryRow('Total Item', '$totalQty Pcs (${trx.details.length} Produk)'),
                  buildSummaryRow('Tunai (Bayar)', CurrencyFormatter.formatNumber(trx.bayar)),
                  buildSummaryRow('Kembalian', CurrencyFormatter.formatNumber(trx.kembalian)),

                  // Footer Notes
                  buildDashedDivider(),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    footerNote1,
                    style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8.0 : 7.0),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    footerNote2,
                    style: pw.TextStyle(font: monoFont, fontSize: is80mm ? 8.0 : 7.0),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    footerThankYou,
                    style: pw.TextStyle(font: monoBoldFont, fontSize: is80mm ? 8.5 : 7.5),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 6),
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
