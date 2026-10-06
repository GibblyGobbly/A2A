import 'package:flutter_test/flutter_test.dart';
import 'package:universal_converter/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const OmniConvertApp());
    expect(find.text('Image & Compression Studio'), findsOneWidget);
  });
}
