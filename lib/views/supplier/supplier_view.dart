import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../models/supplier_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/sync_service.dart';
import '../../widgets/app_confirm_dialog.dart';

class SupplierView extends StatefulWidget {
  const SupplierView({super.key});

  @override
  State<SupplierView> createState() => _SupplierViewState();
}

class _SupplierViewState extends State<SupplierView> {
  List<SupplierModel> _suppliers = [];
  List<SupplierModel> _filteredSuppliers = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('supplier', orderBy: 'nama ASC');
    setState(() {
      _suppliers = res.map((m) => SupplierModel.fromMap(m)).toList();
      _filter();
      _isLoading = false;
    });
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredSuppliers = List.from(_suppliers);
    } else {
      _filteredSuppliers = _suppliers.where((s) {
        return s.nama.toLowerCase().contains(q) ||
            s.kontak.toLowerCase().contains(q) ||
            s.telepon.toLowerCase().contains(q) ||
            s.alamat.toLowerCase().contains(q);
      }).toList();
    }
  }

  void _showAddEditModal({SupplierModel? supplier, bool isAdmin = true}) {
    if (supplier != null && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akses Ditolak: Hanya ADMIN yang dapat mengedit data supplier.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    final namaCtrl = TextEditingController(text: supplier?.nama ?? '');
    final kontakCtrl = TextEditingController(text: supplier?.kontak ?? '');
    final telpCtrl = TextEditingController(text: supplier?.telepon ?? '');
    final alamatCtrl = TextEditingController(text: supplier?.alamat ?? '');
    final formKey = GlobalKey<FormState>();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isLandscape ? 8 : 20),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 480,
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
                    Text(
                      supplier == null ? 'Tambah Supplier' : 'Edit Data Supplier',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
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

              // Form fields
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: namaCtrl,
                          decoration: InputDecoration(
                            labelText: 'Nama Perusahaan / PBF *',
                            hintText: 'Misal: PT Kimia Farma Trading & Dist',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Nama supplier wajib diisi' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: kontakCtrl,
                          decoration: InputDecoration(
                            labelText: 'Nama Kontak / Sales',
                            hintText: 'Misal: Bpk. Hendra (Sales Area)',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: telpCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Nomor Telepon / WhatsApp',
                            hintText: 'Misal: 081234567890',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: alamatCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Alamat Kantor / Gudang',
                            hintText: 'Jl. Industri Farmasi No. 12',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
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
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final db = await DatabaseHelper.instance.database;
                          SupplierModel savedSup;

                          if (supplier == null) {
                            savedSup = SupplierModel(
                              id: 'SUP-${DateTime.now().millisecondsSinceEpoch}',
                              nama: namaCtrl.text.trim(),
                              kontak: kontakCtrl.text.trim(),
                              telepon: telpCtrl.text.trim(),
                              alamat: alamatCtrl.text.trim(),
                            );
                            await db.insert('supplier', savedSup.toMap());
                          } else {
                            savedSup = SupplierModel(
                              id: supplier.id,
                              nama: namaCtrl.text.trim(),
                              kontak: kontakCtrl.text.trim(),
                              telepon: telpCtrl.text.trim(),
                              alamat: alamatCtrl.text.trim(),
                              status: supplier.status,
                            );
                            await db.update(
                              'supplier',
                              {
                                'nama': savedSup.nama,
                                'kontak': savedSup.kontak,
                                'telepon': savedSup.telepon,
                                'alamat': savedSup.alamat,
                              },
                              where: 'id = ?',
                              whereArgs: [supplier.id],
                            );
                          }

                          // Sinkronkan ke Cloud secara background
                          SyncService.instance.pushSingleSupplier(savedSup);

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            _loadSuppliers();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Supplier "${savedSup.nama}" berhasil disimpan.'),
                                backgroundColor: AppColors.primary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Text(
                          supplier == null ? 'Simpan Supplier' : 'Perbarui Supplier',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
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

  void _confirmDelete(SupplierModel sup, bool isAdmin) async {
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akses Ditolak: Hanya ADMIN yang dapat menghapus supplier.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final confirm = await AppConfirmDialog.show(
      context,
      title: 'Hapus Supplier?',
      message: 'Data distributor ini akan dihapus dari sistem apotek.',
      itemName: sup.nama,
      confirmLabel: 'Ya, Hapus',
      type: ConfirmType.danger,
    );

    if (confirm == true && mounted) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('supplier', where: 'id = ?', whereArgs: [sup.id]);

      // Hapus juga di Cloud
      SyncService.instance.deleteCloudSupplier(sup.id);

      if (mounted) {
        _loadSuppliers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supplier "${sup.nama}" berhasil dihapus.'),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.currentUser?.isAdmin == true;
    final isTablet = ResponsiveLayout.isTabletOrLarger(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS || isLandscape)
          ? FloatingActionButton.extended(
              heroTag: 'fab_supplier',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Supplier', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showAddEditModal(isAdmin: isAdmin),
            )
          : FloatingActionButton(
              heroTag: 'fab_supplier',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: 'Tambah Supplier',
              onPressed: () => _showAddEditModal(isAdmin: isAdmin),
              child: const Icon(Icons.add_rounded),
            ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, isLandscape ? 10 : 16, 16, isLandscape ? 8 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distributor & Supplier Obat',
                      style: TextStyle(fontSize: isLandscape ? 16 : 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${_suppliers.length} Supplier terdaftar',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: isLandscape ? 8 : 12),

            // Search Bar
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() => _filter()),
              decoration: InputDecoration(
                hintText: 'Cari supplier, nama sales, no telp...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _filter());
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Supplier Cards List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredSuppliers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                              SizedBox(height: 8),
                              Text('Tidak ada distributor ditemukan', style: TextStyle(color: AppColors.textMuted)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(0, 0, 0, isLandscape ? 20 : (isTablet ? 24 : 88)),
                          itemCount: _filteredSuppliers.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final s = _filteredSuppliers[idx];
                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE2E8F0),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.local_shipping_outlined,
                                            color: Colors.black87,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s.nama,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceMuted,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Pedagang Besar Farmasi (PBF)',
                                                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isAdmin)
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textMuted),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                                    SizedBox(width: 8),
                                                    Text('Edit Supplier'),
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
                                            onSelected: (v) {
                                              if (v == 'edit') _showAddEditModal(supplier: s, isAdmin: isAdmin);
                                              if (v == 'delete') _confirmDelete(s, isAdmin);
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    const Divider(height: 1, color: AppColors.border),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 6,
                                      children: [
                                        if (s.kontak.isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                                              const SizedBox(width: 4),
                                              Text(
                                                s.kontak,
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        if (s.telepon.isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.phone_outlined, size: 14, color: AppColors.primary),
                                              const SizedBox(width: 4),
                                              Text(
                                                s.telepon,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    if (s.alamat.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              s.alamat,
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
