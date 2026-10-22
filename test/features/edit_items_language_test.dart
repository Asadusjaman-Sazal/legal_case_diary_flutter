/// Seeded case types, steps and on-behalfs are stored in English. The lists
/// under Settings → Edit Court/Steps must still follow the active language,
/// exactly like the court list does. User-added rows keep their own name.
library;

import 'package:flutter/material.dart' hide Step;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/settings/data/case_types_repository.dart';
import 'package:legal_case_diary/features/settings/data/on_behalfs_repository.dart';
import 'package:legal_case_diary/features/settings/data/reference_in_use_checker.dart';
import 'package:legal_case_diary/features/settings/data/steps_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/edit_court_steps/item_list_screen.dart';

/// The seeded category used by every case below.
final _category = seedCategories.firstWhere(
  (category) => category.id == districtCourtsCivilId,
);

const _customCaseType = CaseType(
  id: 'custom-case-type',
  courtCategoryId: districtCourtsCivilId,
  name: 'My Own Type',
  orderIndex: 99,
  isCustom: true,
  isUserModified: false,
  updatedAt: 0,
  isDeleted: false,
);

const _customStep = Step(
  id: 'custom-step',
  courtCategoryId: districtCourtsCivilId,
  stepName: 'My Own Step',
  orderIndex: 99,
  isCustom: true,
  isUserModified: false,
  updatedAt: 0,
  isDeleted: false,
);

const _customOnBehalf = OnBehalf(
  id: 'custom-on-behalf',
  courtCategoryId: districtCourtsCivilId,
  name: 'My Own Role',
  orderIndex: 99,
  isCustom: true,
  isUserModified: false,
  updatedAt: 0,
  isDeleted: false,
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget screen,
    List<Override> overrides,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          referenceInUseProvider.overrideWith(
            (ref) => Stream.value(ReferenceInUse.none),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('bn'),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('seeded case types show their Bengali label', (tester) async {
    final seed = _category.allCaseTypes.first;
    await pump(
      tester,
      const ItemListScreen(
        kind: ItemKind.caseTypes,
        categoryId: districtCourtsCivilId,
      ),
      [
        caseTypesRepositoryProvider.overrideWith(
          (ref) async => _FakeCaseTypesRepository([
            CaseType(
              id: seed.id,
              courtCategoryId: districtCourtsCivilId,
              caseCategoryId: seed.caseCategoryId,
              name: seed.labelEn,
              orderIndex: 0,
              isCustom: false,
              isUserModified: false,
              updatedAt: 0,
              isDeleted: false,
            ),
            _customCaseType,
          ]),
        ),
      ],
    );

    expect(find.text(caseTypeLabelBn[seed.id]!), findsOneWidget);
    expect(find.text(seed.labelEn), findsNothing);
    expect(find.text(_customCaseType.name), findsOneWidget);
    // Only the user-added row offers Delete.
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('seeded steps show their Bengali label', (tester) async {
    final seed = _category.steps.first;
    await pump(
      tester,
      const ItemListScreen(
        kind: ItemKind.steps,
        categoryId: districtCourtsCivilId,
      ),
      [
        stepsRepositoryProvider.overrideWith(
          (ref) async => _FakeStepsRepository([
            Step(
              id: seed.id,
              courtCategoryId: districtCourtsCivilId,
              stepName: seed.labelEn,
              orderIndex: 0,
              isCustom: false,
              isUserModified: false,
              updatedAt: 0,
              isDeleted: false,
            ),
            _customStep,
          ]),
        ),
      ],
    );

    expect(find.text(stepLabelBn[seed.id]!), findsOneWidget);
    expect(find.text(seed.labelEn), findsNothing);
    expect(find.text(_customStep.stepName), findsOneWidget);
    // Only the user-added row offers Delete.
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('seeded on-behalfs show their Bengali label', (tester) async {
    final seed = _category.onBehalfs.first;
    await pump(
      tester,
      const ItemListScreen(
        kind: ItemKind.onBehalf,
        categoryId: districtCourtsCivilId,
      ),
      [
        onBehalfsRepositoryProvider.overrideWith(
          (ref) async => _FakeOnBehalfsRepository([
            OnBehalf(
              id: seed.id,
              courtCategoryId: districtCourtsCivilId,
              name: seed.labelEn,
              orderIndex: 0,
              isCustom: false,
              isUserModified: false,
              updatedAt: 0,
              isDeleted: false,
            ),
            _customOnBehalf,
          ]),
        ),
      ],
    );

    expect(find.text(onBehalfLabelBn[seed.id]!), findsOneWidget);
    expect(find.text(seed.labelEn), findsNothing);
    expect(find.text(_customOnBehalf.name), findsOneWidget);
    // Only the user-added row offers Delete.
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('the Delete Item window is centred and Delete is red', (
    tester,
  ) async {
    final seed = _category.allCaseTypes.first;
    await pump(
      tester,
      const ItemListScreen(
        kind: ItemKind.caseTypes,
        categoryId: districtCourtsCivilId,
      ),
      [
        caseTypesRepositoryProvider.overrideWith(
          (ref) async => _FakeCaseTypesRepository([
            CaseType(
              id: seed.id,
              courtCategoryId: districtCourtsCivilId,
              caseCategoryId: seed.caseCategoryId,
              name: seed.labelEn,
              orderIndex: 0,
              isCustom: false,
              isUserModified: false,
              updatedAt: 0,
              isDeleted: false,
            ),
            _customCaseType,
          ]),
        ),
      ],
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.actionsAlignment, MainAxisAlignment.center);
    expect((dialog.title! as Text).textAlign, TextAlign.center);

    // The Exit App window's action size: 112x48 at 16 pt.
    final cancel = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      ),
    );
    expect(
      cancel.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size(112, 48),
    );
    expect(cancel.style?.textStyle?.resolve(<WidgetState>{})?.fontSize, 16);

    final delete = tester.widget<FilledButton>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      delete.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size(112, 48),
    );
    expect(
      delete.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.error,
    );
    expect(
      delete.style?.foregroundColor?.resolve(<WidgetState>{}),
      Colors.white,
    );
  });
}

class _FakeCaseTypesRepository implements CaseTypesRepository {
  _FakeCaseTypesRepository(this._items);
  final List<CaseType> _items;

  @override
  Stream<List<CaseType>> watchByCategory(String categoryId) => Stream.value(
    _items.where((item) => item.courtCategoryId == categoryId).toList(),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStepsRepository implements StepsRepository {
  _FakeStepsRepository(this._items);
  final List<Step> _items;

  @override
  Stream<List<Step>> watchByCategory(String categoryId) => Stream.value(
    _items.where((item) => item.courtCategoryId == categoryId).toList(),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOnBehalfsRepository implements OnBehalfsRepository {
  _FakeOnBehalfsRepository(this._items);
  final List<OnBehalf> _items;

  @override
  Stream<List<OnBehalf>> watchByCategory(String categoryId) => Stream.value(
    _items.where((item) => item.courtCategoryId == categoryId).toList(),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
