import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('apotek_tia_farma.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    // Gunakan direktori AppData agar bisa diakses tanpa hak Administrator
    final appDir = await getApplicationSupportDirectory();
    final path = p.join(appDir.path, filePath);

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
    await _migrateSchema(db);
    return db;
  }

  Future<void> _migrateSchema(Database db) async {
    try {
      await db.execute("ALTER TABLE produk ADD COLUMN satuan_eceran TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE produk ADD COLUMN isi_eceran INTEGER DEFAULT 1");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE produk ADD COLUMN harga_eceran REAL DEFAULT 0");
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS activity_log (
          id TEXT PRIMARY KEY,
          user_name TEXT NOT NULL,
          user_role TEXT NOT NULL,
          action_type TEXT NOT NULL,
          title TEXT NOT NULL,
          details TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    } catch (_) {}
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Users Table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'KASIR',
        status TEXT NOT NULL DEFAULT 'AKTIF',
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Produk Table
    await db.execute('''
      CREATE TABLE produk (
        id TEXT PRIMARY KEY,
        kode TEXT NOT NULL,
        nama TEXT NOT NULL,
        kategori TEXT DEFAULT '',
        harga_beli REAL NOT NULL DEFAULT 0,
        harga_jual REAL NOT NULL DEFAULT 0,
        stok INTEGER NOT NULL DEFAULT 0,
        satuan TEXT DEFAULT 'PCS',
        satuan_eceran TEXT DEFAULT 'Tablet',
        isi_eceran INTEGER DEFAULT 10,
        harga_eceran REAL DEFAULT 0,
        tgl_kadaluwarsa TEXT,
        status TEXT NOT NULL DEFAULT 'AKTIF',
        created_at TEXT NOT NULL
      )
    ''');

    // 3. Transaksi Table
    await db.execute('''
      CREATE TABLE transaksi (
        id TEXT PRIMARY KEY,
        invoice TEXT NOT NULL,
        tanggal TEXT NOT NULL,
        kasir_email TEXT NOT NULL,
        kasir_name TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0,
        diskon REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        bayar REAL NOT NULL DEFAULT 0,
        kembalian REAL NOT NULL DEFAULT 0,
        metode TEXT NOT NULL DEFAULT 'CASH',
        status TEXT NOT NULL DEFAULT 'SELESAI',
        is_synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // 4. Transaksi Detail Table
    await db.execute('''
      CREATE TABLE transaksi_detail (
        id TEXT PRIMARY KEY,
        transaksi_id TEXT NOT NULL,
        invoice TEXT NOT NULL,
        produk_id TEXT NOT NULL,
        kode TEXT DEFAULT '',
        nama TEXT DEFAULT '',
        qty INTEGER NOT NULL DEFAULT 0,
        harga REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (transaksi_id) REFERENCES transaksi (id) ON DELETE CASCADE
      )
    ''');

    // 5. Supplier Table
    await db.execute('''
      CREATE TABLE supplier (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL,
        kontak TEXT,
        telepon TEXT,
        alamat TEXT,
        status TEXT NOT NULL DEFAULT 'AKTIF',
        created_at TEXT NOT NULL
      )
    ''');

    // 6. Pembelian / PO Table
    await db.execute('''
      CREATE TABLE pembelian (
        id TEXT PRIMARY KEY,
        no_po TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        supplier_nama TEXT NOT NULL,
        tanggal TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'SELESAI',
        created_at TEXT NOT NULL
      )
    ''');

    // 7. Resep & Pasien Table
    await db.execute('''
      CREATE TABLE resep (
        id TEXT PRIMARY KEY,
        no_resep TEXT NOT NULL,
        nama_pasien TEXT NOT NULL,
        nama_dokter TEXT NOT NULL,
        tanggal TEXT NOT NULL,
        keterangan TEXT,
        total REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'SELESAI',
        created_at TEXT NOT NULL
      )
    ''');

    // 8. Settings Table
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL
      )
    ''');

    // Inisialisasi Data Awal (Seeds)
    await _seedDatabase(db);
  }

  Future<void> _seedDatabase(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 1. Default User (Admin Only)
    await db.insert('users', {
      'id': 'USR-01',
      'email': 'admin@pos.local',
      'name': 'Apoteker Administrator',
      'password_hash': 'ApotekTia2026!',
      'role': 'ADMIN',
      'status': 'AKTIF',
      'created_at': now,
    });

    // 2. Default settings
    await db.insert('settings', {
      'key': 'nama_apotek',
      'value': 'APOTEK TIA FARMA',
    });
    await db.insert('settings', {
      'key': 'alamat_apotek',
      'value': 'Pelayanan Kesehatan Keluarga',
    });
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
