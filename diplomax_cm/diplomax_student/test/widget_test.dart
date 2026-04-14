import 'package:flutter_test/flutter_test.dart';

import 'package:diplomax_student/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DiplomaxStudentApp());
    expect(find.byType(DiplomaxStudentApp), findsOneWidget);
  });
}
