import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/produk_provider.dart';
import '../../../providers/transaksi_provider.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class SalesChartCard extends StatefulWidget {
  const SalesChartCard({super.key});

  @override
  State<SalesChartCard> createState() => _SalesChartCardState();
}

class _SalesChartCardState extends State<SalesChartCard> {
  String _period = '7_hari'; // 'hari' | '7_hari' | '30_hari' | 'kustom'
  DateTimeRange? _customRange;

  // Harmonious modern color palette for Donut Chart (Green/Teal theme)
  static const List<Color> _donutColors = [
    Color(0xFF0F766E), // Dark Teal
    Color(0xFF10B981), // Emerald
    Color(0xFF34D399), // Light Emerald
    Color(0xFF6EE7B7), // Lighter Emerald
    Color(0xFF059669), // Green
    Color(0xFF047857), // Dark Green
    Color(0xFF064E3B), // Very Dark Green
  ];

  Future<void> _selectCustomRange() async {
    final now = DateTime.now();
    DateTime start = _customRange?.start ?? now.subtract(const Duration(days: 6));
    DateTime end = _customRange?.end ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: start, end: end),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: const Size(800, 600),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customRange = picked;
        _period = 'kustom';
      });
    }
  }

  String _formatShortCurrency(double value) {
    if (value >= 1000000000000) {
      final v = value / 1000000000000;
      return 'Rp ${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}T';
    } else if (value >= 1000000000) {
      final v = value / 1000000000;
      return 'Rp ${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}M';
    } else if (value >= 1000000) {
      final v = value / 1000000;
      return 'Rp ${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}jt';
    } else if (value >= 1000) {
      final v = value / 1000;
      return 'Rp ${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}rb';
    }
    return 'Rp ${value.toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    final trxProv = context.watch<TransaksiProvider>();
    final prodProv = context.watch<ProdukProvider>();

    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    if (_period == 'hari') {
      start = now;
    } else if (_period == '7_hari') {
      start = now.subtract(const Duration(days: 6));
    } else if (_period == '30_hari') {
      start = now.subtract(const Duration(days: 29));
    } else {
      start = _customRange?.start ?? now.subtract(const Duration(days: 6));
      end = _customRange?.end ?? now;
    }

    start = DateTime(start.year, start.month, start.day);
    end = DateTime(end.year, end.month, end.day, 23, 59, 59);

    final diff = end.difference(start).inDays;

    List<String> trendLabels = [];
    List<String> trendFullDates = [];
    List<double> trendData = [];
    List<double> trendProfitData = [];

    if (_period == 'hari') {
      for (int i = 0; i < 24; i += 2) {
        trendLabels.add('${i.toString().padLeft(2, '0')}:00');
        trendFullDates.add('${DateFormat('dd MMM yyyy').format(start)} ${i.toString().padLeft(2, '0')}:00');
        trendData.add(0.0);
        trendProfitData.add(0.0);
      }
    } else {
      for (int i = 0; i <= diff; i++) {
        final d = start.add(Duration(days: i));
        trendLabels.add(DateFormat('dd/MM').format(d));
        trendFullDates.add(DateFormat('dd MMM yyyy').format(d));
        trendData.add(0.0);
        trendProfitData.add(0.0);
      }
    }

    double totalOmset = 0.0;
    Map<String, int> categoryCounts = {};
    Map<String, int> productCounts = {};

    for (var trx in trxProv.transactions) {
      if (trx.status == 'REFUND') continue;

      DateTime trxDate;
      try {
        trxDate = DateTime.parse(trx.tanggal);
      } catch (e) {
        continue;
      }

      if (trxDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
          trxDate.isBefore(end.add(const Duration(seconds: 1)))) {
        
        int idx;
        if (_period == 'hari') {
          // Because we use 2-hour intervals for labels to avoid clutter
          idx = (trxDate.hour / 2).floor();
        } else {
          idx = trxDate.difference(start).inDays;
        }

        if (idx >= 0 && idx < trendData.length) {
          trendData[idx] += trx.total;
          trendProfitData[idx] += trx.omsetBersih;
        }

        totalOmset += trx.total;

        for (var detail in trx.details) {
          String kat = 'Lainnya';
          try {
            final prod = prodProv.allProducts.firstWhere(
              (p) => p.id == detail.produkId,
            );
            kat = prod.kategori;
            if (kat.isEmpty) kat = 'Lainnya';
          } catch (_) {}

          String name = detail.nama;

          categoryCounts[kat] = (categoryCounts[kat] ?? 0) + detail.qty;
          productCounts[name] = (productCounts[name] ?? 0) + detail.qty;
        }
      }
    }

    int totalItemsSold = categoryCounts.values.fold(0, (sum, val) => sum + val);
    List<Map<String, dynamic>> topCategories = categoryCounts.entries.map((e) {
      double pct = totalItemsSold > 0 ? (e.value / totalItemsSold) * 100 : 0.0;
      return {
        'kategori': e.key,
        'percentage': pct,
      };
    }).toList();
    topCategories.sort((a, b) => (b['percentage'] as double).compareTo(a['percentage'] as double));

    List<Map<String, dynamic>> topProducts = productCounts.entries.map((e) {
      return {
        'nama': e.key,
        'qty': e.value,
      };
    }).toList();
    topProducts.sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
    if (topProducts.length > 5) {
      topProducts = topProducts.sublist(0, 5);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Segmented Filter Pills ──────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildFilterPill('hari', 'Hari Ini'),
              _buildFilterPill('7_hari', '7 Hari'),
              _buildFilterPill('30_hari', '30 Hari'),
              _buildFilterPill('kustom', 'Kustom', isCustom: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 2. Tren Penjualan (Line Chart Card) ────────────────────
                _buildSalesTrendCard(trendLabels, trendData, trendProfitData, trendFullDates),
                const SizedBox(height: 16),

                if (isWide) ...[
                  // Desktop: Tampil Bersisian (2 Kolom)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTopCategoriesCard(topCategories, totalOmset),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTopProductsCard(topProducts),
                      ),
                    ],
                  ),
                ] else ...[
                  // Mobile / Android: Tumpuk Vertikal
                  _buildTopCategoriesCard(topCategories, totalOmset),
                  const SizedBox(height: 16),
                  _buildTopProductsCard(topProducts),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterPill(String key, String label, {bool isCustom = false}) {
    final isSelected = _period == key;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isCustom) {
            _selectCustomRange();
          } else {
            if (_period != key) {
              setState(() => _period = key);
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSalesTrendCard(
    List<String> labels,
    List<double> values,
    List<double> profitValues,
    List<String> fullDates,
  ) {
    double maxY = values.isNotEmpty ? values.reduce(max) : 0;
    double maxProfitY = profitValues.isNotEmpty ? profitValues.reduce(max) : 0;
    double highestY = max(maxY, maxProfitY);
    if (highestY <= 0) highestY = 100000;
    highestY = highestY * 1.35;

    final spots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    final profitSpots = <FlSpot>[];
    for (int i = 0; i < profitValues.length; i++) {
      profitSpots.add(FlSpot(i.toDouble(), profitValues[i]));
    }

    final hasData = values.any((v) => v > 0) || profitValues.any((v) => v > 0);

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tren Penjualan (Rp)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                children: [
                  _buildLegendDot(const Color(0xFF0F766E), 'Omset'), // Dark Teal
                  const SizedBox(width: 10),
                  _buildLegendDot(const Color(0xFF10B981), 'Profit'), // Emerald
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: !hasData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.show_chart, size: 40, color: AppColors.textMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        const Text(
                          'Belum ada transaksi di periode ini',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      Widget buildLineChart(bool showLeftTitles, double width, int step) {
                        return SizedBox(
                          width: width,
                          height: 220,
                          child: LineChart(
                            LineChartData(
                              clipData: const FlClipData.none(),
                              minX: 0,
                              maxX: spots.isNotEmpty ? (spots.length - 1).toDouble() : 1,
                              minY: 0,
                              maxY: highestY,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: highestY / 3,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: AppColors.border.withValues(alpha: 0.4),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: showLeftTitles,
                                    reservedSize: 44,
                                    interval: highestY / 3,
                                    getTitlesWidget: (value, meta) {
                                      if (value == 0) {
                                        return const Text('Rp 0', style: TextStyle(fontSize: 10, color: AppColors.textMuted));
                                      }
                                      return Text(
                                        _formatShortCurrency(value),
                                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      if (idx >= 0 && idx < labels.length) {
                                        if (idx % step == 0 || idx == labels.length - 1) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              labels[idx],
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textMuted,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          );
                                        }
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineTouchData: LineTouchData(
                                handleBuiltInTouches: true,
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipColor: (_) => const Color(0xFF0F172A),
                                  getTooltipItems: (touchedSpots) {
                                    if (touchedSpots.isEmpty) return [];
                                    final firstSpot = touchedSpots.first;
                                    final idx = firstSpot.spotIndex;
                                    final dateText = (idx >= 0 && idx < fullDates.length) ? fullDates[idx] : '';
                                    final omsetVal = (idx >= 0 && idx < values.length) ? values[idx] : 0.0;
                                    final profitVal = (idx >= 0 && idx < profitValues.length) ? profitValues[idx] : 0.0;

                                    return touchedSpots.map((spot) {
                                      if (spot.barIndex == 0) {
                                        return LineTooltipItem(
                                          '$dateText\n',
                                          const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                          children: [
                                            TextSpan(
                                              text: 'Omset:  ${CurrencyFormatter.format(omsetVal)}\n',
                                              style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 12.5, fontWeight: FontWeight.w700),
                                            ),
                                            TextSpan(
                                              text: 'Profit: ${CurrencyFormatter.format(profitVal)}',
                                              style: const TextStyle(color: Color(0xFF34D399), fontSize: 12.5, fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        );
                                      }
                                      return null;
                                    }).toList();
                                  },
                                ),
                              ),
                              lineBarsData: [
                                // Line 1: Omset (Dark Teal)
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  curveSmoothness: 0.35,
                                  preventCurveOverShooting: true,
                                  barWidth: 3.2,
                                  isStrokeCapRound: true,
                                  color: const Color(0xFF0F766E),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        const Color(0xFF0F766E).withValues(alpha: 0.3),
                                        const Color(0xFF0F766E).withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                      radius: 3.5,
                                      color: const Color(0xFF0F766E),
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    ),
                                  ),
                                ),
                                // Line 2: Profit (Emerald)
                                LineChartBarData(
                                  spots: profitSpots,
                                  isCurved: true,
                                  curveSmoothness: 0.35,
                                  preventCurveOverShooting: true,
                                  barWidth: 3.0,
                                  isStrokeCapRound: true,
                                  color: const Color(0xFF10B981),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        const Color(0xFF10B981).withValues(alpha: 0.25),
                                        const Color(0xFF10B981).withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                      radius: 3.5,
                                      color: const Color(0xFF10B981),
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final step = (labels.length > 7) ? (labels.length / 6).ceil() : 1;

                      return buildLineChart(true, constraints.maxWidth, step);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTopCategoriesCard(List<Map<String, dynamic>> categories, double totalOmset) {
    final hasData = categories.isNotEmpty && totalOmset > 0;

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kategori Terlaris',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          if (!hasData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada data kategori di periode ini',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    children: List.generate(categories.length > 5 ? 5 : categories.length, (idx) {
                      final cat = categories[idx];
                      final color = _donutColors[idx % _donutColors.length];
                      final name = cat['kategori']?.toString() ?? '-';
                      final pct = (cat['percentage'] as num? ?? 0).toDouble();

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.5),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2.5,
                            centerSpaceRadius: 38,
                            startDegreeOffset: -90,
                            sections: List.generate(categories.length > 5 ? 5 : categories.length, (idx) {
                              final cat = categories[idx];
                              final color = _donutColors[idx % _donutColors.length];
                              final pct = (cat['percentage'] as num? ?? 0).toDouble();
                              return PieChartSectionData(
                                color: color,
                                value: pct,
                                showTitle: false,
                                radius: 18,
                              );
                            }),
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatShortCurrency(totalOmset),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Total Omset',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(List<Map<String, dynamic>> products) {
    final maxQty = products.isNotEmpty
        ? products.map((p) => (p['qty'] as num? ?? 0).toDouble()).reduce(max)
        : 1.0;

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 5 Produk Paling Laris',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada produk terjual di periode ini',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            Column(
              children: List.generate(products.length, (idx) {
                final p = products[idx];
                final name = p['nama']?.toString() ?? '-';
                final qty = (p['qty'] as num? ?? 0).toInt();
                final ratio = maxQty > 0 ? (qty / maxQty).clamp(0.05, 1.0) : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final barWidth = constraints.maxWidth * ratio;
                            return Stack(
                              children: [
                                Container(
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: AppColors.border.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                Container(
                                  width: barWidth,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$qty x',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}
