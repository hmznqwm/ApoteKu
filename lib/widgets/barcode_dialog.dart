import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../models/produk_model.dart';

class BarcodeDialog extends StatefulWidget {
  final ProdukModel product;

  const BarcodeDialog({super.key, required this.product});

  static Future<void> show(BuildContext context, ProdukModel product) {
    return showDialog(
      context: context,
      builder: (ctx) => BarcodeDialog(product: product),
    );
  }

  @override
  State<BarcodeDialog> createState() => _BarcodeDialogState();
}

class _BarcodeDialogState extends State<BarcodeDialog> {
  bool _useQrCode = false;

  Barcode _getBarcodeType(String code) {
    if (_useQrCode) return Barcode.qrCode();
    // Default to Code 128 as it supports alphanumeric characters
    return Barcode.code128();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final cleanCode = p.kode.trim().isEmpty ? 'UNKNOWN' : p.kode.trim();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Barcode Produk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 14),

            // Product Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nama,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p.kategori,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(p.hargaJual),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Barcode Rendering Canvas
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: _useQrCode ? 160 : 90,
                      maxWidth: double.infinity,
                    ),
                    child: BarcodeWidget(
                      barcode: _getBarcodeType(cleanCode),
                      data: cleanCode,
                      width: _useQrCode ? 150 : double.infinity,
                      height: _useQrCode ? 150 : 80,
                      drawText: !_useQrCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      errorBuilder: (context, error) => Center(
                        child: Text(
                          'Format kode tidak valid untuk barcode 1D.\n$cleanCode',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                  if (_useQrCode) ...[
                    const SizedBox(height: 10),
                    Text(
                      cleanCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Barcode format switch (1D Barcode vs QR Code)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Barcode 1D (Garis)'),
                  selected: !_useQrCode,
                  onSelected: (val) => setState(() => _useQrCode = !val),
                  selectedColor: AppColors.primaryLight,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: !_useQrCode ? FontWeight.bold : FontWeight.normal,
                    color: !_useQrCode ? AppColors.primaryDark : AppColors.textSecondary,
                  ),
                  showCheckmark: false,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('QR Code 2D'),
                  selected: _useQrCode,
                  onSelected: (val) => setState(() => _useQrCode = val),
                  selectedColor: AppColors.primaryLight,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: _useQrCode ? FontWeight.bold : FontWeight.normal,
                    color: _useQrCode ? AppColors.primaryDark : AppColors.textSecondary,
                  ),
                  showCheckmark: false,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Salin Kode'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: cleanCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Kode "$cleanCode" berhasil disalin!'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: AppColors.primaryDark,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}
