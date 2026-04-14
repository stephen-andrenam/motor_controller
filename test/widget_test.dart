import 'package:flutter_test/flutter_test.dart';
import 'package:motor_controller/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MotorControllerApp());
    expect(find.text('Motor Controller'), findsOneWidget);
  });
}
