import 'package:flutter_test/flutter_test.dart';
import 'package:twogether/main.dart';

void main() {
  testWidgets('TWOGETHER welcome screen appears',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TwoGetherApp());

    expect(find.text('TWOGETHER'), findsOneWidget);
    expect(
      find.text('Two Hearts. One Little World.'),
      findsOneWidget,
    );
    expect(find.text('Our Journey Begins'), findsOneWidget);
  });
}
