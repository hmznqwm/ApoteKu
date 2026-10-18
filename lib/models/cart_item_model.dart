import 'produk_model.dart';

class CartItemModel {
  final ProdukModel produk;
  int qty;
  bool isEceran;
  String selectedSatuan;
  double customPrice;
  double discount; // Diskon dalam rupiah

  CartItemModel({
    required this.produk,
    this.qty = 1,
    this.isEceran = false,
    String? selectedSatuan,
    double? customPrice,
    this.discount = 0.0,
  })  : selectedSatuan = selectedSatuan ??
            (isEceran ? produk.effectiveSatuanEceran : produk.satuan),
        customPrice = customPrice ??
            (isEceran ? produk.effectiveHargaEceran : produk.hargaJual);

  void toggleUnit(bool eceran) {
    isEceran = eceran;
    if (isEceran) {
      selectedSatuan = produk.effectiveSatuanEceran;
      customPrice = produk.effectiveHargaEceran;
    } else {
      selectedSatuan = produk.satuan;
      customPrice = produk.hargaJual;
    }
  }

  double get subtotal {
    final raw = (customPrice * qty) - discount;
    return raw > 0 ? raw : 0.0;
  }
}
