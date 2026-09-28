import 'package:flutter_test/flutter_test.dart';
import 'package:app_standard/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AchatVenteStockApp());
    expect(find.text('ACHATS & FOURNISSEURS'), findsOneWidget);
  });
}
