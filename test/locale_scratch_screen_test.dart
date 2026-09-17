import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/l10n/app_translations.dart';
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

    // English is the current development default.
    expect(find.text('Hello'), findsOneWidget);

    // Tap the Bengali button.
    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();

    // Verify the Bengali greeting is shown after the switch.
    expect(find.text('হ্যালো'), findsOneWidget);

    // Tap the English button.
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // Verify the English greeting is shown again.
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('seed dropdown labels follow the active locale', (tester) async {
    final caseTypeId = caseTypeLabelEn.keys.first;
    final stepId = stepLabelEn.keys.first;
    final courtId = courtLabelEn.keys.first;
    final districtId = districtLabelEn.keys.first;

    Widget labels(Locale locale) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Builder(
        builder: (context) => Column(
          children: [
            Text(context.l10n.seedLabel(districtId)),
            Text(context.l10n.seedLabel(courtId)),
            Text(context.l10n.seedLabel(caseTypeId)),
            Text(context.l10n.seedLabel(stepId)),
          ],
        ),
      ),
    );

    await tester.pumpWidget(labels(const Locale('bn')));
    expect(find.text(districtLabelBn[districtId]!), findsOneWidget);
    expect(find.text(courtLabelBn[courtId]!), findsOneWidget);
    expect(find.text(caseTypeLabelBn[caseTypeId]!), findsOneWidget);
    expect(find.text(stepLabelBn[stepId]!), findsOneWidget);

    await tester.pumpWidget(labels(const Locale('en')));
    expect(find.text(districtLabelEn[districtId]!), findsOneWidget);
    expect(find.text(courtLabelEn[courtId]!), findsOneWidget);
    expect(find.text(caseTypeLabelEn[caseTypeId]!), findsOneWidget);
    expect(find.text(stepLabelEn[stepId]!), findsOneWidget);
  });

  group('caseTypeLabel (a case type stored by name)', () {
    /// Translations for [locale], without a widget tree.
    Future<AppTranslations> translations(Locale locale) async =>
        AppTranslations(await AppLocalizations.delegate.load(locale));

    test('keeps the stored name under English', () async {
      final t = await translations(const Locale('en'));
      expect(t.caseTypeLabel('Misc Case-'), 'Misc Case-');
    });

    test('shows a pre-seeded case type in Bengali', () async {
      final t = await translations(const Locale('bn'));
      final category = seedCategories.firstWhere(
        (c) => c.allCaseTypes.isNotEmpty,
      );
      final caseType = category.allCaseTypes.first;
      expect(
        t.caseTypeLabel(caseType.labelEn, courtCategoryId: category.id),
        caseType.labelBn,
      );
      // Guard: the label really changes, so the assertion above means something.
      expect(caseType.labelBn, isNot(caseType.labelEn));
    });

    test('uses the court category when a name is shared', () async {
      final t = await translations(const Locale('bn'));
      // "Misc Case" exists for the civil district courts and for the executive
      // magistrates with different Bengali labels, so the category decides.
      const shared = 'Misc Case-';
      final civil =
          caseTypeLabelBnByCourtCategory[districtCourtsCivilId]?[shared];
      final executive =
          caseTypeLabelBnByCourtCategory[executiveMagistrateId]?[shared];
      expect(civil, isNotNull);
      expect(executive, isNotNull);
      expect(civil, isNot(executive));
      expect(
        t.caseTypeLabel(shared, courtCategoryId: districtCourtsCivilId),
        civil,
      );
      expect(
        t.caseTypeLabel(shared, courtCategoryId: executiveMagistrateId),
        executive,
      );
      // With no category the fallback still localizes rather than showing EN.
      expect(t.caseTypeLabel(shared), isNot(shared));
    });

    test('leaves a case type the user added alone', () async {
      final t = await translations(const Locale('bn'));
      expect(t.caseTypeLabel('My Own Case Type'), 'My Own Case Type');
    });

    test('localizes the comma-joined step names a case stores', () async {
      final t = await translations(const Locale('bn'));
      final category = seedCategories.firstWhere((c) => c.steps.length > 1);
      final first = category.steps.first;
      final second = category.steps[1];
      expect(
        t.stepNames(
          '${first.labelEn},${second.labelEn}',
          courtCategoryId: category.id,
        ),
        '${first.labelBn},${second.labelBn}',
      );
      // Guard: the labels really change, so the assertion above means something.
      expect(first.labelBn, isNot(first.labelEn));
    });

    test('uses the court category and keeps unknown step names', () async {
      final bn = await translations(const Locale('bn'));
      // "Dismissal" is the one step name shared across categories with
      // different Bengali labels.
      const shared = 'Dismissal';
      final civil = stepLabelBnByCourtCategory[districtCourtsCivilId]?[shared];
      final executive =
          stepLabelBnByCourtCategory[executiveMagistrateId]?[shared];
      expect(civil, isNot(executive));
      expect(
        bn.stepNames(shared, courtCategoryId: districtCourtsCivilId),
        civil,
      );
      expect(
        bn.stepNames(shared, courtCategoryId: executiveMagistrateId),
        executive,
      );
      // A step the user added has no seed label and stays as it was stored.
      expect(bn.stepNames('Arrival,My Own Step'), isNotNull);
      expect(bn.stepNames('My Own Step'), 'My Own Step');
      expect(bn.stepNames(null), isNull);

      // English keeps the stored string exactly as it is.
      final en = await translations(const Locale('en'));
      expect(en.stepNames('Arrival,My Own Step'), 'Arrival,My Own Step');
    });

    test('labels an on-behalf role by its ID', () async {
      final bn = await translations(const Locale('bn'));
      final id = onBehalfLabelEn.keys.first;
      expect(bn.onBehalfLabel(id, onBehalfLabelEn[id]), onBehalfLabelBn[id]);
      // A role the user added keeps its stored name; no role is null.
      expect(bn.onBehalfLabel('custom-role', 'My Client'), 'My Client');
      expect(bn.onBehalfLabel(null, null), isNull);
      expect(bn.onBehalfLabel('onbehalf-gone', null), isNull);
    });
  });
}
