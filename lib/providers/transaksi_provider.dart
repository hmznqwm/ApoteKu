import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database/database_helper.dart';
import '../models/transaksi_model.dart';
import '../services/sync_service.dart';

class TransaksiProvider extends ChangeNotifier {
  List<TransaksiModel> _transactions = [];
  bool _isLoading = false;

  double _todayRevenue = 0.0;
  int _todayCount = 0;
  double _monthRevenue = 0.0;
  StreamSubscription? _syncSub;

  List<TransaksiModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  double get todayRevenue => _todayRevenue;
  int get todayCount => _todayCount;
  double get monthRevenue => _monthRevenue;

  TransaksiProvider() {
    loadTransactions();
    _syncSub = SyncService.instance.onSyncComplete.listen((_) {
      loadTransactions();
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('transaksi', orderBy: 'created_at DESC');

      List<TransaksiModel> list = [];
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

      double todaySum = 0.0;
      int todayC = 0;
      double monthSum = 0.0;

      for (var m in res) {
        final trxId = m['id']?.toString() ?? '';
        final invoice = m['invoice']?.toString() ?? '';
        final detailRows = await db.rawQuery('''
          SELECT d.*, p.harga_beli 
          FROM transaksi_detail d
          LEFT JOIN produk p ON p.id = d.produk_id
          WHERE d.transaksi_id = ? OR d.invoice = ?
        ''', [trxId, invoice]);
        final details = detailRows.map((d) => TransaksiDetailModel.fromMap(d)).toList();
        final trx = TransaksiModel.fromMap(m, details: details);
        list.add(trx);

        String tgl = trx.tanggal;
        if (tgl.contains('T')) tgl = tgl.split('T').first;
        if (tgl.contains(' ')) tgl = tgl.split(' ').first;

        if (tgl == today) {
          todaySum += trx.omsetBersih;
          todayC += 1;
        }
        if (tgl.startsWith(currentMonth)) {
          monthSum += trx.omsetBersih;
        }
      }

      _transactions = list;
      _todayRevenue = todaySum;
      _todayCount = todayC;
      _monthRevenue = monthSum;
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Map<String, double> getSalesData(DateTime start, DateTime end) {
    Map<String, double> sales = {};
    final diff = end.difference(start).inDays;

    for (int i = 0; i <= diff; i++) {
      final date = start.add(Duration(days: i));
      final dateKey = DateFormat('dd/MM').format(date);
      final dateDb = DateFormat('yyyy-MM-dd').format(date);

      double sum = 0.0;
      for (var t in _transactions) {
        String tgl = t.tanggal;
        if (tgl.contains('T')) tgl = tgl.split('T').first;
        if (tgl.contains(' ')) tgl = tgl.split(' ').first;
        if (tgl == dateDb) {
          sum += t.omsetBersih;
        }
      }
      sales[dateKey] = sum;
    }
    return sales;
  }

  Map<String, double> getGrossSalesData(DateTime start, DateTime end) {
    Map<String, double> sales = {};
    final diff = end.difference(start).inDays;

    for (int i = 0; i <= diff; i++) {
      final date = start.add(Duration(days: i));
      final dateKey = DateFormat('dd/MM').format(date);
      final dateDb = DateFormat('yyyy-MM-dd').format(date);

      double sum = 0.0;
      for (var t in _transactions) {
        String tgl = t.tanggal;
        if (tgl.contains('T')) tgl = tgl.split('T').first;
        if (tgl.contains(' ')) tgl = tgl.split(' ').first;
        if (tgl == dateDb) {
          sum += t.total;
        }
      }
      sales[dateKey] = sum;
    }
    return sales;
  }

  /// Memproses refund: ubah status transaksi → REFUND, kembalikan stok produk
  Future<bool> refundTransaction(String transaksiId) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Cek apakah transaksi sudah di-refund sebelumnya
      final existing = await db.query(
        'transaksi',
        where: 'id = ?',
        whereArgs: [transaksiId],
        columns: ['status'],
      );
      if (existing.isEmpty) return false;
      if ((existing.first['status'] as String?) == 'REFUND') return false;

      // Ambil detail transaksi
      final details = await db.query(
        'transaksi_detail',
        where: 'transaksi_id = ?',
        whereArgs: [transaksiId],
      );

      // Kembalikan stok untuk setiap item
      for (final d in details) {
        final produkId = d['produk_id']?.toString() ?? '';
        final qty = (d['qty'] as num?)?.toInt() ?? 0;
        if (produkId.isNotEmpty && qty > 0) {
          await db.rawUpdate(
            'UPDATE produk SET stok = stok + ? WHERE id = ?',
            [qty, produkId],
          );
        }
      }

      // Ubah status transaksi menjadi REFUND
      await db.update(
        'transaksi',
        {'status': 'REFUND'},
        where: 'id = ?',
        whereArgs: [transaksiId],
      );

      await loadTransactions();
      return true;
    } catch (_) {
      return false;
    }
  }
}
