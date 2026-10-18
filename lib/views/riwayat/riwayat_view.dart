import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive_layout.dart';
import '../../models/transaksi_model.dart';
import '../../providers/produk_provider.dart';
import '../../providers/transaksi_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/activity_log_provider.dart';
import '../../services/sync_service.dart';
import '../../widgets/receipt_dialog.dart';

class RiwayatView extends StatefulWidget {
  const RiwayatView({super.key});

  @override
  State<RiwayatView> createState() => _RiwayatViewState();
}

class _RiwayatViewState extends State<RiwayatView> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransaksiProvider>().loadTransactions();
    });
  }

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: const Size(800, 600), // Force dialog mode instead of full screen
            ),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _confirmRefund(BuildContext context, TransaksiModel trx) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.undo_rounded, color: AppColors.danger, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Konfirmasi Refund',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Anda yakin ingin merefund invoice ${trx.invoice}?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Total pengembalian dana ${CurrencyFormatter.format(trx.total)}. Stok akan dikembalikan.',
                        style: const TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final auth = context.read<AuthProvider>();
                        final logProv = context.read<ActivityLogProvider>();
                        final trxProv = context.read<TransaksiProvider>();
                        final produkProv = context.read<ProdukProvider>();
                        final success = await trxProv.refundTransaction(trx.id);
                        await produkProv.loadProducts();
                        if (success) {
                          await logProv.logActivity(
                            userName: auth.currentUser?.name ?? 'Staf Kasir',
                            userRole: auth.currentUser?.role ?? 'KASIR',
                            actionType: 'REFUND',
                            title: 'Refund / Pembatalan Transaksi',
                            details: 'Membatalkan & merefund invoice #${trx.invoice} (Total: ${CurrencyFormatter.format(trx.total)}). Stok produk dikembalikan.',
                          );
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(success ? Icons.check_circle : Icons.error, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(success
                                      ? 'Refund berhasil! Stok dikembalikan.'
                                      : 'Refund gagal. Coba lagi.'),
                                ],
                              ),
                              backgroundColor: success ? AppColors.success : AppColors.danger,
                              duration: const Duration(seconds: 3),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Proses Refund',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
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

  void _showDetailDialog(TransaksiModel trx) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isLandscape ? 8 : 20),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detail Transaksi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trx.invoice,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Content Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Grid
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildMetaRow('Tanggal', trx.tanggal),
                            const SizedBox(height: 6),
                            _buildMetaRow('Kasir', trx.kasirName),
                            const SizedBox(height: 6),
                            _buildMetaRow('Metode', trx.metode),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'DAFTAR OBAT DIBELI',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),

                      // Item list
                      ...trx.details.map((d) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${d.nama}  x${d.qty}',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  CurrencyFormatter.format(d.subtotal),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          )),

                      const Divider(height: 24, color: Color(0xFFE2E8F0)),

                      // Payment summary
                      _buildSummaryRow('Total Tagihan', CurrencyFormatter.format(trx.total), isBold: true, color: const Color(0xFF15803D)),
                      const SizedBox(height: 6),
                      _buildSummaryRow('Uang Diterima', CurrencyFormatter.format(trx.bayar)),
                      const SizedBox(height: 6),
                      _buildSummaryRow('Kembalian', CurrencyFormatter.format(trx.kembalian)),
                    ],
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    if (trx.status != 'REFUND')
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmRefund(context, trx);
                          },
                          child: const Icon(Icons.undo_rounded, size: 20),
                        ),
                      ),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('Cetak Struk', style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ReceiptDialog.show(context, trx);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 13.5 : 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isBold ? const Color(0xFF0F172A) : const Color(0xFF475569),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final trxProv = context.watch<TransaksiProvider>();
    final sync = context.watch<SyncService>();
    final isTablet = ResponsiveLayout.isTabletOrLarger(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final allTrx = trxProv.transactions;
    List<TransaksiModel> filteredTrx = allTrx;
    
    if (_startDate != null && _endDate != null) {
      final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      filteredTrx = allTrx.where((t) {
        final d = DateTime.tryParse(t.tanggal);
        if (d == null) return false;
        return d.isAfter(start) && d.isBefore(end);
      }).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<TransaksiProvider>().loadTransactions();
          await sync.syncAll(isBackground: true);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, isLandscape ? 12 : 20, 20, isLandscape ? 8 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    'Riwayat Transaksi Kasir',
                    style: TextStyle(fontSize: isLandscape ? 16 : 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: isLandscape ? null : double.infinity,
                    child: Row(
                      mainAxisSize: isLandscape ? MainAxisSize.min : MainAxisSize.max,
                      children: [
                        if (_startDate != null)
                          Flexible(
                            fit: isLandscape ? FlexFit.loose : FlexFit.tight,
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 16, color: AppColors.danger),
                              label: const Text('Hapus Filter', style: TextStyle(color: AppColors.danger)),
                            ),
                          ),
                        if (_startDate != null) const SizedBox(width: 8),
                        Flexible(
                          fit: isLandscape ? FlexFit.loose : FlexFit.tight,
                          child: ElevatedButton(
                            onPressed: _pickDateRange,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text(
                              'Filter Tanggal',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isLandscape ? 10 : 16),
              Expanded(
                child: trxProv.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredTrx.isEmpty
                        ? Center(
                            child: ListView(
                              shrinkWrap: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                Icon(Icons.receipt_long_outlined, size: 54, color: AppColors.textMuted),
                                SizedBox(height: 12),
                                Center(child: Text('Belum ada riwayat transaksi', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(0, 0, 0, isLandscape ? 20 : (isTablet ? 24 : 88)),
                            itemCount: filteredTrx.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                            final t = filteredTrx[idx];
                            final isRefunded = t.status == 'REFUND';
                            return Card(
                              elevation: 0,
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isRefunded ? AppColors.danger : AppColors.border,
                                  width: 1,
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () => _showDetailDialog(t),
                                onLongPressStart: (details) {
                                  if (t.status == 'REFUND') {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Transaksi ini sudah direfund sebelumnya.'),
                                        backgroundColor: Colors.orange,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }
                                  
                                  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                                  showMenu<String>(
                                    context: context,
                                    position: RelativeRect.fromRect(
                                      details.globalPosition & const Size(40, 40),
                                      Offset.zero & overlay.size,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 6,
                                    items: [
                                      PopupMenuItem<String>(
                                        value: 'refund',
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: AppColors.danger.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.undo_rounded, color: AppColors.danger, size: 18),
                                            ),
                                            const SizedBox(width: 10),
                                            const Text('Refund Transaksi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.danger)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ).then((result) {
                                    if (result == 'refund' && context.mounted) {
                                      _confirmRefund(context, t);
                                    }
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.invoice,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${t.tanggal}  -  ${t.kasirName}  -  ${t.metode.toUpperCase()}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            if (isRefunded)
                                              const Padding(
                                                padding: EdgeInsets.only(top: 6),
                                                child: Text(
                                                  'DIREFUND',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.danger,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            CurrencyFormatter.format(t.total),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
