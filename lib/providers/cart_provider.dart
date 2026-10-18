import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database/database_helper.dart';
import '../models/cart_item_model.dart';
import '../models/produk_model.dart';
import '../models/transaksi_model.dart';
import '../services/sync_service.dart';
import 'produk_provider.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItemModel> _items = {};
  double _diskon = 0.0;
  String _metode = 'CASH';

  Map<String, CartItemModel> get items => _items;
  List<CartItemModel> get itemList => _items.values.toList();
  double get diskon => _diskon;
  String get metode => _metode;

  int get totalQuantity {
    int total = 0;
    _items.forEach((_, item) => total += item.qty);
    return total;
  }

  double get subtotal {
    double sum = 0.0;
    _items.forEach((_, item) => sum += item.subtotal);
    return sum;
  }

  double get grandTotal {
    final total = subtotal - _diskon;
    return total > 0 ? total : 0.0;
  }

  bool addItem(ProdukModel produk, {bool isEceran = false, int qty = 1}) {
    if (produk.stok <= 0) return false;

    final key = "${produk.id}_${isEceran ? 'eceran' : 'utama'}";

    if (_items.containsKey(key)) {
      final current = _items[key]!;
      current.qty += qty;
      notifyListeners();
      return true;
    } else {
      _items[key] = CartItemModel(
        produk: produk,
        qty: qty,
        isEceran: isEceran,
      );
      notifyListeners();
      return true;
    }
  }

  void updateQty(String itemKey, int newQty) {
    if (!_items.containsKey(itemKey)) return;

    if (newQty <= 0) {
      _items.remove(itemKey);
    } else {
      _items[itemKey]!.qty = newQty;
    }
    notifyListeners();
  }

  void toggleItemUnit(String itemKey, bool eceran) {
    if (!_items.containsKey(itemKey)) return;
    final item = _items[itemKey]!;

    final newKey = "${item.produk.id}_${eceran ? 'eceran' : 'utama'}";
    if (newKey != itemKey && _items.containsKey(newKey)) {
      _items[newKey]!.qty += item.qty;
      _items.remove(itemKey);
    } else {
      _items.remove(itemKey);
      item.toggleUnit(eceran);
      _items[newKey] = item;
    }
    notifyListeners();
  }

  void removeItem(String itemKey) {
    _items.remove(itemKey);
    notifyListeners();
  }

  void setDiskon(double amount) {
    _diskon = amount;
    notifyListeners();
  }

  void setMetode(String m) {
    _metode = m;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _diskon = 0.0;
    _metode = 'CASH';
    notifyListeners();
  }

  Future<TransaksiModel?> checkout({
    required double bayar,
    required String kasirEmail,
    required String kasirName,
    required ProdukProvider produkProvider,
  }) async {
    if (_items.isEmpty) return null;
    if (bayar < grandTotal && _metode == 'CASH') return null;

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('yyyyMMdd-HHmmss').format(now);
    final invoice = 'INV-$timeStr';
    final trxId = 'TRX-${DateTime.now().millisecondsSinceEpoch}';

    final double kembalian = bayar >= grandTotal ? (bayar - grandTotal) : 0.0;

    final List<TransaksiDetailModel> details = [];

    // Begin Transaction
    await db.transaction((txn) async {
      // 1. Insert Transaksi
      await txn.insert('transaksi', {
        'id': trxId,
        'invoice': invoice,
        'tanggal': dateStr,
        'kasir_email': kasirEmail,
        'kasir_name': kasirName,
        'subtotal': subtotal,
        'diskon': _diskon,
        'total': grandTotal,
        'bayar': bayar,
        'kembalian': kembalian,
        'metode': _metode,
        'status': 'SELESAI',
        'is_synced': 0,
        'created_at': now.toIso8601String(),
      });

      // 2. Insert Transaksi Detail & update stock
      for (var item in itemList) {
        final detailId = 'TRD-${DateTime.now().millisecondsSinceEpoch}-${item.produk.id}';
        final displayName = item.isEceran
            ? '${item.produk.nama} (${item.selectedSatuan})'
            : item.produk.nama;

        final detail = TransaksiDetailModel(
          id: detailId,
          transaksiId: trxId,
          invoice: invoice,
          produkId: item.produk.id,
          kode: item.produk.kode,
          nama: displayName,
          qty: item.qty,
          harga: item.customPrice,
          subtotal: item.subtotal,
        );

        details.add(detail);

        await txn.insert('transaksi_detail', detail.toMap());

        // Pengurangan stok obat lokal
        // Jika eceran: dikurangi porsi stok sesuai isi_eceran
        final int deduction = item.isEceran
            ? (item.qty / item.produk.effectiveIsiEceran).ceil()
            : item.qty;

        await txn.rawUpdate(
          'UPDATE produk SET stok = MAX(0, stok - ?) WHERE id = ?',
          [deduction, item.produk.id],
        );
      }
    });

    // Refresh memory stock di ProdukProvider
    await produkProvider.loadProducts();

    final result = TransaksiModel(
      id: trxId,
      invoice: invoice,
      tanggal: dateStr,
      kasirEmail: kasirEmail,
      kasirName: kasirName,
      subtotal: subtotal,
      diskon: _diskon,
      total: grandTotal,
      bayar: bayar,
      kembalian: kembalian,
      metode: _metode,
      status: 'SELESAI',
      createdAt: now.toIso8601String(),
      details: details,
    );

    clearCart();

    // Trigger auto-sync ke cloud jika online
    SyncService.instance.syncAll(isBackground: true);

    return result;
  }
}
