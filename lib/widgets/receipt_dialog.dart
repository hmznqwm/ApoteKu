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
  bool _isPrintingBt = false;
  bool _isPrintingUsb = false;

  Future<void> _handlePrintBluetooth() async {
    setState(() => _isPrintingBt = true);

    // 1. Check connection or attempt auto-connect
    bool connected = await PrinterService.instance.checkConnection();
    if (!connected) {
      connected = await PrinterService.instance.autoConnect();
    }

    // 2. If still not connected, pop up printer connection dialog!
    if (!connected && mounted) {
      setState(() => _isPrintingBt = false);
      final connectedFromDialog = await PrinterConnectDialog.show(context);
      if (connectedFromDialog != true) {
        return; // User closed dialog without connecting
      }
      setState(() => _isPrintingBt = true);
    }

    // 3. Print receipt
    final success = await PrinterService.instance.printReceipt(widget.transaction);

    if (mounted) {
      setState(() => _isPrintingBt = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Struk berhasil dicetak via Bluetooth!'
                : 'Gagal mencetak struk. Pastikan printer Bluetooth terhubung.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  Future<void> _handlePrintUsbOrSystem() async {
    setState(() => _isPrintingUsb = true);
    final success = await PrinterService.instance.printUsbOrSystemReceipt(widget.transaction);
    if (mounted) {
      setState(() => _isPrintingUsb = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka dialog cetak USB / Dokumen.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaksi Berhasil',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Struk Siap Dicetak (58mm / 80mm)',
                        style: TextStyle(
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
                      // 1. Header (Centered, NO LOGO)
                      const Text(
                        PrinterService.storeName,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        PrinterService.storeAddress,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        PrinterService.storePhone,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // 2. Dashed Separator
                      _buildDashedLine(),
                      const SizedBox(height: 6),

                      // 3. Metadata (Nomor & Tanggal, Kasir & Jam)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Nomor: ${trx.invoice}',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Kasir: ${trx.kasirName}',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeStr,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 4. Column Header: Keterangan | Jumlah
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Keterangan',
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.nama,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 1),
                                child: Text(
                                  '${item.qty} Pcs  X  ${CurrencyFormatter.formatNumber(item.harga)}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 6),
                      _buildDashedLine(),
                      const SizedBox(height: 6),

                      // 6. Summary Totals (Aligned colons)
                      _buildSummaryRow('Total', CurrencyFormatter.formatNumber(trx.total), isBold: true),
                      if (trx.diskon > 0)
                        _buildSummaryRow('Diskon', '-${CurrencyFormatter.formatNumber(trx.diskon)}'),
                      _buildSummaryRow('Jumlah barang', '${trx.details.length} : $totalQty'),
                      _buildSummaryRow('Bayar', CurrencyFormatter.formatNumber(trx.bayar)),
                      _buildSummaryRow('Kembali', CurrencyFormatter.formatNumber(trx.kembalian)),

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
                      const Text(
                        PrinterService.footerThankYou,
                        style: TextStyle(
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

            // Print Action Buttons (Bluetooth + USB / System Print + Selesai)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: _isPrintingBt
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.bluetooth_connected_rounded, size: 18),
                        label: const Text('Bluetooth', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: (_isPrintingBt || _isPrintingUsb) ? null : _handlePrintBluetooth,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        icon: _isPrintingUsb
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.print_rounded, size: 18),
                        label: const Text('PDF / USB', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: (_isPrintingBt || _isPrintingUsb) ? null : _handlePrintUsbOrSystem,
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
