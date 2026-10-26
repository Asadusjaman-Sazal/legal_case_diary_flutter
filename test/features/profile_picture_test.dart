/// Tests for the locally persisted profile picture (Task 12 Part A).
///
/// Verifies the picture path survives through [SharedPreferences], that the
/// store ignores stale paths, and that both the Profile and Manage Account
/// screens render the same saved picture.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_picture_store.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/manage_account_screen.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/profile_screen.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal valid 1x1 PNG so `FileImage` decodes without errors in tests.
final List<int> _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/'
  'q842iQAAAABJRU5ErkJggg==',
);

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;
  late AppDatabase db;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('profile_picture_test');
  });

  tearDown(() async {
    await db.close();
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
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Manage Account reads the account's cached profile (Task 17 Phase 3).
      databaseProvider.overrideWith((_) async => db),
    ],
    child: MaterialApp(
      // The screens read their labels from AppLocalizations.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  );

  test('store returns the saved picture and ignores a missing file', () async {
    final store = ProfilePictureStore(prefs);
    expect(store.current(), isNull);

    final picture = writePicture('saved.png');
    await prefs.setString(profilePicturePathKey, picture.path);
    expect(store.current()?.path, picture.path);

    await picture.delete();
    expect(store.current(), isNull);
  });

  test('clear removes the saved file and the stored path', () async {
    final picture = writePicture('cleared.png');
    await prefs.setString(profilePicturePathKey, picture.path);

    await ProfilePictureStore(prefs).clear();

    expect(picture.existsSync(), isFalse);
    expect(prefs.getString(profilePicturePathKey), isNull);
  });

  testWidgets('Profile screen renders the saved profile picture', (
    tester,
  ) async {
    final picture = writePicture('profile.png');
    await prefs.setString(profilePicturePathKey, picture.path);

    await tester.pumpWidget(app(const ProfileScreen()));
    await tester.pumpAndSettle();

    expect(_avatarPaths(tester), contains(picture.path));
  });

  testWidgets('the picture opens its viewer, which can delete it', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final picture = writePicture('viewer.png');
    await prefs.setString(profilePicturePathKey, picture.path);

    await tester.pumpWidget(app(const ProfileScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-picture-open')));
    await tester.pumpAndSettle();

    expect(find.text(l.profilePicture_title), findsOneWidget);
    expect(find.byTooltip(l.sharedActions_delete), findsOneWidget);
    expect(find.byTooltip(l.sharedActions_edit), findsOneWidget);

    await tester.tap(find.byTooltip(l.sharedActions_delete));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();

    // The viewer closes on delete; the file and the avatar are gone.
    expect(find.text(l.profilePicture_title), findsNothing);
    expect(picture.existsSync(), isFalse);
    expect(_avatarPaths(tester), isEmpty);
  });

  testWidgets('Manage Account shows the same picture as the Profile screen', (
    tester,
  ) async {
    final picture = writePicture('shared.png');
    await prefs.setString(profilePicturePathKey, picture.path);

    await tester.pumpWidget(app(const ProfileScreen()));
    await tester.pumpAndSettle();
    expect(_avatarPaths(tester), contains(picture.path));

    await tester.pumpWidget(app(const ManageAccountScreen()));
    await tester.pumpAndSettle();
    expect(_avatarPaths(tester), contains(picture.path));
  });

  testWidgets('Manage Account falls back to initials without a picture', (
    tester,
  ) async {
    // Task 17 Phase 3: the screen shows the user's own saved name now, not the
    // mockup's sample one, so the initial comes from the saved record.
    await prefs.setString(
      profileFieldsKey,
      jsonEncode(const ProfileFields(fullName: 'Adv. Rahim').toJson()),
    );

    await tester.pumpWidget(app(const ManageAccountScreen()));
    await tester.pumpAndSettle();

    expect(_avatarPaths(tester), isEmpty);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Adv. Rahim'), findsOneWidget);
  });

  testWidgets('Manage Account shows a blank account as dashes', (tester) async {
    await tester.pumpWidget(app(const ManageAccountScreen()));
    await tester.pumpAndSettle();

    // Nobody signed in and no name saved: the avatar asks, the card dashes.
    expect(find.text('?'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
  });
}

/// File paths of every avatar picture rendered as a [DecorationImage].
List<String> _avatarPaths(WidgetTester tester) {
  final paths = <String>[];
  for (final container in tester.widgetList<Container>(
    find.byType(Container),
  )) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration) {
      final image = decoration.image?.image;
      if (image is FileImage) paths.add(image.file.path);
    }
  }
  return paths;
}
