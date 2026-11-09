import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/database_helper.dart';
import '../models/user_model.dart';
import '../services/sync_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  Future<void> checkExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email != null) {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('users', where: 'email = ?', whereArgs: [email]);
      if (res.isNotEmpty) {
        _currentUser = UserModel.fromMap(res.first);
        notifyListeners();
      }
    }
  }

  Future<bool> login(String inputIdentifier, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final trimmedInput = inputIdentifier.trim().toLowerCase();
    final trimmedPass = password.trim();
    final hashedPass = sha256.convert(utf8.encode(trimmedPass)).toString();

    try {
      final db = await DatabaseHelper.instance.database;

      // -------------------------------------------------------------
      // 1. Online Server Authentication:
      // Validasi langsung akun & kata sandi ke database server website
      // -------------------------------------------------------------
      debugPrint('[AUTH_LOGIN] trimmedInput: $trimmedInput, trimmedPass: $trimmedPass');
      final cloudRes = await SyncService.instance.loginWithCloudCredentials(trimmedInput, trimmedPass);
      debugPrint('[AUTH_LOGIN] cloudRes: $cloudRes');

      if (cloudRes['success'] == true && cloudRes['data'] != null) {
        final data = cloudRes['data'] as Map<String, dynamic>;
        final me = (data['me'] ?? {}) as Map<String, dynamic>;
        final userId = me['id']?.toString() ?? 'USR-${DateTime.now().millisecondsSinceEpoch}';
        final userEmail = me['email']?.toString() ?? (trimmedInput.contains('@') ? trimmedInput : '$trimmedInput@pos.local');
        final userName = me['name']?.toString() ?? 'Staf Apotek';
        final userRole = (me['role']?.toString() ?? 'KASIR').toUpperCase();
        final now = DateTime.now().toIso8601String();

        // Simpan / update akun ke database lokal SQLite agar bisa digunakan offline berikutnya
        final existInDb = await db.query(
          'users',
          where: 'id = ? OR LOWER(email) = ?',
          whereArgs: [userId, userEmail.toLowerCase()],
          limit: 1,
        );

        if (existInDb.isNotEmpty) {
          await db.update(
            'users',
            {
              'name': userName,
              'email': userEmail,
              'password_hash': hashedPass,
              'role': userRole,
              'status': 'AKTIF',
            },
            where: 'id = ?',
            whereArgs: [existInDb.first['id']],
          );
        } else {
          await db.insert('users', {
            'id': userId,
            'email': userEmail,
            'name': userName,
            'password_hash': hashedPass,
            'role': userRole,
            'status': 'AKTIF',
            'created_at': now,
          });
        }

        final newUserMap = {
          'id': userId,
          'email': userEmail,
          'name': userName,
          'password_hash': hashedPass,
          'role': userRole,
          'status': 'AKTIF',
          'created_at': now,
        };

        _currentUser = UserModel.fromMap(newUserMap);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', _currentUser!.email);
        await SyncService.instance.setCloudCredentials(_currentUser!.email, trimmedPass);

        // Jalankan background sync agar seluruh data (produk, transaksi, user lain, log) langsung tersinkron
        unawaited(SyncService.instance.syncAll(isBackground: true));

        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Jika server berhasil dihubungi namun menolak kredensial (misal salah password / user tidak ditemukan)
      if (cloudRes['success'] == false && cloudRes['isNetworkError'] == false) {
        _errorMessage = cloudRes['message']?.toString() ?? 'Username/email atau kata sandi tidak cocok.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // -------------------------------------------------------------
      // 2. Mode Offline (Hanya saat koneksi ke server web tidak terjangkau):
      // Cocokkan dengan data akun pengguna yang sebelumnya telah tersinkron di SQLite
      // -------------------------------------------------------------
      final localUsers = await db.query(
        'users',
        where: 'LOWER(email) = ? OR LOWER(email) = ? OR LOWER(name) = ?',
        whereArgs: [trimmedInput, '$trimmedInput@pos.local', trimmedInput],
      );

      for (var u in localUsers) {
        if ((u['status'] ?? '').toString().toUpperCase() != 'AKTIF') continue;
        final storedHash = (u['password_hash'] ?? '').toString().trim();

        bool isPassValid = false;
        if (storedHash == hashedPass || storedHash == trimmedPass) {
          isPassValid = true;
        } else if (storedHash == md5.convert(utf8.encode(trimmedPass)).toString()) {
          isPassValid = true;
        }

        if (isPassValid) {
          final userData = Map<String, dynamic>.from(u);
          if (userData['password_hash'] != hashedPass) {
            await db.update('users', {'password_hash': hashedPass}, where: 'id = ?', whereArgs: [userData['id']]);
            userData['password_hash'] = hashedPass;
          }

          _currentUser = UserModel.fromMap(userData);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_email', _currentUser!.email);

          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      // Jika jaringan server offline dan akun belum pernah tersimpan di lokal
      _errorMessage = 'Tidak dapat terhubung ke server dan akun tidak ditemukan secara offline.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan sistem: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.clear();
    notifyListeners();
  }
}
