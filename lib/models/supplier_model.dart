class SupplierModel {
  final String id;
  final String nama;
  final String kontak;
  final String telepon;
  final String alamat;
  final String status;

  SupplierModel({
    required this.id,
    required this.nama,
    required this.kontak,
    required this.telepon,
    required this.alamat,
    this.status = 'AKTIF',
  });

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: map['id']?.toString() ?? '',
      nama: map['nama']?.toString() ?? '',
      kontak: map['kontak']?.toString() ?? '',
      telepon: map['telepon']?.toString() ?? '',
      alamat: map['alamat']?.toString() ?? '',
      status: map['status']?.toString() ?? 'AKTIF',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'kontak': kontak,
      'telepon': telepon,
      'alamat': alamat,
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
