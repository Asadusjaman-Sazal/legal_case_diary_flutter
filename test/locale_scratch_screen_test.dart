import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/scratch/locale_scratch_screen.dart';
import 'package:legal_case_diary/shared/providers/locale_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test wrapper that rebuilds [MaterialApp] whenever the active locale changes
/// so that [AppLocalizations] follows the same locale as [localeProvider].
class _LocalizedTestApp extends ConsumerWidget {
  const _LocalizedTestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: const LocaleScratchScreen(),
    );
  }
}

void main() {
  testWidgets('LocaleScratchScreen renders and toggles locale', (tester) async {
    // Provide a fresh SharedPreferences instance for each test run.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const _LocalizedTestApp(),
      ),
    );

    // Verify the Bengali greeting is shown by default.
    expect(find.text('হ্যালো'), findsOneWidget);

    // Tap the English button.
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // Verify the English greeting is shown after the switch.
    expect(find.text('Hello'), findsOneWidget);

    // Tap the Bengali button.
    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();

    // Verify the Bengali greeting is shown again.
    expect(find.text('হ্যালো'), findsOneWidget);
  });
}
