import 'package:flutter/foundation.dart';
import '../models/activity_log_model.dart';
import '../core/database/database_helper.dart';

class ActivityLogProvider extends ChangeNotifier {
  List<ActivityLogModel> _logs = [];
  bool _isLoading = false;

  List<ActivityLogModel> get logs => _logs;
  bool get isLoading => _isLoading;

  Future<void> fetchLogs() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        'activity_log',
        orderBy: 'created_at DESC',
      );
      _logs = maps.map((m) => ActivityLogModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error fetching activity logs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logActivity({
    required String userName,
    required String userRole,
    required String actionType, // 'TAMBAH', 'EDIT', 'HAPUS', 'REFUND'
    required String title,
    required String details,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final newLog = ActivityLogModel(
        id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
        userName: userName,
        userRole: userRole,
        actionType: actionType,
        title: title,
        details: details,
        createdAt: DateTime.now().toIso8601String(),
      );

      await db.insert('activity_log', newLog.toMap());

      // Pangkas otomatis data lama jika melebihi 100 data (Auto FIFO)
      await db.rawDelete('''
        DELETE FROM activity_log 
        WHERE id NOT IN (
          SELECT id FROM activity_log 
          ORDER BY created_at DESC 
          LIMIT 100
        )
      ''');

      await fetchLogs();
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  Future<void> clearAllLogs() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('activity_log');
      _logs.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing activity logs: $e');
    }
  }
}
