import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive_layout.dart';
import '../../models/produk_model.dart';
import '../../providers/produk_provider.dart';

class KedaluwarsaView extends StatefulWidget {
  const KedaluwarsaView({super.key});

  @override
  State<KedaluwarsaView> createState() => _KedaluwarsaViewState();
}

class _KedaluwarsaViewState extends State<KedaluwarsaView> {
  // 0: Semua, 1: Kritis (<30 Hari), 2: Mendekati (<90 Hari), 3: Kedaluwarsa
  int _selectedFilter = 0;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showDetailModal(ProdukModel p) {
    final status = _getStatusInfo(p);
    final totalValue = p.stok * p.hargaJual;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isLandscape ? 8 : 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(status.icon, color: status.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                p.nama,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Container(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: status.color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(status.icon, color: status.color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status.description,
                          style: TextStyle(
                            color: status.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Kode SKU', p.kode),
                _buildInfoRow('Kategori', p.kategori),
                _buildInfoRow('Tanggal Kedaluwarsa', p.tglKadaluwarsa ?? '-'),
                _buildInfoRow('Sisa Stok Tersedia', '${p.stok} ${p.satuan}'),
                _buildInfoRow('Harga Jual / Unit', CurrencyFormatter.format(p.hargaJual)),
                const Divider(height: 20),
                _buildInfoRow(
                  'Estimasi Potensi Nilai',
                  CurrencyFormatter.format(totalValue),
                  isHighlight: true,
                  highlightColor: status.color,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Tutup'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                  color: isHighlight ? (highlightColor ?? AppColors.primary) : AppColors.textPrimary,
                  fontSize: isHighlight ? 14 : 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo(ProdukModel p) {
    if (p.isExpired) {
      return _StatusInfo(
        label: 'EXPIRED',
        description: 'Obat ini telah melewati batas masa kedaluwarsa!',
        color: AppColors.danger,
        icon: Icons.cancel_outlined,
      );
    } else if (p.isCriticalExpiry) {
      return _StatusInfo(
        label: '${p.daysUntilExpiry} Hari Lagi',
        description: 'Masa kedaluwarsa kritis (< 30 hari). Segera tindak/retur!',
        color: const Color(0xFFDC2626),
        icon: Icons.warning_amber_rounded,
      );
    } else if (p.isNearExpiry) {
      return _StatusInfo(
        label: '${p.daysUntilExpiry} Hari Lagi',
        description: 'Masa kedaluwarsa mendekati (< 90 hari). Pantau berkala.',
        color: const Color(0xFFD97706),
        icon: Icons.access_time_rounded,
      );
    }
    return _StatusInfo(
      label: 'Aman',
      description: 'Masa simpan obat masih aman.',
      color: AppColors.success,
      icon: Icons.check_circle_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final produkProv = context.watch<ProdukProvider>();
    final all = produkProv.allProducts;

    final expired = all.where((p) => p.isExpired).toList();
    final critical = all.where((p) => p.isCriticalExpiry).toList();
    final near = all.where((p) => p.isNearExpiry).toList();
    final allThreatened = all.where((p) => p.isExpired || p.isCriticalExpiry || p.isNearExpiry).toList();

    List<ProdukModel> filtered;
    switch (_selectedFilter) {
      case 1:
        filtered = critical;
        break;
      case 2:
        filtered = near;
        break;
      case 3:
        filtered = expired;
        break;
      default:
        filtered = allThreatened;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((p) => p.nama.toLowerCase().contains(q) || p.kode.toLowerCase().contains(q) || p.kategori.toLowerCase().contains(q))
          .toList();
    }

    final isTablet = ResponsiveLayout.isTabletOrLarger(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, isLandscape ? 10 : 16, 16, isLandscape ? 16 : (isTablet ? 24 : 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Text(
              'Monitoring Kedaluwarsa Obat',
              style: TextStyle(
                fontSize: isLandscape ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Pantau dan antisipasi obat yang mendekati masa expired untuk menjaga mutu apotek.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            SizedBox(height: isLandscape ? 10 : 16),

            // 3 Summary Metric Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Kritis',
                    count: critical.length,
                    color: const Color(0xFFDC2626),
                    isSelected: _selectedFilter == 1,
                    onTap: () => setState(() => _selectedFilter = _selectedFilter == 1 ? 0 : 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Mendekati',
                    count: near.length,
                    color: const Color(0xFFD97706),
                    isSelected: _selectedFilter == 2,
                    onTap: () => setState(() => _selectedFilter = _selectedFilter == 2 ? 0 : 2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Kedaluwarsa',
                    count: expired.length,
                    color: AppColors.danger,
                    isSelected: _selectedFilter == 3,
                    onTap: () => setState(() => _selectedFilter = _selectedFilter == 3 ? 0 : 3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari nama obat, SKU, atau kategori...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                fillColor: AppColors.surface,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
            const SizedBox(height: 16),

            // List of Expiring Drugs
            if (filtered.isEmpty)
              _buildEmptyState()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, idx) {
                  final p = filtered[idx];
                  return _buildProductExpiryCard(p);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductExpiryCard(ProdukModel p) {
    final status = _getStatusInfo(p);
    final totalValue = p.stok * p.hargaJual;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: status.color.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: () => _showDetailModal(p),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Medicine Name + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nama,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p.kategori,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                            Text(
                              'SKU: ${p.kode}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expiry Countdown Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: status.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(status.icon, color: status.color, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          status.label,
                          style: TextStyle(
                            color: status.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              // Row 2: 3 Metrics (ED Date, Stock Left, Risk Value)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCol(
                      icon: Icons.calendar_month_outlined,
                      iconColor: status.color,
                      label: 'Tgl ED',
                      value: p.tglKadaluwarsa ?? '-',
                    ),
                  ),
                  Container(width: 1, height: 32, color: AppColors.border),
                  Expanded(
                    child: _buildMetricCol(
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.primary,
                      label: 'Sisa Stok',
                      value: '${p.stok} ${p.satuan}',
                    ),
                  ),
                  Container(width: 1, height: 32, color: AppColors.border),
                  Expanded(
                    child: _buildMetricCol(
                      icon: Icons.monetization_on_outlined,
                      iconColor: const Color(0xFFD97706),
                      label: 'Nilai Resiko',
                      value: CurrencyFormatter.format(totalValue),
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

  Widget _buildMetricCol({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_outlined, color: AppColors.success, size: 36),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kondisi Stok Obat Aman',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tidak ada obat yang membutuhkan penanganan kedaluwarsa pada kategori/pencarian ini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatusInfo {
  final String label;
  final String description;
  final Color color;
  final IconData icon;

  _StatusInfo({
    required this.label,
    required this.description,
    required this.color,
    required this.icon,
  });
}
