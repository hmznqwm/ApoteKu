import 'dart:async';
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/database_helper.dart';
import '../models/produk_model.dart';
import '../models/supplier_model.dart';
import 'printer_service.dart';

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
      _sessionToken = prefs.getString(_prefKeyCloudToken);
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
    final trimmed = newUrl.trim();
    if (trimmed.isNotEmpty) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https')) || uri.host.isEmpty) {
        throw Exception('URL server tidak valid. Format harus diawali dengan http:// atau https://');
      }
    }
    _serverUrl = trimmed.isEmpty ? _defaultUrl : trimmed;
    _savedCookie = '';
    _sessionToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyUrl, _serverUrl);
      await prefs.remove(_prefKeyCloudToken);
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
      debugPrint('[_callApi Initial] $action -> status: ${resp.statusCode}, body: ${resp.body.length > 100 ? resp.body.substring(0, 100) : resp.body}');
    } catch (e) {
      debugPrint('[_callApi Initial Error] $e');
      throw Exception('Gagal menghubungi server web: $e');
    }

    // Jika response berupa HTML challenge dari InfinityFree
    if (resp.body.contains('toNumbers') && resp.body.contains('slowAES')) {
      final cookieVal = _solveChallenge(resp.body);
      debugPrint('[_callApi Challenge] Solved cookieVal: $cookieVal');
      if (cookieVal.isNotEmpty) {
        _savedCookie = '__test=$cookieVal';
        headers['Cookie'] = _savedCookie;
        try {
          final getUri = uri.replace(queryParameters: {'i': '1'});
          final getR = await _client.get(getUri, headers: headers).timeout(const Duration(seconds: 10));
          debugPrint('[_callApi GET ?i=1] status: ${getR.statusCode}');
        } catch (e) {
          debugPrint('[_callApi GET ?i=1 Error] $e');
        }
        resp = await _client.post(uri, headers: headers, body: jsonEncode(bodyData)).timeout(const Duration(seconds: 15));
        debugPrint('[_callApi Retry] $action -> status: ${resp.statusCode}, body: ${resp.body.length > 150 ? resp.body.substring(0, 150) : resp.body}');
      }
    }

    try {
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      debugPrint('[_callApi Decoded] $action -> ok: ${decoded['ok']}');
      if (decoded['ok'] == false) {
        final msg = decoded['message']?.toString() ?? '';
        if (msg.contains('Token') || msg.contains('Sesi')) {
          _sessionToken = null;
        }
      }
      return decoded;
    } catch (e) {
      debugPrint('[_callApi JSON Error] $e, Raw: ${resp.body}');
      throw Exception('Format response tidak valid dari server (${resp.statusCode})');
    }
  }

  // ==========================================
  // AUTHENTICATION DENGAN AKUN CLOUD
  // ==========================================

  static const String _prefKeyCloudEmail = 'sync_cloud_email';
  static const String _prefKeyCloudPass = 'sync_cloud_password';
  static const String _prefKeyCloudToken = 'sync_cloud_token';

  Future<void> setCloudCredentials(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyCloudEmail, email.trim());
      await prefs.setString(_prefKeyCloudPass, password.trim());
      _sessionToken = null;
    } catch (_) {}
  }

  Future<Map<String, dynamic>> loginWithCloudCredentials(String usernameOrEmail, String password) async {
    try {
      final res = await _callApi('auth.login', {
        'email': usernameOrEmail.trim(),
        'password': password.trim(),
      });

      if (res['ok'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        if (data['token'] != null) {
          _sessionToken = data['token']?.toString();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKeyCloudToken, _sessionToken!);
          await prefs.setString(_prefKeyCloudEmail, usernameOrEmail.trim());
          await prefs.setString(_prefKeyCloudPass, password.trim());
        }
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'isNetworkError': false,
          'message': res['message']?.toString() ?? 'Username/email atau kata sandi tidak cocok.',
        };
      }
    } catch (e) {
      debugPrint('Cloud login attempt error: $e');
      return {
        'success': false,
        'isNetworkError': true,
        'message': e.toString(),
      };
    }
  }

  Future<bool> loginCloud() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var email = prefs.getString(_prefKeyCloudEmail);
      var pass = prefs.getString(_prefKeyCloudPass);

      if (email == null || pass == null || email.isEmpty || pass.isEmpty) {
        email = 'admin';
        pass = 'admin123';
      }

      final res = await _callApi('auth.login', {
        'email': email,
        'password': pass,
      });

      if (res['ok'] == true && res['data'] != null && res['data']['token'] != null) {
        _sessionToken = res['data']['token']?.toString();
        await prefs.setString(_prefKeyCloudToken, _sessionToken!);
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

      // 6. Sync Pengguna / Manajemen User (Pull & Push)
      _statusMessage = 'Menyelaraskan data pengguna...';
      notifyListeners();
      await _syncUsers();

      // 7. Sync Audit Trail & Monitoring Aktivitas (Pull & Push)
      _statusMessage = 'Menyelaraskan log monitoring...';
      notifyListeners();
      await _syncActivityLogs();

      // 8. Sync Gejala / Keluhan Obat (Pull & Push)
      _statusMessage = 'Menyelaraskan data gejala obat...';
      notifyListeners();
      await _syncGejala();

      // 9. Sync Pengadaan / Faktur Pembelian (Pull & Push)
      _statusMessage = 'Menyelaraskan data pengadaan...';
      notifyListeners();
      await _syncPembelian();

      // 10. Sync Pengaturan Profil & Identitas Apotek (Pull)
      _statusMessage = 'Menyelaraskan profil apotek...';
      notifyListeners();
      await _pullCloudSettings();

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
              // Jika transaksi sudah ada secara lokal, cek apakah ada perubahan status (misal: REFUND dari cloud)
              final localStatus = exist.first['status']?.toString() ?? 'SELESAI';
              final cloudStatus = tx['status']?.toString() ?? 'SELESAI';

              if (cloudStatus == 'HAPUS') {
                await txn.delete('transaksi_detail', where: 'transaksi_id = ? OR invoice = ?', whereArgs: [id, invoice]);
                await txn.delete('transaksi', where: 'id = ? OR invoice = ?', whereArgs: [id, invoice]);
                continue;
              }

              if (cloudStatus != localStatus) {
                await txn.update(
                  'transaksi',
                  {'status': cloudStatus, 'is_synced': 1},
                  where: 'id = ? OR invoice = ?',
                  whereArgs: [id, invoice],
                );

                // Jika cloud mengubah status menjadi REFUND dan lokal belum REFUND, kembalikan stok obat lokal
                if (cloudStatus == 'REFUND' && localStatus != 'REFUND') {
                  final details = await txn.query(
                    'transaksi_detail',
                    where: 'transaksi_id = ? OR invoice = ?',
                    whereArgs: [id, invoice],
                  );
                  for (final d in details) {
                    final prodId = d['produk_id']?.toString() ?? '';
                    final qty = (d['qty'] as num?)?.toInt() ?? 0;
                    if (prodId.isNotEmpty && qty > 0) {
                      await txn.rawUpdate(
                        'UPDATE produk SET stok = stok + ? WHERE id = ?',
                        [qty, prodId],
                      );
                    }
                  }
                }
              } else {
                await txn.update(
                  'transaksi',
                  {'is_synced': 1},
                  where: 'id = ? OR invoice = ?',
                  whereArgs: [id, invoice],
                );
              }
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

          final cloudIndikasi = p['indikasi']?.toString();
          final map = <String, dynamic>{
            'id': id,
            'kode': kode,
            'nama': p['nama']?.toString() ?? '',
            'kategori': p['kategori']?.toString() ?? '',
            'harga_beli': (p['harga_beli'] as num?)?.toDouble() ?? 0.0,
            'harga_jual': (p['harga_jual'] as num?)?.toDouble() ?? 0.0,
            'stok': (p['stok'] as num?)?.toInt() ?? 0,
            'satuan': p['satuan']?.toString() ?? 'PCS',
            'satuan_eceran': p['satuan_eceran']?.toString() ?? p['satuanEceran']?.toString() ?? '',
            'isi_eceran': (p['isi_eceran'] as num?)?.toInt() ?? (p['isiEceran'] as num?)?.toInt() ?? 1,
            'harga_eceran': (p['harga_eceran'] as num?)?.toDouble() ?? (p['hargaEceran'] as num?)?.toDouble() ?? 0.0,
            'tgl_kadaluwarsa': p['tgl_kadaluwarsa']?.toString() ?? p['tgl_expired']?.toString(),
            'status': p['status']?.toString() ?? 'AKTIF',
            'created_at': p['created_at']?.toString() ?? now,
          };

          if (cloudIndikasi != null && cloudIndikasi.isNotEmpty) {
            map['indikasi'] = cloudIndikasi;
          } else if (exist.isNotEmpty && exist.first['indikasi'] != null) {
            map['indikasi'] = exist.first['indikasi'];
          }

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
              'indikasi': prod.indikasi,
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

  Future<void> _syncUsers() async {
    final db = await DatabaseHelper.instance.database;

    // 1. Tarik pengguna terbaru dari cloud (Pull)
    try {
      final res = await _callApi('sync.pullUsers');
      if (res['ok'] == true && res['data'] != null) {
        final List<dynamic> users = res['data']['users'] ?? [];
        for (var u in users) {
          final id = u['id']?.toString() ?? '';
          final email = u['email']?.toString() ?? '';
          if (id.isEmpty || email.isEmpty) continue;

          final exist = await db.query(
            'users',
            where: 'id = ? OR email = ?',
            whereArgs: [id, email],
            limit: 1,
          );
          final passHash = u['password_hash']?.toString() ?? '';

          if (exist.isEmpty) {
            await db.insert('users', {
              'id': id,
              'name': u['name']?.toString() ?? 'Staf',
              'email': email,
              'role': u['role']?.toString() ?? 'KASIR',
              'status': u['status']?.toString() ?? 'AKTIF',
              'password_hash': passHash.isNotEmpty
                  ? passHash
                  : 'f3c6fe4bbd0bf5348ebdfa71d5654db30e7aeb5bafced73074e835d5e693645b',
              'created_at': u['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            });
          } else {
            final updateData = <String, dynamic>{
              'name': u['name']?.toString() ?? exist.first['name'],
              'role': u['role']?.toString() ?? exist.first['role'],
              'status': u['status']?.toString() ?? exist.first['status'],
            };
            if (passHash.isNotEmpty) {
              updateData['password_hash'] = passHash;
            }
            await db.update('users', updateData, where: 'id = ?', whereArgs: [exist.first['id']]);
          }
        }
      }
    } catch (_) {}

    // 2. Unggah data pengguna lokal ke cloud (Push)
    try {
      final localUsers = await db.query('users');
      if (localUsers.isNotEmpty) {
        await _callApi('sync.pushUsers', {
          'users': localUsers.map((u) => {
            'id': u['id'],
            'email': u['email'],
            'name': u['name'],
            'role': u['role'],
            'status': u['status'],
            'password_hash': u['password_hash'],
          }).toList(),
        });
      }
    } catch (_) {}
  }

  Future<void> _syncActivityLogs() async {
    final db = await DatabaseHelper.instance.database;

    // 1. Unggah log aktivitas lokal ke cloud (Push)
    try {
      final localLogs = await db.query('activity_log', orderBy: 'created_at DESC', limit: 50);
      if (localLogs.isNotEmpty) {
        await _callApi('sync.pushActivityLogs', {
          'logs': localLogs.map((l) => {
            'id': l['id'],
            'user_name': l['user_name'],
            'user_role': l['user_role'],
            'action_type': l['action_type'],
            'title': l['title'],
            'details': l['details'],
            'created_at': l['created_at'],
          }).toList(),
        });
      }
    } catch (_) {}

    // 2. Tarik log aktivitas terbaru dari cloud (Pull)
    try {
      final res = await _callApi('sync.pullActivityLogs');
      if (res['ok'] == true && res['data'] != null) {
        final List<dynamic> logs = res['data']['logs'] ?? [];
        for (var l in logs) {
          final id = l['id']?.toString() ?? '';
          if (id.isEmpty) continue;

          final exist = await db.query('activity_log', where: 'id = ?', whereArgs: [id], limit: 1);
          if (exist.isEmpty) {
            final actionType = l['action_type']?.toString() ?? 'TAMBAH';
            final module = l['module']?.toString() ?? '';
            final itemName = l['item_name']?.toString() ?? '';
            final description = l['description']?.toString() ?? '';

            String title = itemName.isNotEmpty ? itemName : module;
            if (title.isEmpty) title = 'Aktivitas $actionType';

            await db.insert('activity_log', {
              'id': id,
              'user_name': l['user_name']?.toString() ?? 'Sistem',
              'user_role': l['user_role']?.toString() ?? 'KASIR',
              'action_type': actionType,
              'title': title,
              'details': description,
              'created_at': l['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            });
          }
        }

        // Pangkas otomatis log lokal agar tetap ringan (maksimal 100 log)
        await db.rawDelete('''
          DELETE FROM activity_log 
          WHERE id NOT IN (
            SELECT id FROM activity_log 
            ORDER BY created_at DESC 
            LIMIT 100
          )
        ''');
      }
    } catch (_) {}
  }

  Future<void> pushSingleUser(Map<String, dynamic> userMap, [String? rawPassword]) async {
    try {
      if (_sessionToken == null) await loginCloud();
      if (_sessionToken != null) {
        final payload = Map<String, dynamic>.from(userMap);
        if (rawPassword != null && rawPassword.isNotEmpty) {
          payload['password'] = rawPassword;
        }
        await _callApi('sync.pushUsers', {
          'users': [payload],
        });
      }
    } catch (_) {}
  }

  Future<void> deleteCloudUser(String userId) async {
    try {
      if (_sessionToken == null) await loginCloud();
      if (_sessionToken != null) {
        await _callApi('user.delete', {'id': userId});
      }
    } catch (_) {}
  }

  Future<void> pushSingleActivityLog(Map<String, dynamic> logMap) async {
    try {
      if (_sessionToken == null) await loginCloud();
      if (_sessionToken != null) {
        await _callApi('sync.pushActivityLogs', {
          'logs': [logMap],
        });
      }
    } catch (_) {}
  }

  Future<void> pushRefund(String transaksiId) async {
    try {
      if (_sessionToken == null) await loginCloud();
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('transaksi', where: 'id = ?', whereArgs: [transaksiId], limit: 1);
      if (res.isNotEmpty) {
        final invoice = res.first['invoice']?.toString() ?? transaksiId;
        // Panggil endpoint transaksi.refund di cloud
        if (_sessionToken != null) {
          await _callApi('transaksi.refund', {'id': invoice});
        }
        // Pastikan pushTransaksi juga mengunggah perubahan transaksi
        await _pushUnsyncedTransactions();
      }
    } catch (_) {}
  }

  Future<void> _syncGejala() async {
    final db = await DatabaseHelper.instance.database;

    // 1. Pull data gejala dari cloud
    try {
      final res = await _callApi('sync.pullGejala');
      if (res['ok'] == true && res['data'] != null) {
        final List<dynamic> gejalas = res['data'] is List ? res['data'] : (res['data']['gejala'] ?? []);
        final now = DateTime.now().toIso8601String();

        await db.transaction((txn) async {
          for (var g in gejalas) {
            final id = g['id']?.toString() ?? '';
            final nama = (g['nama'] ?? g['namaGejala'] ?? '')?.toString().trim() ?? '';
            if (nama.isEmpty) continue;

            final exist = await txn.query(
              'gejala',
              where: 'LOWER(nama) = ? OR id = ?',
              whereArgs: [nama.toLowerCase(), id],
              limit: 1,
            );

            if (exist.isEmpty) {
              await txn.insert('gejala', {
                'id': id.isNotEmpty ? id : 'GJ-${DateTime.now().millisecondsSinceEpoch}',
                'nama': nama,
                'created_at': now,
              });
            }
          }
        });
      }
    } catch (_) {}

    // 2. Push data gejala lokal ke cloud
    try {
      final localGejala = await db.query('gejala');
      if (localGejala.isNotEmpty) {
        await _callApi('sync.pushGejala', {
          'gejala': localGejala.map((g) => {
            'id': g['id'],
            'nama': g['nama'],
          }).toList(),
        });
      }
    } catch (_) {}
  }

  Future<void> pushGejala(String nama, String id) async {
    try {
      if (_sessionToken == null) await loginCloud();
      if (_sessionToken != null) {
        await _callApi('gejala.save', {
          'id': id,
          'nama': nama,
        });
      }
    } catch (_) {}
  }

  Future<void> _syncPembelian() async {
    final db = await DatabaseHelper.instance.database;

    // 1. Pull data pembelian dari cloud
    try {
      final res = await _callApi('sync.pullPembelian');
      if (res['ok'] == true && res['data'] != null) {
        final List<dynamic> items = res['data']['pembelian'] ?? [];
        await db.transaction((txn) async {
          for (var item in items) {
            final id = item['id']?.toString() ?? '';
            final noPo = item['no_po']?.toString() ?? item['no_faktur']?.toString() ?? '';
            if (id.isEmpty && noPo.isEmpty) continue;

            final exist = await txn.query(
              'pembelian',
              where: 'id = ? OR no_po = ?',
              whereArgs: [id, noPo],
              limit: 1,
            );

            final map = <String, dynamic>{
              'id': id.isNotEmpty ? id : noPo,
              'no_po': noPo,
              'supplier_id': item['supplier_id']?.toString() ?? '',
              'supplier_nama': item['supplier_nama']?.toString() ?? 'Supplier',
              'produk_id': item['produk_id']?.toString() ?? '',
              'qty': (item['qty'] as num?)?.toInt() ?? 0,
              'harga_beli': (item['harga_beli'] as num?)?.toDouble() ?? 0.0,
              'total': (item['total'] as num?)?.toDouble() ?? 0.0,
              'tanggal': item['tanggal']?.toString() ?? '',
              'petugas': item['petugas']?.toString() ?? '',
              'status': item['status']?.toString() ?? 'LUNAS',
              'created_at': item['created_at']?.toString() ?? DateTime.now().toIso8601String(),
              'is_synced': 1,
            };

            if (exist.isEmpty) {
              await txn.insert('pembelian', map);
            } else {
              await txn.update(
                'pembelian',
                map,
                where: 'id = ?',
                whereArgs: [exist.first['id']],
              );
            }
          }
        });
      }
    } catch (_) {}

    // 2. Push data pembelian lokal yang belum disinkronkan ke cloud
    try {
      final unsynced = await db.query(
        'pembelian',
        where: 'is_synced = 0',
      );
      if (unsynced.isNotEmpty) {
        final res = await _callApi('sync.pushPembelian', {
          'pembelian': unsynced.map((p) => {
            'id': p['id'],
            'no_po': p['no_po'],
            'no_faktur': p['no_po'],
            'supplier_id': p['supplier_id'],
            'supplier_nama': p['supplier_nama'],
            'produk_id': p['produk_id'],
            'qty': p['qty'],
            'harga_beli': p['harga_beli'],
            'total': p['total'],
            'tanggal': p['tanggal'],
            'petugas': p['petugas'],
            'status': p['status'],
            'created_at': p['created_at'],
          }).toList(),
        });
        if (res['ok'] == true) {
          for (var p in unsynced) {
            await db.update(
              'pembelian',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [p['id']],
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _pullCloudSettings() async {
    try {
      final res = await _callApi('sync.pullSettings');
      if (res['ok'] == true && res['data'] != null) {
        final settings = res['data']['settings'] as Map<String, dynamic>?;
        if (settings != null) {
          final prefs = await SharedPreferences.getInstance();
          if (settings['nama_apotek'] != null && settings['nama_apotek'].toString().isNotEmpty) {
            await prefs.setString('setting_nama_apotek', settings['nama_apotek'].toString());
          }
          if (settings['slogan_apotek'] != null && settings['slogan_apotek'].toString().isNotEmpty) {
            await prefs.setString('setting_slogan_apotek', settings['slogan_apotek'].toString());
          }
          if (settings['alamat_apotek'] != null && settings['alamat_apotek'].toString().isNotEmpty) {
            await prefs.setString('setting_alamat_apotek', settings['alamat_apotek'].toString());
          }
          if (settings['telepon_apotek'] != null) {
            await prefs.setString('setting_telepon_apotek', settings['telepon_apotek'].toString());
          }
          if (settings['footer_struk'] != null && settings['footer_struk'].toString().isNotEmpty) {
            await prefs.setString('setting_footer_struk', settings['footer_struk'].toString());
          }
          await PrinterService.loadStoreInfoFromPrefs();
        }
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
