class PembelianModel {
  final String id;
  final String noPo;
  final String supplierId;
  final String supplierNama;
  final String produkId;
  final int qty;
  final double hargaBeli;
  final double total;
  final String tanggal;
  final String petugas;
  final String status;
  final String createdAt;
  final bool isSynced;

  PembelianModel({
    required this.id,
    required this.noPo,
    required this.supplierId,
    required this.supplierNama,
    this.produkId = '',
    this.qty = 0,
    this.hargaBeli = 0.0,
    required this.total,
    required this.tanggal,
    this.petugas = '',
    this.status = 'LUNAS',
    required this.createdAt,
    this.isSynced = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'no_po': noPo,
      'supplier_id': supplierId,
      'supplier_nama': supplierNama,
      'produk_id': produkId,
      'qty': qty,
      'harga_beli': hargaBeli,
      'total': total,
      'tanggal': tanggal,
      'petugas': petugas,
      'status': status,
      'created_at': createdAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory PembelianModel.fromMap(Map<String, dynamic> map) {
    return PembelianModel(
      id: map['id']?.toString() ?? '',
      noPo: map['no_po']?.toString() ?? map['no_faktur']?.toString() ?? '',
      supplierId: map['supplier_id']?.toString() ?? '',
      supplierNama: map['supplier_nama']?.toString() ?? 'Supplier',
      produkId: map['produk_id']?.toString() ?? '',
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      hargaBeli: (map['harga_beli'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      tanggal: map['tanggal']?.toString() ?? '',
      petugas: map['petugas']?.toString() ?? '',
      status: map['status']?.toString() ?? 'LUNAS',
      createdAt: map['created_at']?.toString() ?? '',
      isSynced: (map['is_synced'] as num?)?.toInt() == 1,
    );
  }
}

