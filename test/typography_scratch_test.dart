import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/constants/app_typography.dart';
import 'package:legal_case_diary/core/scratch/typography_scratch.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';

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

  test('keeps Tiro Bangla in the fallback chain for explicit text styles', () {
    final englishRoles = <TextStyle>[
      AppTypography.headlineLg,
      AppTypography.headlineMd,
      AppTypography.titleLg,
      AppTypography.titleMd,
      AppTypography.bodyLg,
      AppTypography.bodyMd,
      AppTypography.bodySm,
      AppTypography.labelLg,
      AppTypography.labelMd,
      AppTypography.caseNumber,
    ];

    for (final style in englishRoles) {
      expect(style.fontFamilyFallback, contains('TiroBangla'));
    }

    expect(
      AppTheme.lightTheme(const Locale('bn')).textTheme.bodyMedium?.fontFamily,
      'TiroBangla',
    );
  });
}
