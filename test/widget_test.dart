// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_centers_finance/app/app.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const QuranFinanceApp());
  });
}
