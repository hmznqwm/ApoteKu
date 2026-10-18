import 'package:flutter_test/flutter_test.dart';
import 'package:apotek_app/models/produk_model.dart';

void main() {
  group('ProdukModel & Multi-Satuan Unit Tests', () {
    test('Pengujian Inisialisasi ProdukModel dengan Satuan Utama', () {
      final produk = ProdukModel(
        id: 'PROD-001',
        kode: '89999991234',
        nama: 'Paracetamol 500mg Kaplet',
        kategori: 'Obat Bebas',
        hargaBeli: 8000,
        hargaJual: 10000,
        stok: 50,
        satuan: 'Strip',
      );

      expect(produk.nama, equals('Paracetamol 500mg Kaplet'));
      expect(produk.hargaJual, equals(10000));
      expect(produk.satuan, equals('Strip'));
      expect(produk.isLowStock, isFalse);
      expect(produk.isOutOfStock, isFalse);
    });

    test('Pengujian Multi-Satuan Eceran & Hitung Otomatis Harga Tablet', () {
      final produk = ProdukModel(
        id: 'PROD-002',
        kode: '89999995678',
        nama: 'Amoxicillin 500mg',
        kategori: 'Antibiotik',
        hargaBeli: 12000,
        hargaJual: 15000,
        stok: 20,
        satuan: 'Strip',
        satuanEceran: 'Tablet',
        isiEceran: 10,
        hargaEceran: 0.0, // otomatis 15000 / 10 = 1500
      );

      expect(produk.effectiveSatuanEceran, equals('Tablet'));
      expect(produk.effectiveIsiEceran, equals(10));
      expect(produk.effectiveHargaEceran, equals(1500.0));
    });

    test('Pengujian Custom Harga Eceran Manual', () {
      final produk = ProdukModel(
        id: 'PROD-003',
        kode: '89999999999',
        nama: 'Cataflam 50mg',
        kategori: 'Obat Keras',
        hargaBeli: 40000,
        hargaJual: 50000,
        stok: 10,
        satuan: 'Strip',
        satuanEceran: 'Tablet',
        isiEceran: 10,
        hargaEceran: 5500.0,
      );

      expect(produk.effectiveHargaEceran, equals(5500.0));
    });

    test('Pengujian Status Stok & Kedaluwarsa', () {
      final lowStock = ProdukModel(
        id: 'P1',
        kode: '001',
        nama: 'Obat A',
        kategori: 'Umum',
        hargaBeli: 1000,
        hargaJual: 2000,
        stok: 3,
        satuan: 'PCS',
      );

      expect(lowStock.isLowStock, isTrue);
      expect(lowStock.isOutOfStock, isFalse);

      final outOfStock = lowStock.copyWith(stok: 0);
      expect(outOfStock.isOutOfStock, isTrue);
    });
  });
}
