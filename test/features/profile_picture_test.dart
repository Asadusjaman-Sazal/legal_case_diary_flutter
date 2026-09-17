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
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_picture_store.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/manage_account_screen.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/profile_screen.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
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
    tempDir = await Directory.systemTemp.createTemp('profile_picture_test');
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
    await tester.pumpWidget(app(const ManageAccountScreen()));
    await tester.pumpAndSettle();

    expect(_avatarPaths(tester), isEmpty);
    expect(find.text('A'), findsOneWidget);
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
