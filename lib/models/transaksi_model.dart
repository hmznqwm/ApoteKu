class TransaksiDetailModel {
  final String id;
  final String transaksiId;
  final String invoice;
  final String produkId;
  final String kode;
  final String nama;
  final int qty;
  final double harga;
  final double hargaBeli;
  final double subtotal;

  TransaksiDetailModel({
    required this.id,
    required this.transaksiId,
    required this.invoice,
    required this.produkId,
    required this.kode,
    required this.nama,
    required this.qty,
    required this.harga,
    this.hargaBeli = 0.0,
    required this.subtotal,
  });

  factory TransaksiDetailModel.fromMap(Map<String, dynamic> map) {
    return TransaksiDetailModel(
      id: map['id']?.toString() ?? '',
      transaksiId: map['transaksi_id']?.toString() ?? '',
      invoice: map['invoice']?.toString() ?? '',
      produkId: map['produk_id']?.toString() ?? '',
      kode: map['kode']?.toString() ?? '',
      nama: map['nama']?.toString() ?? '',
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      harga: (map['harga'] as num?)?.toDouble() ?? 0.0,
      hargaBeli: (map['harga_beli'] as num?)?.toDouble() ?? 0.0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaksi_id': transaksiId,
      'invoice': invoice,
      'produk_id': produkId,
      'kode': kode,
      'nama': nama,
      'qty': qty,
      'harga': harga,
      'subtotal': subtotal,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

class TransaksiModel {
  final String id;
  final String invoice;
  final String tanggal;
  final String kasirEmail;
  final String kasirName;
  final double subtotal;
  final double diskon;
  final double total;
  final double bayar;
  final double kembalian;
  final String metode;
  final String status;
  final int isSynced;
  final String createdAt;
  final List<TransaksiDetailModel> details;

  double get omsetBersih {
    double totalOmset = 0.0;
    for (var d in details) {
      totalOmset += (d.harga - d.hargaBeli) * d.qty;
    }
    return totalOmset - diskon;
  }

  TransaksiModel({
    required this.id,
    required this.invoice,
    required this.tanggal,
    required this.kasirEmail,
    required this.kasirName,
    required this.subtotal,
    required this.diskon,
    required this.total,
    required this.bayar,
    required this.kembalian,
    this.metode = 'CASH',
    this.status = 'SELESAI',
    this.isSynced = 0,
    required this.createdAt,
    this.details = const [],
  });

  factory TransaksiModel.fromMap(Map<String, dynamic> map, {List<TransaksiDetailModel> details = const []}) {
    return TransaksiModel(
      id: map['id']?.toString() ?? '',
      invoice: map['invoice']?.toString() ?? '',
      tanggal: map['tanggal']?.toString() ?? '',
      kasirEmail: map['kasir_email']?.toString() ?? '',
      kasirName: map['kasir_name']?.toString() ?? 'Kasir',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      diskon: (map['diskon'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      bayar: (map['bayar'] as num?)?.toDouble() ?? 0.0,
      kembalian: (map['kembalian'] as num?)?.toDouble() ?? 0.0,
      metode: map['metode']?.toString() ?? 'CASH',
      status: map['status']?.toString() ?? 'SELESAI',
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at']?.toString() ?? '',
      details: details,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice': invoice,
      'tanggal': tanggal,
      'kasir_email': kasirEmail,
      'kasir_name': kasirName,
      'subtotal': subtotal,
      'diskon': diskon,
      'total': total,
      'bayar': bayar,
      'kembalian': kembalian,
      'metode': metode,
      'status': status,
      'is_synced': isSynced,
      'created_at': createdAt,
    };
  }
}
