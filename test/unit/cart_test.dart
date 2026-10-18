import 'package:flutter_test/flutter_test.dart';
import 'package:apotek_app/models/produk_model.dart';
import 'package:apotek_app/providers/cart_provider.dart';

void main() {
  group('CartProvider & Penjualan Eceran 2 Pil Unit Tests', () {
    late CartProvider cartProvider;
    late ProdukModel produkA;

    setUp(() {
      cartProvider = CartProvider();
      produkA = ProdukModel(
        id: 'PROD-100',
        kode: '89912345678',
        nama: 'Paracetamol 500mg',
        kategori: 'Obat Bebas',
        hargaBeli: 8000,
        hargaJual: 10000, // Harga 1 Strip (isi 10 tablet) = Rp 10.000
        stok: 15,
        satuan: 'Strip',
        satuanEceran: 'Tablet',
        isiEceran: 10,
        hargaEceran: 1000, // Rp 1.000 / tablet
      );
    });

    test('Menambah Produk Satuan Utama (1 Strip)', () {
      final success = cartProvider.addItem(produkA, isEceran: false, qty: 1);
      expect(success, isTrue);
      expect(cartProvider.itemList.length, equals(1));
      expect(cartProvider.itemList.first.selectedSatuan, equals('Strip'));
      expect(cartProvider.subtotal, equals(10000.0));
    });

    test('Menambah Pembelian Eceran 2 Pil/Tablet', () {
      // Pembeli membeli 2 tablet eceran
      final success = cartProvider.addItem(produkA, isEceran: true, qty: 2);
      expect(success, isTrue);
      expect(cartProvider.itemList.length, equals(1));

      final item = cartProvider.itemList.first;
      expect(item.isEceran, isTrue);
      expect(item.selectedSatuan, equals('Tablet'));
      expect(item.customPrice, equals(1000.0));
      expect(item.qty, equals(2));
      expect(item.subtotal, equals(2000.0)); // 2 x Rp 1.000 = Rp 2.000
    });

    test('Mengubah Satuan Item di Keranjang (Strip <=> Tablet)', () {
      cartProvider.addItem(produkA, isEceran: false, qty: 1);
      final itemKey = cartProvider.items.keys.first;

      // Saklar ke Eceran (Tablet)
      cartProvider.toggleItemUnit(itemKey, true);
      expect(cartProvider.itemList.first.isEceran, isTrue);
      expect(cartProvider.itemList.first.selectedSatuan, equals('Tablet'));
      expect(cartProvider.subtotal, equals(1000.0));

      // Saklar kembali ke Strip
      final newKey = cartProvider.items.keys.first;
      cartProvider.toggleItemUnit(newKey, false);
      expect(cartProvider.itemList.first.isEceran, isFalse);
      expect(cartProvider.itemList.first.selectedSatuan, equals('Strip'));
      expect(cartProvider.subtotal, equals(10000.0));
    });

    test('Mengatur Diskon dan Perhitungan Grand Total', () {
      cartProvider.addItem(produkA, isEceran: true, qty: 5); // 5 x 1000 = 5000
      cartProvider.setDiskon(500);

      expect(cartProvider.subtotal, equals(5000.0));
      expect(cartProvider.diskon, equals(500.0));
      expect(cartProvider.grandTotal, equals(4500.0));
    });

    test('Kosongkan Keranjang', () {
      cartProvider.addItem(produkA, isEceran: true, qty: 3);
      expect(cartProvider.itemList.isNotEmpty, isTrue);

      cartProvider.clearCart();
      expect(cartProvider.itemList.isEmpty, isTrue);
      expect(cartProvider.grandTotal, equals(0.0));
    });
  });
}
