/// Tests for the shared profile Full Name and its use in the drawer header.
///
/// Covers the locally persisted name ([ProfileNameNotifier]), the Profile
/// screen saving it, and the navigation drawer header showing the saved picture
/// plus that name.
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

  test('name notifier defaults, persists, and ignores unchanged values',
      () async {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(profileNameProvider), defaultProfileFullName);

    await container.read(profileNameProvider.notifier).setName('  Rahim Uddin ');
    expect(container.read(profileNameProvider), 'Rahim Uddin');
    expect(prefs.getString(profileFullNameKey), 'Rahim Uddin');

    // A fresh container (app restart) reads the persisted name.
    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);
    expect(restarted.read(profileNameProvider), 'Rahim Uddin');
  });

  testWidgets('Profile screen saves the Full Name into the shared store',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(const ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Adv. $defaultProfileFullName'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, defaultProfileFullName),
      'Rahim Uddin',
    );
    await tester.tap(find.text('Save Profile'));
    await tester.pumpAndSettle();

    // Persisted for the rest of the app (drawer header) and shown in the read
    // view immediately.
    expect(prefs.getString(profileFullNameKey), 'Rahim Uddin');
    expect(find.text('Adv. Rahim Uddin'), findsOneWidget);
  });

  testWidgets('drawer header shows the saved picture and full name',
      (tester) async {
    final picture = writePicture('drawer.png');
    await prefs.setString(profilePicturePathKey, picture.path);
    await prefs.setString(profileFullNameKey, 'Rahim Uddin');

    await tester.pumpWidget(app(_drawerHost()));
    await _openDrawer(tester);

    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Rahim Uddin')),
      findsOneWidget,
    );
    expect(_drawerAvatarPaths(tester), contains(picture.path));
  });

  testWidgets('drawer header falls back to the person icon and saved name',
      (tester) async {
    await prefs.setString(profileFullNameKey, 'Rahim Uddin');

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
      find.descendant(of: find.byType(Drawer), matching: find.text('Rahim Uddin')),
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
