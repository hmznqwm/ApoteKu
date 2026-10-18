import 'dart:async';
import 'package:flutter/material.dart';
import '../core/database/database_helper.dart';
import '../models/produk_model.dart';
import '../services/sync_service.dart';

class ProdukProvider extends ChangeNotifier {
  List<ProdukModel> _allProducts = [];
  List<ProdukModel> _filteredProducts = [];
  List<String> _categories = ['Semua'];
  String _selectedCategory = 'Semua';
  String _searchQuery = '';
  bool _isLoading = false;
  StreamSubscription? _syncSub;

  List<ProdukModel> get products => _filteredProducts;
  List<ProdukModel> get allProducts => _allProducts;
  List<String> get categories => _categories;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

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

  void setCategory(String cat) {
    _selectedCategory = cat;
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
          p.kode.toLowerCase().contains(_searchQuery);
      return matchesCat && matchesQuery;
    }).toList();
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

