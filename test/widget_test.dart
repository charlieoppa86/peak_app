import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:peak_app/app.dart';

void main() {
  testWidgets('App boots into the home tab with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const PeakApp());
    await tester.pumpAndSettle();

    expect(find.text('홈 · 날씨 캘린더'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsWidgets);
    expect(find.text('프로필'), findsOneWidget);
  });
}
