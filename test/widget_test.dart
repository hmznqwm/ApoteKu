import 'package:flutter_test/flutter_test.dart';
import 'package:apotek_app/main.dart';
import 'package:apotek_app/providers/auth_provider.dart';
import 'package:apotek_app/providers/cart_provider.dart';
import 'package:apotek_app/providers/produk_provider.dart';
import 'package:apotek_app/providers/transaksi_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('ApotekApp initialization test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ProdukProvider()),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => TransaksiProvider()),
        ],
        child: const ApotekApp(),
      ),
    );

    expect(find.byType(ApotekApp), findsOneWidget);
  });
}
