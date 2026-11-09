import 'package:flutter/material.dart';
import '../models/transaksi_model.dart';
import '../services/printer_service.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import 'printer_dialog.dart';

class ReceiptDialog extends StatefulWidget {
  final TransaksiModel transaction;

  const ReceiptDialog({super.key, required this.transaction});

  static Future<void> show(BuildContext context, TransaksiModel transaction) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReceiptDialog(transaction: transaction),
    );
  }

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  bool _isPrinting = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkPrinterStatus();
  }

  Future<void> _checkPrinterStatus() async {
    bool connected = await PrinterService.instance.checkConnection();
    if (!connected) {
      connected = await PrinterService.instance.autoConnect();
    }
    if (mounted) {
      setState(() {
        _isConnected = connected;
      });
    }
  }

  Future<void> _handleManageBluetooth() async {
    final connected = await PrinterConnectDialog.show(context);
    await _checkPrinterStatus();
    if (connected == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer Bluetooth berhasil terhubung! Siap mencetak.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handlePrint() async {
    if (_isPrinting) return;

    setState(() => _isPrinting = true);

    // 1. Periksa apakah printer sudah terhubung atau bisa auto-connect
    bool connected = await PrinterService.instance.checkConnection();
    if (!connected) {
      connected = await PrinterService.instance.autoConnect();
    }

    if (mounted) {
      setState(() => _isConnected = connected);
    }

    // 2. Jika sudah terhubung, langsung otomatis cetak ke printer termal!
    if (connected) {
      final success = await PrinterService.instance.printReceipt(widget.transaction);
      if (mounted) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    success
                        ? 'Struk berhasil dicetak ke printer termal!'
                        : 'Gagal mencetak struk. Pastikan kertas dan baterai printer mencukupi.',
                  ),
                ),
              ],
            ),
            backgroundColor: success ? AppColors.success : AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 3. Jika belum terhubung, hanya beri notifikasi singkat tanpa pop up apapun
    if (mounted) {
      setState(() => _isPrinting = false);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Printer belum terhubung! Silakan klik tombol Bluetooth terlebih dahulu.'),
              ),
            ],
          ),
          backgroundColor: Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trx = widget.transaction;

    // Date & Time formatting
    DateTime trxDate;
    try {
      trxDate = DateTime.parse(trx.createdAt);
    } catch (_) {
      trxDate = DateTime.now();
    }
    final dateStr = CurrencyFormatter.formatReceiptDate(trxDate);
    final timeStr = CurrencyFormatter.formatReceiptTime(trxDate);

    // Calculate total quantity
    int totalQty = 0;
    for (var item in trx.details) {
      totalQty += item.qty;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header with Success Indicator & Settings
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transaksi Berhasil',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Struk Siap Dicetak (Panjang Otomatis • ${trx.details.length} Item)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  tooltip: 'Pengaturan Printer',
                  onPressed: () => PrinterConnectDialog.show(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Authentic Monospace Thermal Receipt Ticket (No Logo)
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Header (Logo, Nama, Slogan, Alamat)
                      Center(
                        child: Image.asset(
                          'assets/images/apotek-logo.png',
                          height: 44,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(height: 4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        PrinterService.storeName,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        PrinterService.storeSlogan,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        PrinterService.storeAddress,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (PrinterService.storePhone.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          PrinterService.storePhone,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 8),

                      // 2. Dashed Separator
                      _buildDashedLine(),
                      const SizedBox(height: 6),

                      // 3. Metadata (No. Nota, Waktu, Kasir)
                      Row(
                        children: [
                          const SizedBox(
                            width: 65,
                            child: Text(
                              'No. Nota',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87),
                            ),
                          ),
                          const Text(': ', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87)),
                          Expanded(
                            child: Text(
                              trx.invoice,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const SizedBox(
                            width: 65,
                            child: Text(
                              'Waktu',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87),
                            ),
                          ),
                          const Text(': ', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87)),
                          Expanded(
                            child: Text(
                              '$dateStr $timeStr',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const SizedBox(
                            width: 65,
                            child: Text(
                              'Kasir',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87),
                            ),
                          ),
                          const Text(': ', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87)),
                          Expanded(
                            child: Text(
                              trx.kasirName,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 4. Column Header: Keterangan | Jumlah
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Keterangan / Obat',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          Text(
                            'Jumlah',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildDashedLine(),
                      const SizedBox(height: 6),

                      // 5. Items List
                      ...trx.details.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.nama,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      '${item.qty} Pcs  x  ${CurrencyFormatter.formatNumber(item.harga)}',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.formatNumber(item.subtotal),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 6),
                      _buildDashedLine(),
                      const SizedBox(height: 6),

                      // 6. Summary Totals (Aligned colons)
                      _buildSummaryRow('Total Belanja', CurrencyFormatter.formatNumber(trx.total), isBold: true),
                      if (trx.diskon > 0)
                        _buildSummaryRow('Diskon', '-${CurrencyFormatter.formatNumber(trx.diskon)}'),
                      _buildSummaryRow('Total Item', '$totalQty Pcs (${trx.details.length} Produk)'),
                      _buildSummaryRow('Tunai (Bayar)', CurrencyFormatter.formatNumber(trx.bayar)),
                      _buildSummaryRow('Kembalian', CurrencyFormatter.formatNumber(trx.kembalian)),

                      const SizedBox(height: 8),
                      _buildDashedLine(),
                      const SizedBox(height: 8),

                      // 7. Footer Note (Centered)
                      const Text(
                        PrinterService.footerNote1,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        PrinterService.footerNote2,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        PrinterService.footerThankYou,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Print Action Buttons (Bluetooth + Print + Selesai)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Tombol 1: Bluetooth
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isConnected ? AppColors.primary : const Color(0xFF475569),
                          backgroundColor: _isConnected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(
                            color: _isConnected ? AppColors.primary : const Color(0xFFCBD5E1),
                          ),
                        ),
                        icon: Icon(
                          _isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
                          size: 18,
                          color: _isConnected ? AppColors.primary : const Color(0xFF475569),
                        ),
                        label: Text(
                          _isConnected ? 'Bluetooth (Aktif)' : 'Bluetooth',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _isConnected ? AppColors.primary : const Color(0xFF475569),
                          ),
                        ),
                        onPressed: _isPrinting ? null : _handleManageBluetooth,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Tombol 2: Print (Menggantikan PDF/USB)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: _isPrinting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Print', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: _isPrinting ? null : _handlePrint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Selesai', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            ': ',
            style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth;
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.grey.shade500),
              ),
            );
          }),
        );
      },
    );
  }
}
