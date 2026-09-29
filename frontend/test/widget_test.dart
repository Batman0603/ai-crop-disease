import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app.dart';

void main() {
  testWidgets('CropCare app displays main navigation', (tester) async {
    await tester.pumpWidget(const CropDiseaseApp());

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Detect'), findsWidgets);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Keep your crops healthy'), findsOneWidget);
  });
}
