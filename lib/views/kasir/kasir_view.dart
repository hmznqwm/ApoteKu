import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive_layout.dart';
import '../../models/cart_item_model.dart';
import '../../models/produk_model.dart';
import '../../models/transaksi_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/produk_provider.dart';
import '../../providers/transaksi_provider.dart';
import '../../widgets/barcode_scanner_dialog.dart';
import '../../widgets/receipt_dialog.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/hardware_barcode_listener.dart';

class KasirView extends StatefulWidget {
  const KasirView({super.key});

  @override
  State<KasirView> createState() => _KasirViewState();
}

class _KasirViewState extends State<KasirView> {
  final TextEditingController _searchCtrl = TextEditingController();

  // --- State Inline Payment ---
  final TextEditingController _bayarCtrl = TextEditingController();
  String _metode = 'CASH';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProdukProvider>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _bayarCtrl.dispose();
    super.dispose();
  }

  void _setExactCash(double total) {
    _bayarCtrl.text = total.toInt().toString();
  }

  void _setDirectAmount(double amount) {
    _bayarCtrl.text = amount.toInt().toString();
  }

  void _openBarcodeScanner() {
    BarcodeScannerDialog.scanContinuous(
      context,
      onScanned: (code) {
        _handleBarcodeResult(code);
      },
    );
  }

  void _showQuickAddUnitDialog(ProdukModel prod) {
    bool isEceran = false;
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double currentPrice = isEceran ? prod.effectiveHargaEceran : prod.hargaJual;
            final String currentUnit = isEceran ? prod.effectiveSatuanEceran : prod.satuan;
            final int inputQty = int.tryParse(qtyCtrl.text) ?? 1;
            final double currentTotal = currentPrice * inputQty;

            final media = MediaQuery.of(context);
            final isTablet = ResponsiveLayout.isTabletOrLarger(context);
            final double cardWidth = isTablet ? 480.0 : (media.size.width * 0.90).clamp(320.0, 440.0);

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                width: cardWidth,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header: Icon + Title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.medication_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prod.nama,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Stok: ${prod.stok} ${prod.satuan}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Label & Selector: Satuan Penjualan Dinamis
                    if (prod.hasEceranOption) ...[
                      const Text(
                        'Pilih Satuan Penjualan:',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Tab 1: Satuan Utama
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => isEceran = false),
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: !isEceran ? AppColors.primary : AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: !isEceran ? AppColors.primary : AppColors.border,
                                    width: 1.2,
                                  ),
                                  boxShadow: !isEceran
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      prod.satuan,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: !isEceran ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.format(prod.hargaJual),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: !isEceran ? Colors.white.withValues(alpha: 0.9) : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Tab 2: Satuan Eceran
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => isEceran = true),
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isEceran ? AppColors.primary : AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isEceran ? AppColors.primary : AppColors.border,
                                    width: 1.2,
                                  ),
                                  boxShadow: isEceran
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      prod.effectiveSatuanEceran,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isEceran ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.format(prod.effectiveHargaEceran),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: isEceran ? Colors.white.withValues(alpha: 0.9) : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Tampilan Single Unit untuk produk tanpa opsi eceran khusus
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Satuan: ${prod.satuan}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              CurrencyFormatter.format(prod.hargaJual),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Label & Stepper: Jumlah / Kuantitas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Jumlah / Kuantitas:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Stepper Container
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_rounded, size: 18, color: AppColors.textPrimary),
                                onPressed: () {
                                  int current = int.tryParse(qtyCtrl.text) ?? 1;
                                  if (current > 1) {
                                    setDialogState(() {
                                      qtyCtrl.text = (current - 1).toString();
                                    });
                                  }
                                },
                              ),
                              SizedBox(
                                width: 44,
                                child: TextField(
                                  controller: qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                  ),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                                onPressed: () {
                                  int current = int.tryParse(qtyCtrl.text) ?? 1;
                                  setDialogState(() {
                                    qtyCtrl.text = (current + 1).toString();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Total Price Summary Container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subtotal ($inputQty $currentUnit):',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(currentTotal),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons:
                    // 1) Tambah ke Keranjang
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                        label: const Text(
                          'Tambah ke Keranjang',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          final q = int.tryParse(qtyCtrl.text) ?? 1;
                          if (q > 0) {
                            context.read<CartProvider>().addItem(
                                  prod,
                                  isEceran: isEceran,
                                  qty: q,
                                );
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2) Batal Button (Placed at the VERY BOTTOM, matching style of Tambah ke Keranjang)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Batal',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditQtyDialog({required String itemKey, required CartItemModel item}) {
    final qtyCtrl = TextEditingController(text: item.qty.toString());
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Kuantitas ${item.produk.nama} (${item.selectedSatuan})'),
          content: TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Masukkan Jumlah Kuantitas',
              hintText: 'Contoh: 2',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final q = int.tryParse(qtyCtrl.text.trim());
                if (q != null) {
                  context.read<CartProvider>().updateQty(itemKey, q);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _handleBarcodeResult(String code) {
    final produkProv = context.read<ProdukProvider>();
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;
    final query = cleanCode.toLowerCase();

    // Prioritaskan exact match pada kode/barcode, kemudian nama, baru contains
    ProdukModel? match;
    for (final p in produkProv.allProducts) {
      if (p.kode.trim().toLowerCase() == query) {
        match = p;
        break;
      }
    }
    if (match == null) {
      for (final p in produkProv.allProducts) {
        if (p.nama.trim().toLowerCase() == query) {
          match = p;
          break;
        }
      }
    }
    if (match == null) {
      for (final p in produkProv.allProducts) {
        if (p.kode.trim().toLowerCase().contains(query)) {
          match = p;
          break;
        }
      }
    }
    if (match == null) {
      for (final p in produkProv.allProducts) {
        final pNama = p.nama.trim().toLowerCase();
        if (pNama.contains(query) || query.contains(pNama)) {
          match = p;
          break;
        }
      }
    }
    if (match == null) {
      final queryWords = query.split(RegExp(r'\s+')).where((w) => w.length >= 3).toList();
      int maxScore = 0;
      for (final p in produkProv.allProducts) {
        final pWords = p.nama.trim().toLowerCase().split(RegExp(r'\s+'));
        int score = 0;
        for (final qw in queryWords) {
          if (pWords.any((pw) => pw.contains(qw) || qw.contains(pw))) {
            score++;
          }
        }
        if (score > maxScore) {
          maxScore = score;
          match = p;
        }
      }
    }

    if (match != null && match.id.isNotEmpty) {
      _showQuickAddUnitDialog(match);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Obat dengan pencarian "$code" tidak ditemukan'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmClearCart({BuildContext? sheetContext}) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'Kosongkan Keranjang?',
      message: 'Semua obat yang ada di keranjang belanja akan dihapus.',
      confirmLabel: 'Ya, Kosongkan',
      type: ConfirmType.danger,
    );

    if (confirm == true && mounted) {
      context.read<CartProvider>().clearCart();
      if (sheetContext != null && sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }
    }
  }


  void _showReceiptDialog(TransaksiModel trx) {
    ReceiptDialog.show(context, trx);
  }

  Future<void> _processPayment() async {
    final cartProv = context.read<CartProvider>();
    final authProv = context.read<AuthProvider>();
    final produkProv = context.read<ProdukProvider>();
    final total = cartProv.grandTotal;
    final rawBayar =
        double.tryParse(_bayarCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
            0.0;
    final effectiveBayar = _metode == 'CASH' ? rawBayar : total;

    setState(() => _isProcessing = true);
    cartProv.setMetode(_metode);
    final trx = await cartProv.checkout(
      bayar: effectiveBayar,
      kasirEmail: authProv.currentUser?.email ?? 'kasir@pos.local',
      kasirName: authProv.currentUser?.name ?? 'Kasir',
      produkProvider: produkProv,
    );
    if (!mounted) return;
    context.read<TransaksiProvider>().loadTransactions();
    setState(() {
      _isProcessing = false;
      _metode = 'CASH';
      _bayarCtrl.clear();
    });
    _showReceiptDialog(trx!);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveLayout.isTabletOrLarger(context);

    return HardwareBarcodeListener(
      onBarcodeScanned: (code) {
        if (code.trim().isNotEmpty) {
          _handleBarcodeResult(code.trim());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
      ),
    );
  }

  // -------------------------------------------------------------
  // TABLET LAYOUT: 2-Column Split (Catalog 60% + Sticky Cart 40%)
  // -------------------------------------------------------------
  Widget _buildTabletLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactWidth = constraints.maxWidth < 750;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Catalog
            Expanded(
              flex: isCompactWidth ? 6 : 6,
              child: Column(
                children: [
                  _buildTopSearchBar(),
                  _buildCategoryPills(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await context.read<ProdukProvider>().loadProducts();
                      },
                      child: _buildProductGrid(
                        crossAxisCount: isCompactWidth ? 2 : 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            // Right Column: Persistent Sticky Cart
            Expanded(
              flex: isCompactWidth ? 4 : 4,
              child: _buildCartPanel(isTablet: true),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // MOBILE LAYOUT: Full Width Catalog + Floating Cart Bar
  // -------------------------------------------------------------
  Widget _buildMobileLayout() {
    final cartProv = context.watch<CartProvider>();

    return Column(
      children: [
        _buildTopSearchBar(),
        _buildCategoryPills(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await context.read<ProdukProvider>().loadProducts();
            },
            child: _buildProductGrid(crossAxisCount: 2),
          ),
        ),
        // Bottom Cart Summary Bar
        if (cartProv.items.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Tappable Cart Info & Total (Buka Rincian Keranjang)
                  Expanded(
                    child: InkWell(
                      onTap: _showMobileCartBottomSheet,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Badge(
                              label: Text('${cartProv.totalQuantity}'),
                              backgroundColor: AppColors.primary,
                              child: const Icon(Icons.shopping_cart_outlined, color: AppColors.primaryDark, size: 26),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      CurrencyFormatter.format(cartProv.grandTotal),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${cartProv.totalQuantity} item • Ketuk lihat keranjang',
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Button Masuk / Buka Keranjang
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _showMobileCartBottomSheet,
                    icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                    label: const Text(
                      'Keranjang',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopSearchBar() {
    final produkProv = context.read<ProdukProvider>();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, isLandscape ? 8 : 16, 16, isLandscape ? 6 : 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => produkProv.search(v),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  _handleBarcodeResult(v.trim());
                }
              },
              decoration: InputDecoration(
                hintText: 'Cari obat / ketik barcode...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: isLandscape ? 10 : 14),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          produkProv.search('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openBarcodeScanner,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPills() {
    final produkProv = context.watch<ProdukProvider>();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: produkProv.categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final cat = produkProv.categories[idx];
          final isSelected = cat == produkProv.selectedCategory;
          return InkWell(
            onTap: () => produkProv.setCategory(cat),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid({required int crossAxisCount}) {
    final produkProv = context.watch<ProdukProvider>();
    final cartProv = context.watch<CartProvider>();

    if (produkProv.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (produkProv.products.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: 300,
          alignment: Alignment.center,
          child: const Text(
            'Tidak ada obat ditemukan',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final isTablet = ResponsiveLayout.isTabletOrLarger(context);
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: isTablet ? 120 : 130,
      ),
      itemCount: produkProv.products.length,
      itemBuilder: (context, idx) {
        final prod = produkProv.products[idx];
        final inCartItem = cartProv.items[prod.id];
        final inCartQty = inCartItem?.qty ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inCartQty > 0 ? AppColors.primary : Colors.grey.shade300,
              width: inCartQty > 0 ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (prod.stok <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Stok obat habis!'),
                    backgroundColor: AppColors.danger,
                    duration: Duration(milliseconds: 700),
                  ),
                );
                return;
              }
              _showQuickAddUnitDialog(prod);
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Expanded(
                    child: Text(
                      prod.nama,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Price & Add Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Price
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            CurrencyFormatter.format(prod.hargaJual),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Stepper or Add Button
                      if (inCartQty > 0)
                        Container(
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => cartProv.updateQty(prod.id, inCartQty - 1),
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                                child: const SizedBox(
                                  width: 28,
                                  height: 30,
                                  child: Icon(Icons.remove, size: 16, color: AppColors.primary),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '$inCartQty',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  if (inCartQty >= prod.stok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Stok tidak mencukupi!'),
                                        backgroundColor: AppColors.warning,
                                        duration: Duration(milliseconds: 700),
                                      ),
                                    );
                                    return;
                                  }
                                  cartProv.updateQty(prod.id, inCartQty + 1);
                                },
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                                child: const SizedBox(
                                  width: 28,
                                  height: 30,
                                  child: Icon(Icons.add, size: 16, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        InkWell(
                          onTap: prod.stok <= 0
                              ? null
                              : () {
                                  final ok = cartProv.addItem(prod);
                                  if (!ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Stok tidak mencukupi!'),
                                        backgroundColor: AppColors.warning,
                                        duration: Duration(milliseconds: 700),
                                      ),
                                    );
                                  }
                                },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: prod.stok > 0 ? AppColors.primary : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              prod.stok > 0 ? Icons.add : Icons.block,
                              color: Colors.white,
                              size: 20,
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
    },
    );
  }

  // -------------------------------------------------------------
  // CART PANEL: Dual Pane for Tablet or Sheet for Mobile
  // -------------------------------------------------------------
  Widget _buildCartPanel({required bool isTablet, BuildContext? sheetContext}) {
    final cartProv = context.watch<CartProvider>();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final Widget itemsListWidget = cartProv.items.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.shopping_bag_outlined, size: 42, color: AppColors.textMuted),
                  SizedBox(height: 8),
                  Text(
                    'Keranjang masih kosong',
                    style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Pilih obat di katalog untuk menambahkan',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          )
        : ListView.separated(
            shrinkWrap: !isTablet,
            physics: isTablet ? const AlwaysScrollableScrollPhysics() : const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: cartProv.itemList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final itemKey = cartProv.items.keys.elementAt(idx);
              final item = cartProv.itemList[idx];

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.produk.nama,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                          onPressed: () => cartProv.removeItem(itemKey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Harga: ${CurrencyFormatter.format(item.customPrice)} / ${item.selectedSatuan}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Qty Stepper with Tappable Numeric Box
                        Row(
                          children: [
                            InkWell(
                              onTap: () => cartProv.updateQty(itemKey, item.qty - 1),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(Icons.remove, size: 14, color: AppColors.textPrimary),
                              ),
                            ),
                            InkWell(
                              onTap: () => _showEditQtyDialog(itemKey: itemKey, item: item),
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 36),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  '${item.qty}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => cartProv.updateQty(itemKey, item.qty + 1),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.add, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        // Subtotal
                        Text(
                          CurrencyFormatter.format(item.subtotal),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );

    return Container(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: isTablet ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // Cart Header (Overflow-safe with camera, trash, and close buttons)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isLandscape ? 6 : 10,
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Keranjang (${cartProv.totalQuantity})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isLandscape ? 14 : 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Trash / Kosongkan icon button (Icon only, no text)
                if (cartProv.items.isNotEmpty)
                  IconButton(
                    tooltip: 'Kosongkan Keranjang',
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.danger, size: 22),
                    onPressed: () => _confirmClearCart(sheetContext: sheetContext),
                  ),
                // Close / Back button for bottom sheet
                if (sheetContext != null)
                  IconButton(
                    tooltip: 'Tutup',
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Items List (Flexible for mobile adaptive height, Expanded for tablet)
          isTablet
              ? Expanded(child: itemsListWidget)
              : Flexible(child: itemsListWidget),

          // Footer: Total + Inline Payment
          Container(
            padding: EdgeInsets.fromLTRB(14, 12, 14, isLandscape ? 8 : 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL BAYAR',
                          style: TextStyle(
                            color: Color(0xFFCCFBF1),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              CurrencyFormatter.format(cartProv.grandTotal),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _buildMethodTab('CASH', 'Tunai'),
                        _buildMethodTab('QRIS', 'QRIS'),
                        _buildMethodTab('TRANSFER', 'Transfer'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_metode == 'CASH' && cartProv.items.isNotEmpty) ...[
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _bayarCtrl,
                      builder: (context, bayarValue, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _bayarCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                letterSpacing: 0.5,
                                color: Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 14),
                                  child: Text(
                                    'Rp',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                hintText: 'Nominal uang diterima',
                                hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                ),
                                suffixIcon: _bayarCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.cancel_rounded, size: 22, color: Color(0xFF94A3B8)),
                                        onPressed: () { _bayarCtrl.clear(); },
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildPayChip('Uang Pas', true, false, () => _setExactCash(cartProv.grandTotal)),
                                _buildPayChip('10.000', false, false, () => _setDirectAmount(10000)),
                                _buildPayChip('20.000', false, false, () => _setDirectAmount(20000)),
                                _buildPayChip('50.000', false, false, () => _setDirectAmount(50000)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Builder(builder: (ctx) {
                              final total = cartProv.grandTotal;
                              final rawBayar = double.tryParse(_bayarCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
                              final isOk = rawBayar >= total;
                              if (!isOk) return const SizedBox.shrink();
                              final amount = rawBayar - total;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Kembalian',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5,
                                            color: Color(0xFF166534))),
                                    Text(CurrencyFormatter.format(amount),
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15,
                                            color: Color(0xFF15803D))),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                  ] else if (_metode != 'CASH' && cartProv.items.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _metode == 'QRIS'
                                  ? 'Pastikan notifikasi QRIS pelanggan sudah berhasil'
                                  : 'Pastikan bukti transfer sudah dicek & sesuai nominal',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _bayarCtrl,
                    builder: (context, bayarValue, child) {
                      final total = cartProv.grandTotal;
                      final rawBayar = double.tryParse(_bayarCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
                      final canPay = cartProv.items.isNotEmpty && !_isProcessing && (_metode != 'CASH' || rawBayar >= total);
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canPay ? _processPayment : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.surfaceMuted,
                            padding: EdgeInsets.symmetric(vertical: isLandscape ? 10 : 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isProcessing
                              ? const SizedBox(height: 20, width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.receipt_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Selesaikan & Cetak Struk',
                                        style: TextStyle(fontSize: isLandscape ? 13 : 15, fontWeight: FontWeight.w800)),
                                  ],
                                ),
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
    );
  }

  void _showMobileCartBottomSheet() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * (isLandscape ? 0.95 : 0.88),
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _buildCartPanel(isTablet: false, sheetContext: ctx),
        ),
      ),
    );
  }

  Widget _buildMethodTab(String code, String label) {
    final isSel = _metode == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _metode = code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSel
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
              color: isSel ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPayChip(String label, bool isHighlight, bool isAdditive, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: isHighlight
                ? const Color(0xFF0D9488)
                : (isAdditive ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHighlight
                  ? const Color(0xFF0F766E)
                  : (isAdditive ? const Color(0xFFBAE6FD) : const Color(0xFFCBD5E1)),
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: isHighlight
                  ? Colors.white
                  : (isAdditive ? const Color(0xFF0369A1) : const Color(0xFF1E293B)),
            ),
          ),
        ),
      ),
    );
  }
}
