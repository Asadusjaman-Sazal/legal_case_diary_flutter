/// Tests for the shared profile record and its use in the drawer header.
///
/// Covers the locally persisted record ([ProfileFieldsNotifier]), the blank
/// profile every new install starts with, the Profile screen saving the whole
/// record, and the navigation drawer header rendering the saved picture plus
/// full name.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_picture_store.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/profile_screen.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/shared/widgets/app_navigation_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal valid 1x1 PNG so `FileImage` decodes without errors in tests.
final List<int> _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/'
  'q842iQAAAABJRU5ErkJggg==',
);

/// The mockup sample values, which must never be seeded into a real install.
const List<String> _mockupSampleValues = <String>[
  'Asadusjaman',
  'Dhaka Bar Association',
  '1557',
  'Chamber 402, High Court Annex, Dhaka-1000',
  '1812332721',
];

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    tempDir = await Directory.systemTemp.createTemp('profile_name_test');
  });

  tearDown(() async {
    // Drop decoded images before removing the files (Windows file locks).
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  File writePicture(String name) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(_pngBytes);
    return file;
  }

  Widget app(Widget child) => ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  );

  /// A container over the same preferences, as a fresh app launch sees them.
  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a new install starts with a blank profile and no stored record', () {
    final c = container();

    expect(c.read(profileFieldsProvider), ProfileFields.blank);
    expect(c.read(profileNameProvider), isEmpty);
    expect(prefs.getString(profileFieldsKey), isNull);
  });

  test('the record persists trimmed and ignores unchanged saves', () async {
    final c = container();
    await c
        .read(profileFieldsProvider.notifier)
        .save(
          const ProfileFields(
            fullName: '  Rahim Uddin ',
            barAssociation: ' Dhaka Bar Association ',
            mobile: ' 1812332721 ',
          ),
        );

    expect(c.read(profileNameProvider), 'Rahim Uddin');
    expect(prefs.getString(profileFullNameKey), isNull);
    final stored = ProfileFields.fromJson(
      jsonDecode(prefs.getString(profileFieldsKey)!) as Map<String, dynamic>,
    );
    expect(stored.barAssociation, 'Dhaka Bar Association');
    expect(stored.mobile, '1812332721');
    expect(stored.membershipNo, isEmpty);

    // A fresh container (app restart) reads the persisted record.
    final restarted = container();
    expect(restarted.read(profileFieldsProvider).fullName, 'Rahim Uddin');
    expect(restarted.read(profileFieldsProvider).barAssociation,
        'Dhaka Bar Association');
  });

  test('an install that saved only a name keeps it', () async {
    await prefs.setString(profileFullNameKey, 'Rahim Uddin');

    final c = container();
    expect(c.read(profileFieldsProvider).fullName, 'Rahim Uddin');

    // Saving the record folds the legacy key into it.
    await c
        .read(profileFieldsProvider.notifier)
        .save(c.read(profileFieldsProvider).copyWith(mobile: '1812332721'));
    expect(prefs.getString(profileFullNameKey), isNull);
    expect(container().read(profileFieldsProvider).fullName, 'Rahim Uddin');
  });

  testWidgets('Profile screen shows an empty profile on a fresh install', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(const ProfileScreen()));
    await tester.pumpAndSettle();

    // The mockups' sample values are placeholders, never a new user's data.
    for (final sample in _mockupSampleValues) {
      expect(find.text(sample), findsNothing, reason: sample);
      expect(find.textContaining(sample), findsNothing, reason: sample);
    }
    expect(find.text('Your Name'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(5));
  });

  testWidgets('Profile screen saves and reopens the whole record', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(const ProfileScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit Profile'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your full name'),
      'Rahim Uddin',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter bar association name'),
      'Dhaka Bar Association',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter registration number'),
      '1557',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '01XXXXXXXXX'),
      '01812332721',
    );
    await tester.tap(find.text('Save Profile'));
    await tester.pumpAndSettle();

    // Persisted for the rest of the app and shown in the read view immediately.
    final stored = ProfileFields.fromJson(
      jsonDecode(prefs.getString(profileFieldsKey)!) as Map<String, dynamic>,
    );
    expect(stored.fullName, 'Rahim Uddin');
    expect(stored.barAssociation, 'Dhaka Bar Association');
    expect(stored.membershipNo, '1557');
    expect(stored.mobile, '01812332721');
    // The header shows the saved name exactly, with no honorific added; the
    // Full Name row below shows the same text.
    expect(find.text('Rahim Uddin'), findsNWidgets(2));
    expect(find.text('Dhaka Bar Association'), findsOneWidget);
    // The read view wears the same `+88` country code the editor's fixed box
    // carries, with the local number (leading 0) the user typed beside it.
    expect(find.text('+88 01812332721'), findsOneWidget);

    // Reopening the editor shows the saved values.
    await tester.tap(find.byTooltip('Edit Profile'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextFormField, 'Rahim Uddin'),
      findsOneWidget,
    );
  });

  testWidgets('the edit form scrolls clear of the keyboard', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(const ProfileScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit Profile'));
    await tester.pumpAndSettle();

    // The keyboard covers the bottom third. The form must scroll above it
    // instead of overflowing (the "Bottom overflowed by N pixels" bug).
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });

  testWidgets('drawer header shows the saved picture and full name', (
    tester,
  ) async {
    final picture = writePicture('drawer.png');
    await prefs.setString(profilePicturePathKey, picture.path);
    await ProfileStore(prefs).write(const ProfileFields(fullName: 'Rahim Uddin'));

    await tester.pumpWidget(app(_drawerHost()));
    await _openDrawer(tester);

    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Rahim Uddin'),
      ),
      findsOneWidget,
    );
    expect(_drawerAvatarPaths(tester), contains(picture.path));
  });

  testWidgets('drawer header falls back to the person icon and saved name', (
    tester,
  ) async {
    await ProfileStore(prefs).write(const ProfileFields(fullName: 'Rahim Uddin'));

    await tester.pumpWidget(app(_drawerHost()));
    await _openDrawer(tester);

    expect(_drawerAvatarPaths(tester), isEmpty);
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.person_outline),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Rahim Uddin'),
      ),
      findsOneWidget,
    );
  });
}

/// Scaffold hosting the app drawer, mirroring how the case screens mount it.
Widget _drawerHost() => Scaffold(
  drawer: const AppNavigationDrawer(currentRoute: '/all-cases'),
  body: const SizedBox.shrink(),
);

/// Opens the hosted drawer and settles its animation.
Future<void> _openDrawer(WidgetTester tester) async {
  tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
  await tester.pumpAndSettle();
}

/// File paths of every drawer avatar picture rendered as a [CircleAvatar].
List<String> _drawerAvatarPaths(WidgetTester tester) {
  final paths = <String>[];
  for (final avatar in tester.widgetList<CircleAvatar>(
    find.descendant(of: find.byType(Drawer), matching: find.byType(CircleAvatar)),
  )) {
    final image = avatar.backgroundImage;
    if (image is FileImage) paths.add(image.file.path);
  }
  return paths;
}
