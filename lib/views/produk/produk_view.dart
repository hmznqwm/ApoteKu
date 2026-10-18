import 'dart:io';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive_layout.dart';
import '../../models/produk_model.dart';
import '../../providers/produk_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/activity_log_provider.dart';
import '../../widgets/barcode_dialog.dart';
import '../../widgets/barcode_scanner_dialog.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/hardware_barcode_listener.dart';

class ProdukView extends StatefulWidget {
  const ProdukView({super.key});

  @override
  State<ProdukView> createState() => _ProdukViewState();
}

class _ProdukViewState extends State<ProdukView> {
  final _searchCtrl = TextEditingController();

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
    super.dispose();
  }


  void _showAddEditModal({ProdukModel? product, bool isAdmin = true}) {
    if (product != null && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akses Ditolak: Hanya ADMIN yang dapat mengedit data obat.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => _ProductFormDialog(product: product),
    );
  }

  void _confirmDelete(ProdukModel prod, bool isAdmin) async {
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akses Ditolak: Hanya ADMIN yang dapat menghapus data obat.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final confirm = await AppConfirmDialog.show(
      context,
      title: 'Hapus Obat?',
      message: 'Data obat akan dihapus permanen dari sistem.',
      itemName: prod.nama,
      confirmLabel: 'Ya, Hapus',
      type: ConfirmType.danger,
    );

    if (confirm == true && mounted) {
      final auth = context.read<AuthProvider>();
      final logProv = context.read<ActivityLogProvider>();
      await context.read<ProdukProvider>().deleteProduct(prod.id);
      await logProv.logActivity(
        userName: auth.currentUser?.name ?? 'Staf Kasir',
        userRole: auth.currentUser?.role ?? 'KASIR',
        actionType: 'HAPUS',
        title: 'Menghapus Obat/Produk',
        details: 'Menghapus produk "${prod.nama}" (${prod.kode}) dari katalog.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Obat "${prod.nama}" berhasil dihapus'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final produkProv = context.watch<ProdukProvider>();
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.currentUser?.isAdmin == true;
    final isTablet = ResponsiveLayout.isTabletOrLarger(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return HardwareBarcodeListener(
      onBarcodeScanned: (code) {
        if (code.trim().isNotEmpty) {
          _searchCtrl.text = code.trim();
          produkProv.search(code.trim());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
      floatingActionButton: (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS || isLandscape)
          ? FloatingActionButton.extended(
              heroTag: 'fab_produk',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Obat', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showAddEditModal(),
            )
          : FloatingActionButton(
              heroTag: 'fab_produk',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: 'Tambah Obat',
              onPressed: () => _showAddEditModal(),
              child: const Icon(Icons.add_rounded),
            ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, isLandscape ? 8 : 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search & Filter Toolbar
            if (isLandscape) ...[
              // Landscape: Search and Action Buttons in a Single Clean Horizontal Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => produkProv.search(v),
                      decoration: InputDecoration(
                        hintText: 'Cari obat atau kode barang...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                ],
              ),
            ] else ...[
              // Portrait: Full width search bar
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => produkProv.search(v),
                decoration: InputDecoration(
                  hintText: 'Cari obat atau kode barang...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            produkProv.search('');
                          },
                        )
                      : null,
                ),
              ),
            ],
            SizedBox(height: isLandscape ? 6 : 10),
            // Horizontal Category Pills
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: produkProv.categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final cat = produkProv.categories[idx];
                  final isSel = cat == produkProv.selectedCategory;
                  return InkWell(
                    onTap: () => produkProv.setCategory(cat),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSel ? AppColors.primary : AppColors.border,
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                            color: isSel ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: isLandscape ? 6 : 10),

            // Products Responsive List / Table
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await context.read<ProdukProvider>().loadProducts();
                },
                child: produkProv.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : produkProv.products.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: 300,
                          alignment: Alignment.center,
                          child: const Text(
                            'Tidak ada obat ditemukan',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : _buildResponsiveProducts(produkProv.products, isTablet, isAdmin),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTabletTable(List<ProdukModel> list, bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text('Kode Barang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Expanded(flex: 3, child: Text('Nama Obat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Expanded(flex: 2, child: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Expanded(flex: 2, child: Text('Harga Jual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Expanded(flex: 1, child: Text('Stok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Expanded(flex: 2, child: Text('Kedaluwarsa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Expanded(flex: 2, child: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ],
          ),
        ),
        // Rows
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: list.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, idx) {
              final p = list[idx];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () => BarcodeDialog.show(context, p),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Flexible(child: Text(p.kode, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.primaryDark), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(p.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 2),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(p.kategori, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        CurrencyFormatter.format(p.hargaJual),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          p.stok <= 0 ? 'Habis' : '${p.stok}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            color: p.stok <= 0
                                ? const Color(0xFFEF4444)
                                : p.stok <= 5
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.tglKadaluwarsa ?? '-',
                        style: TextStyle(
                          fontSize: 12,
                          color: p.isExpired
                              ? AppColors.danger
                              : p.isCriticalExpiry
                              ? AppColors.danger
                              : p.isNearExpiry
                              ? AppColors.warning
                              : AppColors.textSecondary,
                          fontWeight: p.isNearExpiry || p.isCriticalExpiry ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Lihat Barcode',
                            icon: const Icon(Icons.qr_code_2_rounded, size: 18, color: AppColors.primary),
                            onPressed: () => BarcodeDialog.show(context, p),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          if (isAdmin) ...[
                            IconButton(
                              tooltip: 'Edit Obat',
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                              onPressed: () => _showAddEditModal(product: p, isAdmin: isAdmin),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Hapus Obat',
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                              onPressed: () => _confirmDelete(p, isAdmin),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveProducts(List<ProdukModel> list, bool isTablet, bool isAdmin) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isTablet && constraints.maxWidth > 850) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: _buildTabletTable(list, isAdmin),
          );
        }

        final isWide = constraints.maxWidth > 580;
        final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
        if (isWide) {
          return Scrollbar(
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(0, 4, 0, isLand ? 20 : (isTablet ? 20 : 96)),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 440,
              mainAxisExtent: 78,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: list.length,
            itemBuilder: (context, idx) => _buildProductCard(list[idx], isAdmin),
          ),
        );
      }

      return Scrollbar(
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 4, 0, isLand ? 20 : (isTablet ? 20 : 96)),
          itemCount: list.length,
          separatorBuilder: (context, index) => const SizedBox(height: 6),
          itemBuilder: (context, idx) => _buildProductCard(list[idx], isAdmin),
        ),
      );
      },
    );
  }

  Widget _buildProductCard(ProdukModel p, bool isAdmin) {
    final isLowStock = p.stok <= 5;
    final isOutOfStock = p.stok <= 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => BarcodeDialog.show(context, p),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.nama,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'barcode',
                          child: Row(
                            children: [
                              Icon(Icons.qr_code_2_rounded, size: 18, color: AppColors.textPrimary),
                              SizedBox(width: 8),
                              Text('Lihat Detail / Barcode'),
                            ],
                          ),
                        ),
                        if (isAdmin) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Edit Obat'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                SizedBox(width: 8),
                                Text('Hapus', style: TextStyle(color: AppColors.danger)),
                              ],
                            ),
                          ),
                        ],
                      ],
                      onSelected: (v) {
                        if (v == 'barcode') BarcodeDialog.show(context, p);
                        if (v == 'edit') _showAddEditModal(product: p, isAdmin: isAdmin);
                        if (v == 'delete') _confirmDelete(p, isAdmin);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    CurrencyFormatter.format(p.hargaJual),
                    style: const TextStyle(
                      color: Color(0xFF0D9488),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    isOutOfStock ? 'Habis' : 'Stok: ${p.stok}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isOutOfStock
                          ? const Color(0xFFEF4444)
                          : isLowStock
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (p.hasEceranOption) ...[
                    Text(
                      'Eceran: ${CurrencyFormatter.format(p.effectiveHargaEceran)} / ${p.effectiveSatuanEceran}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      p.satuan,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                  ] else ...[
                    Text(
                      'Satuan: ${p.satuan}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// ADD / EDIT PRODUCT MODAL (CLEAN SINGLE FORM - NO TABS / NO AI SLOP)
// -------------------------------------------------------------
class _ProductFormDialog extends StatefulWidget {
  final ProdukModel? product;
  const _ProductFormDialog({this.product});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _kodeCtrl;
  late TextEditingController _namaCtrl;
  late TextEditingController _hargaBeliCtrl;
  late TextEditingController _hargaJualCtrl;
  late TextEditingController _stokCtrl;
  late TextEditingController _edCtrl;

  late String _selectedKategori;
  late String _selectedSatuan;

  final List<String> _kategoriList = [
    'Obat Bebas',
    'Bebas Terbatas',
    'Obat Keras',
    'Suplemen & Vitamin',
    'Sirup & Suspensi',
    'Salep & Gel',
    'Alat Kesehatan',
    'Herbal & Jamu',
    'Lainnya',
  ];

  final List<String> _satuanList = [
    'STRIP',
    'TABLET',
    'BOTOL',
    'BOX',
    'PCS',
    'TUBE',
    'AMPUL',
    'SACHET',
    'KAPLET',
    'BLISTER',
    'VIAL',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _kodeCtrl = TextEditingController(
      text: p?.kode ?? '899${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
    );
    _namaCtrl = TextEditingController(text: p?.nama ?? '');

    // Kategori initialization
    final initialKategori = p?.kategori ?? 'Obat Bebas';
    if (!_kategoriList.contains(initialKategori) && initialKategori.trim().isNotEmpty) {
      _kategoriList.insert(0, initialKategori);
    }
    _selectedKategori = initialKategori.trim().isEmpty ? 'Obat Bebas' : initialKategori;

    // Satuan initialization
    final initialSatuan = (p?.satuan ?? 'STRIP').toUpperCase();
    if (!_satuanList.contains(initialSatuan) && initialSatuan.trim().isNotEmpty) {
      _satuanList.insert(0, initialSatuan);
    }
    _selectedSatuan = initialSatuan.trim().isEmpty ? 'STRIP' : initialSatuan;

    _hargaBeliCtrl = TextEditingController(
      text: p != null ? p.hargaBeli.toInt().toString() : '5000',
    );
    _hargaJualCtrl = TextEditingController(
      text: p != null ? p.hargaJual.toInt().toString() : '8000',
    );
    _stokCtrl = TextEditingController(text: p?.stok.toString() ?? '20');

    final defaultEd = DateTime.now().add(const Duration(days: 730));
    final defaultEdStr =
        "${defaultEd.year}-${defaultEd.month.toString().padLeft(2, '0')}-${defaultEd.day.toString().padLeft(2, '0')}";
    _edCtrl = TextEditingController(text: p?.tglKadaluwarsa ?? defaultEdStr);

    _hargaBeliCtrl.addListener(() => setState(() {}));
    _hargaJualCtrl.addListener(() => setState(() {}));
    _kodeCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _kodeCtrl.dispose();
    _namaCtrl.dispose();
    _hargaBeliCtrl.dispose();
    _hargaJualCtrl.dispose();
    _stokCtrl.dispose();
    _edCtrl.dispose();
    super.dispose();
  }

  void _generateKodeBarang() {
    setState(() {
      _kodeCtrl.text = '899${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    });
  }

  Future<void> _pickExpiryDate() async {
    DateTime initial = DateTime.now().add(const Duration(days: 365));
    if (_edCtrl.text.isNotEmpty) {
      try {
        initial = DateTime.parse(_edCtrl.text.trim());
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Pilih Tanggal Kedaluwarsa',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (picked != null) {
      setState(() {
        _edCtrl.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _setExpiryShortcut(int months) {
    final target = DateTime.now().add(Duration(days: (months * 30.5).round()));
    setState(() {
      _edCtrl.text =
          "${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}";
    });
  }

  bool _isSaving = false;

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final id = widget.product?.id ?? 'PRD-${DateTime.now().millisecondsSinceEpoch}';
      final cleanBeli = _hargaBeliCtrl.text.replaceAll('.', '').replaceAll(',', '.').trim();
      final cleanJual = _hargaJualCtrl.text.replaceAll('.', '').replaceAll(',', '.').trim();

      final prod = ProdukModel(
        id: id,
        kode: _kodeCtrl.text.trim(),
        nama: _namaCtrl.text.trim(),
        kategori: _selectedKategori,
        hargaBeli: double.tryParse(cleanBeli) ?? 0.0,
        hargaJual: double.tryParse(cleanJual) ?? 0.0,
        stok: int.tryParse(_stokCtrl.text.trim()) ?? 0,
        satuan: _selectedSatuan,
        tglKadaluwarsa: _edCtrl.text.trim(),
        status: 'AKTIF',
        createdAt: widget.product?.createdAt ?? DateTime.now().toIso8601String(),
      );

      final success = await context.read<ProdukProvider>().saveProduct(prod);

      if (mounted) {
        if (success) {
          final auth = context.read<AuthProvider>();
          final isNew = widget.product == null;
          context.read<ActivityLogProvider>().logActivity(
            userName: auth.currentUser?.name ?? 'Staf Kasir',
            userRole: auth.currentUser?.role ?? 'KASIR',
            actionType: isNew ? 'TAMBAH' : 'EDIT',
            title: isNew ? 'Menambah Obat/Produk Baru' : 'Mengubah Data Obat/Produk',
            details: isNew
                ? 'Menambahkan produk "${prod.nama}" (${prod.satuan}) - Rp ${prod.hargaJual.toInt()} - Stok: ${prod.stok}'
                : 'Mengubah data produk "${prod.nama}" (${prod.satuan}) - Rp ${prod.hargaJual.toInt()} - Stok: ${prod.stok}',
          );
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Obat "${prod.nama}" berhasil disimpan!')),
                ],
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menyimpan obat. Silakan periksa data Anda.'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double beli = double.tryParse(_hargaBeliCtrl.text) ?? 0.0;
    final double jual = double.tryParse(_hargaJualCtrl.text) ?? 0.0;
    final double marginNominal = jual - beli;
    final double marginPersen = beli > 0 ? (marginNominal / beli) * 100 : 0.0;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isLandscape ? 12 : 24,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.medication_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product == null ? 'Tambah Obat' : 'Edit Obat',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Lengkapi data obat untuk katalog apotek',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Form Content (Single Page Scrollable)
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- SECTION 1: INFORMASI OBAT ---
                      _buildSectionTitle('Informasi Obat'),
                      const SizedBox(height: 12),

                      _buildFieldLabel('Nama Obat & Dosis *'),
                      TextFormField(
                        controller: _namaCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Paracetamol 500mg Kaplet',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Nama obat wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),

                      _buildFieldLabel('Kode / Barcode *'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _kodeCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Kode barcode',
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Kode wajib diisi' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.primary),
                            label: const Text('Scan', style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
                            onPressed: () async {
                              final scanned = await BarcodeScannerDialog.scanSingle(context);
                              if (scanned != null && scanned.isNotEmpty) {
                                setState(() => _kodeCtrl.text = scanned);
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            style: IconButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.all(12),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textSecondary),
                            tooltip: 'Generate Kode Baru',
                            onPressed: _generateKodeBarang,
                          ),
                        ],
                      ),
                      if (_kodeCtrl.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'Barcode Preview:',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 28,
                                  child: BarcodeWidget(
                                    barcode: Barcode.code128(),
                                    data: _kodeCtrl.text.trim(),
                                    drawText: false,
                                    errorBuilder: (context, error) => const SizedBox(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Kategori & Satuan (Clean Dropdowns side by side)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Kategori Obat *'),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedKategori,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: _kategoriList.map((cat) {
                                    return DropdownMenuItem<String>(
                                      value: cat,
                                      child: Text(cat, style: const TextStyle(fontSize: 13)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedKategori = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Satuan *'),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedSatuan,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: _satuanList.map((sat) {
                                    return DropdownMenuItem<String>(
                                      value: sat,
                                      child: Text(sat, style: const TextStyle(fontSize: 13)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedSatuan = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // --- SECTION 2: HARGA & MARGIN ---
                      _buildSectionTitle('Harga & Margin'),
                      const SizedBox(height: 12),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Harga Beli (Modal)'),
                                TextFormField(
                                  controller: _hargaBeliCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    prefixText: 'Rp ',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Harga Jual *'),
                                TextFormField(
                                  controller: _hargaJualCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    prefixText: 'Rp ',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Clean subtle margin display
                      Row(
                        children: [
                          Icon(
                            marginNominal >= 0 ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
                            size: 14,
                            color: marginNominal >= 0 ? AppColors.primary : AppColors.danger,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            marginNominal >= 0
                                ? 'Estimasi Margin: ${CurrencyFormatter.format(marginNominal)} (${marginPersen.toStringAsFixed(1)}%)'
                                : 'Harga jual lebih rendah dari harga modal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: marginNominal >= 0 ? AppColors.textSecondary : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // --- SECTION 3: STOK & KEDALUWARSA ---
                      _buildSectionTitle('Stok & Kedaluwarsa'),
                      const SizedBox(height: 12),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Stok *'),
                                TextFormField(
                                  controller: _stokCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    suffixText: _selectedSatuan,
                                    suffixStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Kedaluwarsa (ED) *'),
                                TextFormField(
                                  controller: _edCtrl,
                                  readOnly: true,
                                  onTap: _pickExpiryDate,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                                      onPressed: _pickExpiryDate,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Quick expiry pill buttons (Neat Row without extra text)
                      Row(
                        children: [
                          Expanded(child: _buildEdChip('+6 Bln', 6)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildEdChip('+1 Thn', 12)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildEdChip('+2 Thn', 24)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildEdChip('+3 Thn', 36)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.save_outlined, size: 18),
                              SizedBox(width: 6),
                              Text('Simpan Obat', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildEdChip(String label, int months) {
    return InkWell(
      onTap: () => _setExpiryShortcut(months),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

