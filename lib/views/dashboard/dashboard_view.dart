import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive_layout.dart';
import '../../providers/produk_provider.dart';
import '../../providers/transaksi_provider.dart';
import 'widgets/sales_chart_card.dart';

class DashboardView extends StatefulWidget {
  final Function(int)? onNavigate;
  const DashboardView({super.key, this.onNavigate});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProdukProvider>().loadProducts();
      context.read<TransaksiProvider>().loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final produkProv = context.watch<ProdukProvider>();
    final trxProv = context.watch<TransaksiProvider>();
    final isTablet = ResponsiveLayout.isTabletOrLarger(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;


    final expiringCount = produkProv.expiringProducts.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await produkProv.loadProducts();
          await trxProv.loadTransactions();
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, isLandscape ? 12 : 20, 20, isLandscape ? 16 : (isTablet ? 24 : 20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isLandscape ? 16 : 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selamat Datang di Sistem Apotek',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Operasional Kasir & Pengelolaan Stok Siap Digunakan',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),

                        ],
                      ),
                    ),
                    if (isTablet)
                      const Icon(
                        Icons.medical_services_outlined,
                        color: Colors.white24,
                        size: 90,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // KPI Cards — Professional Elegant 2x2 Grid (or 4-Col on Tablet)
              isTablet
                  ? Row(
                      children: [
                        Expanded(
                          child: _buildProfessionalKpiCard(
                            title: 'Omset Kotor',
                            value: CurrencyFormatter.format(trxProv.transactions.fold(0.0, (sum, trx) => sum + trx.total)),
                            subtitle: '${trxProv.transactions.length} Transaksi',
                            onTap: () => widget.onNavigate?.call(1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildProfessionalKpiCard(
                            title: 'Laba Bersih',
                            value: CurrencyFormatter.format(trxProv.transactions.fold(0.0, (sum, trx) => sum + trx.omsetBersih)),
                            subtitle: 'Estimasi Profit',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildProfessionalKpiCard(
                            title: 'Katalog Obat',
                            value: '${produkProv.allProducts.length} Item',
                            subtitle: '${produkProv.categories.length - 1} Kategori',
                            onTap: () => widget.onNavigate?.call(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildProfessionalKpiCard(
                            title: 'Kedaluwarsa',
                            value: '$expiringCount Item',
                            subtitle: expiringCount > 0 ? 'Perlu Restock' : 'Semua Aman',
                            subtitleColor: expiringCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            onTap: () => widget.onNavigate?.call(3),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildProfessionalKpiCard(
                                title: 'Omset Kotor',
                                value: CurrencyFormatter.format(trxProv.transactions.fold(0.0, (sum, trx) => sum + trx.total)),
                                subtitle: '${trxProv.transactions.length} Transaksi',
                                onTap: () => widget.onNavigate?.call(1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildProfessionalKpiCard(
                                title: 'Laba Bersih',
                                value: CurrencyFormatter.format(trxProv.transactions.fold(0.0, (sum, trx) => sum + trx.omsetBersih)),
                                subtitle: 'Estimasi Profit',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildProfessionalKpiCard(
                                title: 'Katalog Obat',
                                value: '${produkProv.allProducts.length} Item',
                                subtitle: '${produkProv.categories.length - 1} Kategori',
                                onTap: () => widget.onNavigate?.call(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildProfessionalKpiCard(
                                title: 'Kedaluwarsa',
                                value: '$expiringCount Item',
                                subtitle: expiringCount > 0 ? 'Perlu Restock' : 'Semua Aman',
                                subtitleColor: expiringCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                onTap: () => widget.onNavigate?.call(3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
              const SizedBox(height: 24),

              // Modern Sales Chart (Redesigned)
              const SalesChartCard(),
              const SizedBox(height: 24),

              // Section Obat Stok Menipis
              _buildLowStockSection(
                context: context,
                produkProv: produkProv,
                isTablet: isTablet,
              ),
            ],
          ),
        ),
      ),
    );
  }





  Widget _buildLowStockSection({
    required BuildContext context,
    required ProdukProvider produkProv,
    required bool isTablet,
  }) {
    final lowStockItems = produkProv.lowStockProducts;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stok Obat Menipis',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lowStockItems.isNotEmpty
                          ? 'Perlu segera restock persediaan'
                          : 'Seluruh persediaan obat dalam kondisi aman',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

            ],
          ),
          const SizedBox(height: 16),

          // Items List or Empty State
          if (lowStockItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.task_alt_rounded, color: Color(0xFF16A34A), size: 36),
                  SizedBox(height: 8),
                  Text(
                    'Tidak Ada Obat Menipis',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15803D),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Semua persediaan obat masih berada di atas ambang minimum (stok > 5).',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                ...lowStockItems.take(5).map((prod) {
                  final isOut = prod.isOutOfStock;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            prod.nama,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isOut ? 'Habis' : 'Sisa ${prod.stok}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isOut ? AppColors.danger : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProfessionalKpiCard({
    required String title,
    required String value,
    required String subtitle,
    Color? subtitleColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor ?? const Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
