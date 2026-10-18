import 'dart:async';
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/database_helper.dart';
import '../models/produk_model.dart';
import '../models/supplier_model.dart';

enum SyncState {
  online,
  syncing,
  hasPending,
  offline,
}

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  static const String _defaultUrl = 'https://apotektiafarma.rf.gd/api.php';
  static const String _prefKeyUrl = 'sync_server_url';

  String _serverUrl = _defaultUrl;
  String _savedCookie = '';
  String? _sessionToken;
  DateTime? _lastSyncTime;
  int _unsyncedCount = 0;
  SyncState _state = SyncState.offline;
  String _statusMessage = 'Memeriksa koneksi server...';

  Timer? _autoSyncTimer;
  final http.Client _client = http.Client();
  final StreamController<void> _onSyncCompleteController = StreamController<void>.broadcast();

  String get serverUrl => _serverUrl;
  String get savedCookie => _savedCookie;
  String? get sessionToken => _sessionToken;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get unsyncedCount => _unsyncedCount;
  SyncState get state => _state;
  String get statusMessage => _statusMessage;
  Stream<void> get onSyncComplete => _onSyncCompleteController.stream;

  String solveChallenge(String body) => _solveChallenge(body);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverUrl = prefs.getString(_prefKeyUrl) ?? _defaultUrl;
    } catch (_) {}

    await refreshUnsyncedCount();

    // Jalankan auto-sync awal
    syncAll(isBackground: true);

    // Pasang timer periodik setiap 30 detik untuk auto-sync
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncAll(isBackground: true);
    });
  }

  Future<void> setServerUrl(String newUrl) async {
    _serverUrl = newUrl.trim();
    _savedCookie = '';
    _sessionToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyUrl, _serverUrl);
    } catch (_) {}
    notifyListeners();
    await syncAll();
  }

  Future<int> refreshUnsyncedCount() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.rawQuery('SELECT COUNT(*) as count FROM transaksi WHERE is_synced = 0');
      _unsyncedCount = (res.first['count'] as int?) ?? 0;
      if (_state != SyncState.syncing && _state != SyncState.offline) {
        _state = _unsyncedCount > 0 ? SyncState.hasPending : SyncState.online;
      }
      notifyListeners();
      return _unsyncedCount;
    } catch (_) {
      return 0;
    }
  }

  // ==========================================
  // HTTP & InfinityFree AES Challenge Handler
  // ==========================================

  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _solveChallenge(String body) {
    final matchA = RegExp(r'a=toNumbers\("([a-f0-9]+)"\)').firstMatch(body);
    final matchB = RegExp(r'b=toNumbers\("([a-f0-9]+)"\)').firstMatch(body);
    final matchC = RegExp(r'c=toNumbers\("([a-f0-9]+)"\)').firstMatch(body);
    if (matchA == null || matchB == null || matchC == null) return '';

    try {
      final keyBytes = _hexToBytes(matchA.group(1)!);
      final ivBytes = _hexToBytes(matchB.group(1)!);
      final cipherBytes = _hexToBytes(matchC.group(1)!);

      final key = enc.Key(keyBytes);
      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: null));
      final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
      return _bytesToHex(decrypted);
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, dynamic>> callApi(String action, [Map<String, dynamic>? payload]) => _callApi(action, payload);

  Future<Map<String, dynamic>> _callApi(String action, [Map<String, dynamic>? payload]) async {
    final uri = Uri.parse(_serverUrl);
    final bodyData = {
      'action': action,
      'payload': {
        if (_sessionToken != null) 'token': _sessionToken,
        ...?payload,
      }
    };

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ApoteKu-POS/1.0',
      if (_savedCookie.isNotEmpty) 'Cookie': _savedCookie,
    };

    http.Response resp;
    try {
      resp = await _client.post(uri, headers: headers, body: jsonEncode(bodyData)).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('Gagal menghubungi server web: $e');
    }

    // Jika response berupa HTML challenge dari InfinityFree
    if (resp.body.contains('toNumbers') && resp.body.contains('slowAES')) {
      final cookieVal = _solveChallenge(resp.body);
      if (cookieVal.isNotEmpty) {
        _savedCookie = '__test=$cookieVal';
        headers['Cookie'] = _savedCookie;
        try {
          final getUri = uri.replace(queryParameters: {'i': '1'});
          await _client.get(getUri, headers: headers).timeout(const Duration(seconds: 10));
        } catch (_) {}
        resp = await _client.post(uri, headers: headers, body: jsonEncode(bodyData)).timeout(const Duration(seconds: 15));
      }
    }

    try {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Format response tidak valid dari server (${resp.statusCode})');
    }
  }

  // ==========================================
  // AUTHENTICATION DENGAN AKUN DEFAULT ADMIN
  // ==========================================

  Future<bool> loginCloud() async {
    try {
      final res = await _callApi('auth.login', {
        'email': 'admin@pos.local',
        'password': 'ApotekTia2026!',
      });

      if (res['ok'] == true && res['data'] != null && res['data']['token'] != null) {
        _sessionToken = res['data']['token'];
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ==========================================
  // SYNC OPERATIONS (Push Transaksi, Pull/Push Produk & Supplier)
  // ==========================================

  Future<bool> pingServer() async {
    try {
      final res = await _callApi('sync.ping');
      return res['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncAll({bool isBackground = false}) async {
    if (_state == SyncState.syncing) return;

    _state = SyncState.syncing;
    _statusMessage = 'Menghubungkan ke server web...';
    notifyListeners();

    try {
      // 1. Cek Login / Token
      if (_sessionToken == null) {
        final loggedIn = await loginCloud();
        if (!loggedIn) {
          _state = SyncState.offline;
          _statusMessage = 'Server offline / tidak terjangkau';
          await refreshUnsyncedCount();
          return;
        }
      }

      // 2. Push Transaksi yang belum terkirim
      _statusMessage = 'Mengunggah transaksi lokal ke cloud...';
      notifyListeners();
      await _pushUnsyncedTransactions();

      // 3. Pull Riwayat Transaksi dari Cloud
      _statusMessage = 'Memperbarui riwayat transaksi dari cloud...';
      notifyListeners();
      await _pullCloudTransactions();

      // 4. Pull Master Produk Terbaru dari Cloud
      _statusMessage = 'Memperbarui katalog produk dari cloud...';
      notifyListeners();
      await _pullCloudProducts();

      // 5. Sync Data Supplier (Pull & Push)
      _statusMessage = 'Menyelaraskan data supplier...';
      notifyListeners();
      await _syncSuppliers();

      _lastSyncTime = DateTime.now();
      await refreshUnsyncedCount();

      _state = _unsyncedCount > 0 ? SyncState.hasPending : SyncState.online;
      _statusMessage = 'Tersinkronisasi dengan Server Web';
      _onSyncCompleteController.add(null);
      notifyListeners();
    } catch (e) {
      _sessionToken = null; // Reset token on error
      _state = SyncState.offline;
      _statusMessage = 'Gagal sinkron: ${e.toString().replaceAll('Exception: ', '')}';
      await refreshUnsyncedCount();
    }
  }

  Future<void> _pushUnsyncedTransactions() async {
    final db = await DatabaseHelper.instance.database;
    final unsyncedRows = await db.query(
      'transaksi',
      where: 'is_synced = 0',
      orderBy: 'created_at ASC',
      limit: 50,
    );

    if (unsyncedRows.isEmpty) return;

    List<Map<String, dynamic>> payloadTransactions = [];

    for (var row in unsyncedRows) {
      final trxId = row['id'].toString();
      final detailRows = await db.query(
        'transaksi_detail',
        where: 'transaksi_id = ?',
        whereArgs: [trxId],
      );

      payloadTransactions.add({
        'id': row['id'],
        'invoice': row['invoice'],
        'tanggal': row['tanggal'],
        'kasir_email': row['kasir_email'],
        'kasir_name': row['kasir_name'],
        'subtotal': row['subtotal'],
        'diskon': row['diskon'],
        'total': row['total'],
        'bayar': row['bayar'],
        'kembalian': row['kembalian'],
        'metode': row['metode'],
        'status': row['status'],
        'created_at': row['created_at'],
        'items': detailRows.map((d) => {
          'id': d['id'],
          'produk_id': d['produk_id'],
          'kode': d['kode'],
          'nama': d['nama'],
          'qty': d['qty'],
          'harga': d['harga'],
          'subtotal': d['subtotal'],
          'created_at': d['created_at'],
        }).toList(),
      });
    }

    final res = await _callApi('sync.pushTransactions', {
      'transactions': payloadTransactions,
    });

    if (res['ok'] == true && res['data'] != null) {
      final List<dynamic> syncedInvoices = res['data']['synced_invoices'] ?? [];
      for (var inv in syncedInvoices) {
        await db.update(
          'transaksi',
          {'is_synced': 1},
          where: 'invoice = ?',
          whereArgs: [inv.toString()],
        );
      }
    }
  }

  Future<void> _pullCloudTransactions() async {
    try {
      final res = await _callApi('sync.pullTransactions');
      if (res['ok'] == true && res['data'] != null) {
        final List<dynamic> transactions = res['data']['transactions'] ?? [];
        if (transactions.isEmpty) return;

        final db = await DatabaseHelper.instance.database;

        await db.transaction((txn) async {
          for (var tx in transactions) {
            final id = tx['id']?.toString() ?? '';
            final invoice = tx['invoice']?.toString() ?? '';
            if (id.isEmpty || invoice.isEmpty) continue;

            String rawTanggal = tx['tanggal']?.toString() ?? '';
            if (rawTanggal.contains('T')) {
              rawTanggal = rawTanggal.split('T').first;
            } else if (rawTanggal.contains(' ')) {
              rawTanggal = rawTanggal.split(' ').first;
            }
            if (rawTanggal.isEmpty) {
              rawTanggal = DateTime.now().toIso8601String().substring(0, 10);
            }

            final exist = await txn.query(
              'transaksi',
              where: 'id = ? OR invoice = ?',
              whereArgs: [id, invoice],
              limit: 1,
            );

            if (exist.isEmpty) {
              await txn.insert('transaksi', {
                'id': id,
                'invoice': invoice,
                'tanggal': rawTanggal,
                'kasir_email': tx['kasir_email']?.toString() ?? 'admin@pos.local',
                'kasir_name': tx['kasir_name']?.toString() ?? 'Kasir Cloud',
                'subtotal': (tx['subtotal'] as num?)?.toDouble() ?? 0.0,
                'diskon': (tx['diskon'] as num?)?.toDouble() ?? 0.0,
                'total': (tx['total'] as num?)?.toDouble() ?? 0.0,
                'bayar': (tx['bayar'] as num?)?.toDouble() ?? 0.0,
                'kembalian': (tx['kembalian'] as num?)?.toDouble() ?? 0.0,
                'metode': tx['metode']?.toString() ?? 'CASH',
                'status': tx['status']?.toString() ?? 'SELESAI',
                'created_at': tx['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                'is_synced': 1,
              });

              final items = tx['items'] is List ? tx['items'] as List<dynamic> : [];
              for (int i = 0; i < items.length; i++) {
                final it = items[i];
                final detId = (it['id'] != null && it['id'].toString().isNotEmpty)
                    ? it['id'].toString()
                    : '${id}_det_$i';
                await txn.insert('transaksi_detail', {
                  'id': detId,
                  'transaksi_id': id,
                  'invoice': invoice,
                  'produk_id': it['produk_id']?.toString() ?? '',
                  'kode': it['kode']?.toString() ?? '',
                  'nama': it['nama']?.toString() ?? '',
                  'qty': (it['qty'] as num?)?.toInt() ?? 1,
                  'harga': (it['harga'] as num?)?.toDouble() ?? 0.0,
                  'subtotal': (it['subtotal'] as num?)?.toDouble() ?? 0.0,
                  'created_at': it['created_at']?.toString() ?? tx['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                });
              }
            } else {
              // Pastikan status sinkronisasi lokal ter-update
              await txn.update(
                'transaksi',
                {'is_synced': 1},
                where: 'id = ? OR invoice = ?',
                whereArgs: [id, invoice],
              );
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pullCloudProducts() async {
    final res = await _callApi('sync.pullProducts');
    if (res['ok'] == true && res['data'] != null) {
      final List<dynamic> products = res['data']['products'] ?? [];
      if (products.isEmpty) return;

      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();

      await db.transaction((txn) async {
        for (var p in products) {
          final id = p['id']?.toString() ?? '';
          final kode = p['kode']?.toString() ?? '';
          if (id.isEmpty || kode.isEmpty) continue;

          final exist = await txn.query(
            'produk',
            where: 'id = ? OR kode = ?',
            whereArgs: [id, kode],
            limit: 1,
          );

          final map = {
            'id': id,
            'kode': kode,
            'nama': p['nama']?.toString() ?? '',
            'kategori': p['kategori']?.toString() ?? '',
            'harga_beli': (p['harga_beli'] as num?)?.toDouble() ?? 0.0,
            'harga_jual': (p['harga_jual'] as num?)?.toDouble() ?? 0.0,
            'stok': (p['stok'] as num?)?.toInt() ?? 0,
            'satuan': p['satuan']?.toString() ?? 'PCS',
            'status': p['status']?.toString() ?? 'AKTIF',
            'created_at': p['created_at']?.toString() ?? now,
          };

          if (exist.isNotEmpty) {
            await txn.update(
              'produk',
              map,
              where: 'id = ?',
              whereArgs: [exist.first['id']],
            );
          } else {
            await txn.insert('produk', map);
          }
        }
      });
    }
  }

  Future<void> pushSingleProduct(ProdukModel prod) async {
    try {
      if (_sessionToken == null) {
        await loginCloud();
      }
      if (_sessionToken != null) {
        await _callApi('sync.pushProducts', {
          'products': [
            {
              'id': prod.id,
              'kode': prod.kode,
              'nama': prod.nama,
              'kategori': prod.kategori,
              'harga_beli': prod.hargaBeli,
              'harga_jual': prod.hargaJual,
              'stok': prod.stok,
              'satuan': prod.satuan,
              'status': prod.status,
            }
          ]
        });
      }
    } catch (_) {}
  }

  Future<void> deleteCloudProduct(String id) async {
    try {
      if (_sessionToken == null) {
        await loginCloud();
      }
      if (_sessionToken != null) {
        await _callApi('produk.delete', {'id': id});
      }
    } catch (_) {}
  }

  Future<void> _syncSuppliers() async {
    final db = await DatabaseHelper.instance.database;

    // 1. Pull data supplier dari cloud
    try {
      final res = await _callApi('sync.pullSuppliers');
      if (res['ok'] == true && res['data'] != null) {
        final List<dynamic> suppliers = res['data']['suppliers'] ?? [];
        final now = DateTime.now().toIso8601String();

        await db.transaction((txn) async {
          for (var s in suppliers) {
            final id = s['id']?.toString() ?? '';
            final nama = s['nama']?.toString() ?? '';
            if (id.isEmpty || nama.isEmpty) continue;

            final exist = await txn.query(
              'supplier',
              where: 'id = ?',
              whereArgs: [id],
              limit: 1,
            );

            final map = {
              'id': id,
              'nama': nama,
              'kontak': s['kontak']?.toString() ?? '',
              'telepon': s['telepon']?.toString() ?? '',
              'alamat': s['alamat']?.toString() ?? '',
              'status': s['status']?.toString() ?? 'AKTIF',
              'created_at': s['created_at']?.toString() ?? now,
            };

            if (exist.isNotEmpty) {
              await txn.update(
                'supplier',
                map,
                where: 'id = ?',
                whereArgs: [id],
              );
            } else {
              await txn.insert('supplier', map);
            }
          }
        });
      }
    } catch (_) {}

    // 2. Push data supplier lokal ke cloud agar web selalu sinkron
    try {
      final localSuppliers = await db.query('supplier');
      if (localSuppliers.isNotEmpty) {
        await _callApi('sync.pushSuppliers', {
          'suppliers': localSuppliers.map((s) => {
            'id': s['id'],
            'nama': s['nama'],
            'kontak': s['kontak'],
            'telepon': s['telepon'],
            'alamat': s['alamat'],
            'status': s['status'],
          }).toList(),
        });
      }
    } catch (_) {}
  }

  Future<void> pushSingleSupplier(SupplierModel sup) async {
    try {
      if (_sessionToken == null) {
        await loginCloud();
      }
      if (_sessionToken != null) {
        await _callApi('sync.pushSuppliers', {
          'suppliers': [
            {
              'id': sup.id,
              'nama': sup.nama,
              'kontak': sup.kontak,
              'telepon': sup.telepon,
              'alamat': sup.alamat,
              'status': sup.status,
            }
          ]
        });
      }
    } catch (_) {}
  }

  Future<void> deleteCloudSupplier(String id) async {
    try {
      if (_sessionToken == null) {
        await loginCloud();
      }
      if (_sessionToken != null) {
        await _callApi('supplier.delete', {'id': id});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _client.close();
    super.dispose();
  }
}
