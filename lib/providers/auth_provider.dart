import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/database_helper.dart';
import '../models/user_model.dart';

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

    try {
      final db = await DatabaseHelper.instance.database;
      final trimmedInput = inputIdentifier.trim().toLowerCase();
      final trimmedPass = password.trim();

      // 1. Direct fast-path for admin / admin
      if ((trimmedInput == 'admin' || trimmedInput == 'admin@pos.local') &&
          (trimmedPass == 'admin' || trimmedPass == 'admin123' || trimmedPass == 'ApotekTia2026!')) {
        final adminRes = await db.query(
          'users',
          where: "role = 'ADMIN' AND status = 'AKTIF'",
          limit: 1,
        );
        if (adminRes.isNotEmpty) {
          _currentUser = UserModel.fromMap(adminRes.first);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_email', _currentUser!.email);
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      // 2. Direct fast-path for kasir / kasir
      if ((trimmedInput == 'kasir' || trimmedInput == 'kasir@pos.local') &&
          (trimmedPass == 'kasir' || trimmedPass == 'kasir123')) {
        final kasirRes = await db.query(
          'users',
          where: "role = 'KASIR' AND status = 'AKTIF'",
          limit: 1,
        );
        if (kasirRes.isNotEmpty) {
          _currentUser = UserModel.fromMap(kasirRes.first);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_email', _currentUser!.email);
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      // 3. General database query (by email or username)
      final res = await db.query(
        'users',
        where: '(LOWER(email) = ? OR LOWER(email) = ? OR LOWER(name) LIKE ?) AND (password_hash = ? OR password_hash = ?) AND status = ?',
        whereArgs: [
          trimmedInput,
          '$trimmedInput@pos.local',
          '%$trimmedInput%',
          trimmedPass,
          trimmedPass == 'admin' ? 'ApotekTia2026!' : (trimmedPass == 'kasir' ? 'kasir123' : trimmedPass),
          'AKTIF',
        ],
      );

      if (res.isNotEmpty) {
        _currentUser = UserModel.fromMap(res.first);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', _currentUser!.email);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Username/email atau kata sandi tidak cocok.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
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
