import 'package:flutter_test/flutter_test.dart';
import 'package:demo/app/app.dart'; // <-- ใช้ชื่อแพ็กเกจใน pubspec.yaml (ต้องเป็นตัวพิมพ์เล็ก)

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
