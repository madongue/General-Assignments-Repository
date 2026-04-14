import 'package:flutter_test/flutter_test.dart';

import 'package:diplomax_university/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DiplomaxUniversityApp());
    expect(find.byType(DiplomaxUniversityApp), findsOneWidget);
  });
}
