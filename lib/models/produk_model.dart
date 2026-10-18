class ProdukModel {
  final String id;
  final String kode;
  final String nama;
  final String kategori;
  final double hargaBeli;
  final double hargaJual;
  final int stok;
  final String satuan; // Satuan Utama (cth: Strip, Dus)
  final String satuanEceran; // Satuan Eceran (cth: Tablet, Pil)
  final int isiEceran; // Jumlah eceran per satuan utama (cth: 10 tablet per strip)
  final double hargaEceran; // Harga per tablet/eceran (jika 0, dihitung dari hargaJual / isiEceran)
  final String? tglKadaluwarsa;
  final String status;
  final String? createdAt;

  ProdukModel({
    required this.id,
    required this.kode,
    required this.nama,
    required this.kategori,
    required this.hargaBeli,
    required this.hargaJual,
    required this.stok,
    required this.satuan,
    this.satuanEceran = '',
    this.isiEceran = 1,
    this.hargaEceran = 0.0,
    this.tglKadaluwarsa,
    this.status = 'AKTIF',
    this.createdAt,
  });

  factory ProdukModel.fromMap(Map<String, dynamic> map) {
    return ProdukModel(
      id: map['id']?.toString() ?? '',
      kode: map['kode']?.toString() ?? '',
      nama: map['nama']?.toString() ?? '',
      kategori: map['kategori']?.toString() ?? 'Umum',
      hargaBeli: (map['harga_beli'] as num?)?.toDouble() ?? 0.0,
      hargaJual: (map['harga_jual'] as num?)?.toDouble() ?? 0.0,
      stok: (map['stok'] as num?)?.toInt() ?? 0,
      satuan: map['satuan']?.toString() ?? 'PCS',
      satuanEceran: map['satuan_eceran']?.toString() ?? '',
      isiEceran: (map['isi_eceran'] as num?)?.toInt() ?? 1,
      hargaEceran: (map['harga_eceran'] as num?)?.toDouble() ?? 0.0,
      tglKadaluwarsa: map['tgl_kadaluwarsa']?.toString(),
      status: map['status']?.toString() ?? 'AKTIF',
      createdAt: map['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kode': kode,
      'nama': nama,
      'kategori': kategori,
      'harga_beli': hargaBeli,
      'harga_jual': hargaJual,
      'stok': stok,
      'satuan': satuan,
      'satuan_eceran': satuanEceran,
      'isi_eceran': isiEceran,
      'harga_eceran': hargaEceran,
      'tgl_kadaluwarsa': tglKadaluwarsa,
      'status': status,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  // Helpers Multi-Satuan Dinamis
  bool get hasEceranOption {
    final sUtama = satuan.trim().toUpperCase();
    final sEceran = satuanEceran.trim().toUpperCase();

    // 1. Jika satuan eceran kosong atau persis sama dengan satuan utama -> Tanpa eceran
    if (sEceran.isEmpty || sEceran == sUtama) return false;

    // 2. Jika isiEceran <= 1 dan hargaEceran <= 0 -> Tanpa eceran
    if (isiEceran <= 1 && hargaEceran <= 0) return false;

    // 3. Filter data legacy (di mana DB terlanjur terisi default 'Tablet' & isi 10 untuk produk non-obat seperti PCS/BOTOL):
    final isSatuanGrosirApotek = ['STRIP', 'BOX', 'DUS', 'BLISTER', 'KAPLET', 'PACK'].contains(sUtama);
    final isKategoriObat = kategori.toLowerCase().contains('obat') ||
        kategori.toLowerCase().contains('suplemen') ||
        kategori.toLowerCase().contains('herbal') ||
        kategori.toLowerCase().contains('vitamin');

    if (sEceran == 'TABLET' && !isSatuanGrosirApotek && !isKategoriObat && hargaEceran <= 0) {
      return false;
    }

    return true;
  }

  String get effectiveSatuanEceran {
    if (hasEceranOption) {
      return satuanEceran.trim();
    }
    return satuan.trim();
  }

  int get effectiveIsiEceran => (hasEceranOption && isiEceran > 0) ? isiEceran : 1;

  double get effectiveHargaEceran {
    if (!hasEceranOption) return hargaJual;
    if (hargaEceran > 0) return hargaEceran;
    if (effectiveIsiEceran > 1 && hargaJual > 0) {
      return hargaJual / effectiveIsiEceran;
    }
    return hargaJual;
  }

  // Helper untuk Status Stok & Kedaluwarsa
  bool get isLowStock => stok <= 5;
  bool get isOutOfStock => stok <= 0;

  DateTime? get expiryDate {
    if (tglKadaluwarsa == null || tglKadaluwarsa!.isEmpty) return null;
    return DateTime.tryParse(tglKadaluwarsa!);
  }

  int get daysUntilExpiry {
    final exp = expiryDate;
    if (exp == null) return 9999;
    return exp.difference(DateTime.now()).inDays;
  }

  bool get isExpired => daysUntilExpiry <= 0;
  bool get isCriticalExpiry => daysUntilExpiry > 0 && daysUntilExpiry <= 30;
  bool get isNearExpiry => daysUntilExpiry > 30 && daysUntilExpiry <= 90;

  ProdukModel copyWith({
    String? id,
    String? kode,
    String? nama,
    String? kategori,
    double? hargaBeli,
    double? hargaJual,
    int? stok,
    String? satuan,
    String? satuanEceran,
    int? isiEceran,
    double? hargaEceran,
    String? tglKadaluwarsa,
    String? status,
    String? createdAt,
  }) {
    return ProdukModel(
      id: id ?? this.id,
      kode: kode ?? this.kode,
      nama: nama ?? this.nama,
      kategori: kategori ?? this.kategori,
      hargaBeli: hargaBeli ?? this.hargaBeli,
      hargaJual: hargaJual ?? this.hargaJual,
      stok: stok ?? this.stok,
      satuan: satuan ?? this.satuan,
      satuanEceran: satuanEceran ?? this.satuanEceran,
      isiEceran: isiEceran ?? this.isiEceran,
      hargaEceran: hargaEceran ?? this.hargaEceran,
      tglKadaluwarsa: tglKadaluwarsa ?? this.tglKadaluwarsa,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
