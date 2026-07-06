import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiomi/main.dart';

void main() {
  testWidgets('Xiomi muestra la pantalla de carga', (tester) async {
    await tester.pumpWidget(const XiomiApp());
    expect(find.text('Xiomi'), findsOneWidget);
    expect(find.byIcon(Icons.document_scanner_rounded), findsOneWidget);
  });
}
