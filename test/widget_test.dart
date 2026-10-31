import 'package:flutter_test/flutter_test.dart';

import 'package:yaarexbook/main.dart';

void main() {
  testWidgets('L\'application démarre', (WidgetTester tester) async {
    await tester.pumpWidget(const YaarexbookApp());
    expect(find.byType(YaarexbookApp), findsOneWidget);
  });
}