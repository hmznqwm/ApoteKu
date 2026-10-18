import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive_layout.dart';
import '../../models/transaksi_model.dart';
import '../../providers/transaksi_provider.dart';
import '../../services/sync_service.dart';

class LaporanView extends StatefulWidget {
  const LaporanView({super.key});

  @override
  State<LaporanView> createState() => _LaporanViewState();
}

class _LaporanViewState extends State<LaporanView> {
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

  @override
  Widget build(BuildContext context) {
    final trxProv = context.watch<TransaksiProvider>();
    final sync = context.watch<SyncService>();
    final isTablet = ResponsiveLayout.isTabletOrLarger(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final allTrx = trxProv.transactions;
    List<TransaksiModel> filteredTrx = allTrx;
    double filteredRevenue = 0;
    double filteredNetRevenue = 0;
    
    if (_startDate != null && _endDate != null) {
      final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      filteredTrx = allTrx.where((t) {
        final d = DateTime.tryParse(t.tanggal);
        if (d == null) return false;
        return d.isAfter(start) && d.isBefore(end);
      }).toList();
    }

    double totalCash = 0;
    double totalQris = 0;
    double totalTransfer = 0;
    for (var t in filteredTrx) {
      filteredRevenue += t.total;
      filteredNetRevenue += t.omsetBersih;
      if (t.metode.toUpperCase() == 'CASH') {
        totalCash += t.total;
      } else if (t.metode.toUpperCase() == 'QRIS') {
        totalQris += t.total;
      } else if (t.metode.toUpperCase() == 'TRANSFER') {
        totalTransfer += t.total;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<TransaksiProvider>().loadTransactions();
          await sync.syncAll(isBackground: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, isLandscape ? 12 : 20, 20, isLandscape ? 16 : (isTablet ? 24 : 20)),
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
                    'Laporan Penjualan & Keuangan',
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;
                  
                  final card1 = Card(
                    elevation: 0.8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.border, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text('Omset', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.trending_up_rounded, color: Color(0xFF2563EB), size: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(filteredRevenue),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('${filteredTrx.length} transaksi tercatat', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  );

                  final card2 = Card(
                    elevation: 0.8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.border, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text('Omset Bersih', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.monetization_on_rounded, color: Color(0xFF16A34A), size: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(filteredNetRevenue),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.info),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text('Keuntungan murni (potong modal)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        card1,
                        const SizedBox(height: 10),
                        card2,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: card1),
                      const SizedBox(width: 14),
                      Expanded(child: card2),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0.8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Metode Pembayaran',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          _PaymentMethodItem(
                            title: 'Cash',
                            amount: totalCash,
                            icon: Icons.payments_rounded,
                            bgColor: const Color(0xFFF0FDF4),
                            iconColor: const Color(0xFF16A34A),
                          ),
                          const Divider(height: 16, color: AppColors.border),
                          _PaymentMethodItem(
                            title: 'QRIS',
                            amount: totalQris,
                            icon: Icons.qr_code_scanner_rounded,
                            bgColor: const Color(0xFFFAF5FF),
                            iconColor: const Color(0xFF9333EA),
                          ),
                          const Divider(height: 16, color: AppColors.border),
                          _PaymentMethodItem(
                            title: 'Transfer',
                            amount: totalTransfer,
                            icon: Icons.sync_alt_rounded,
                            bgColor: const Color(0xFFECFEFF),
                            iconColor: const Color(0xFF0891B2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0.8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5), size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text('Ringkasan Transaksi Terakhir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const Divider(height: 24),
                      filteredTrx.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: Text('Belum ada transaksi tercatat', style: TextStyle(color: AppColors.textMuted))),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredTrx.take(5).length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final t = filteredTrx[idx];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceMuted,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          t.invoice,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${t.tanggal} • ${t.metode}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        CurrencyFormatter.format(t.total),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _PaymentMethodItem extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  const _PaymentMethodItem({
    required this.title,
    required this.amount,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
        Text(
          CurrencyFormatter.format(amount),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
        ),
      ],
    );
  }
}
