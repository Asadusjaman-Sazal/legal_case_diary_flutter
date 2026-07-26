import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/scratch/typography_scratch.dart';

void main() {
  group('TypographyScratch', () {
    testWidgets('renders every font family sample', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TypographyScratch()));

      expect(find.text('Typography Scratch'), findsOneWidget);
      expect(find.text('Manrope (Headlines)'), findsOneWidget);
      expect(find.text('Inter (Body)'), findsOneWidget);
      expect(find.text('IBM Plex Sans (Labels & Data)'), findsOneWidget);
      expect(find.text('Tiro Bangla (Bengali)'), findsOneWidget);
      expect(find.text('বাংলা লেখার নমুনা — সব ফন্ট সঠিকভাবে লোড হয়েছে কিনা তা যাচাই করুন।'),
          findsOneWidget);
    });
  });
}
