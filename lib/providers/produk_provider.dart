import 'dart:async';
import 'package:flutter/material.dart';
import '../core/database/database_helper.dart';
import '../models/produk_model.dart';
import '../services/sync_service.dart';

class ProdukProvider extends ChangeNotifier {
  List<String> _dbGejalaList = [];
  List<ProdukModel> _allProducts = [];
  List<ProdukModel> _filteredProducts = [];
  List<String> _categories = ['Semua'];
  String _selectedCategory = 'Semua';
  final Set<String> _selectedGejala = {};
  String _searchQuery = '';
  bool _isLoading = false;
  StreamSubscription? _syncSub;

  List<ProdukModel> get products => _filteredProducts;
  List<ProdukModel> get allProducts => _allProducts;
  List<String> get categories => _categories;
  String get selectedCategory => _selectedCategory;
  Set<String> get selectedGejala => _selectedGejala;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  List<String> get dbGejalaList => _dbGejalaList;

  List<String> get allAvailableGejala {
    final set = <String>{..._dbGejalaList};
    for (final p in _allProducts) {
      for (final g in p.listIndikasi) {
        if (g.isNotEmpty) set.add(g);
      }
    }
    return set.toList();
  }

  ProdukProvider() {
    loadProducts();
    _syncSub = SyncService.instance.onSyncComplete.listen((_) {
      loadProducts();
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  // Alerts
  List<ProdukModel> get lowStockProducts =>
      _allProducts.where((p) => p.isLowStock).toList();

  List<ProdukModel> get expiringProducts =>
      _allProducts.where((p) => p.isExpired || p.isCriticalExpiry || p.isNearExpiry).toList();

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    final db = await DatabaseHelper.instance.database;
    final res = await db.query('produk', orderBy: 'nama ASC');
    _allProducts = res.map((m) => ProdukModel.fromMap(m)).toList();

    // Muat daftar gejala langsung dari tabel database SQLite
    try {
      final gejalaRows = await DatabaseHelper.instance.getGejalaList();
      _dbGejalaList = gejalaRows
          .map((r) => r['nama']?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error getGejalaList: $e');
    }

    // Refresh categories
    final cats = {'Semua'};
    for (var p in _allProducts) {
      if (p.kategori.isNotEmpty) cats.add(p.kategori);
    }
    _categories = cats.toList();

    _applyFilter();
    _isLoading = false;
    notifyListeners();
  }

  /// Tambah gejala baru langsung tersimpan ke database SQLite & trigger sinkronisasi
  Future<String> tambahGejala(String nama) async {
    final clean = nama.trim();
    if (clean.isEmpty) return '';

    try {
      final id = await DatabaseHelper.instance.insertGejala(clean);
      if (!_dbGejalaList.contains(clean)) {
        _dbGejalaList.add(clean);
        notifyListeners();
      }
      // Trigger sinkronisasi ke server web / cloud
      SyncService.instance.pushGejala(clean, id);
      return id;
    } catch (e) {
      debugPrint('Error tambahGejala: $e');
      return '';
    }
  }

  void setCategory(String cat) {
    _selectedCategory = cat;
    _applyFilter();
    notifyListeners();
  }

  void toggleGejala(String gejala) {
    if (_selectedGejala.contains(gejala)) {
      _selectedGejala.remove(gejala);
    } else {
      _selectedGejala.add(gejala);
    }
    _applyFilter();
    notifyListeners();
  }

  void clearGejala() {
    if (_selectedGejala.isNotEmpty) {
      _selectedGejala.clear();
      _applyFilter();
      notifyListeners();
    }
  }

  void clearAllFilters() {
    _selectedCategory = 'Semua';
    _selectedGejala.clear();
    _searchQuery = '';
    _applyFilter();
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    _filteredProducts = _allProducts.where((p) {
      final matchesCat = _selectedCategory == 'Semua' || p.kategori == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          p.nama.toLowerCase().contains(_searchQuery) ||
          p.kode.toLowerCase().contains(_searchQuery) ||
          p.indikasi.toLowerCase().contains(_searchQuery);

      bool matchesGejala = true;
      if (_selectedGejala.isNotEmpty) {
        final pIndikasiList = p.listIndikasi.map((e) => e.toLowerCase()).toList();
        final rawIndikasi = p.indikasi.toLowerCase();
        matchesGejala = _selectedGejala.any((g) {
          final gLower = g.toLowerCase();
          return pIndikasiList.contains(gLower) || rawIndikasi.contains(gLower);
        });
      }

      return matchesCat && matchesQuery && matchesGejala;
    }).toList();

    // Jika filter keluhan/gejala aktif, urutkan obat dengan kecocokan terbanyak di posisi paling atas
    if (_selectedGejala.isNotEmpty) {
      _filteredProducts.sort((a, b) {
        final aLower = a.indikasi.toLowerCase();
        final bLower = b.indikasi.toLowerCase();
        final aScore = _selectedGejala.where((g) => aLower.contains(g.toLowerCase())).length;
        final bScore = _selectedGejala.where((g) => bLower.contains(g.toLowerCase())).length;
        if (bScore != aScore) {
          return bScore.compareTo(aScore);
        }
        return a.nama.compareTo(b.nama);
      });
    }
  }

  Future<bool> saveProduct(ProdukModel product) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final existing = await db.query('produk', where: 'id = ?', whereArgs: [product.id]);

      final dataMap = product.toMap();
      if (existing.isNotEmpty) {
        await db.update(
          'produk',
          dataMap,
          where: 'id = ?',
          whereArgs: [product.id],
        );
      } else {
        await db.insert('produk', dataMap);
      }

      await loadProducts();

      // Trigger auto-sync ke cloud database
      SyncService.instance.pushSingleProduct(product);

      return true;
    } catch (e) {
      debugPrint('Error saveProduct: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('produk', where: 'id = ?', whereArgs: [id]);
      await loadProducts();

      // Trigger delete di cloud database
      SyncService.instance.deleteCloudProduct(id);

      return true;
    } catch (e) {
      debugPrint('Error deleteProduct: $e');
      return false;
    }
  }

  Future<void> reduceStock(String productId, int qty) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      'UPDATE produk SET stok = MAX(0, stok - ?) WHERE id = ?',
      [qty, productId],
    );
    await loadProducts();
  }
}

