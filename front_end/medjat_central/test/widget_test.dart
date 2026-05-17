import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MedjatCentralApp());
    expect(find.text('Medjat Central'), findsOneWidget);
  });
}
