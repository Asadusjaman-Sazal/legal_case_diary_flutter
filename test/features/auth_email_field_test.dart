/// The Email box's two additions (user request): the clear cross and the
/// domain window.
///
/// The box itself is the shared auth field, so what is pinned here is only what
/// was asked for: the cross empties the box and puts the keyboard away, the six
/// domains appear in order once a letter has been typed, each row reads as the
/// whole address the tap would produce, they narrow to what has been typed after
/// the `@`, a chosen domain is attached with no space, the window always hangs
/// under the box (scrolling the page up when the keyboard leaves too little
/// room), and it closes on a tap outside or an empty box — but not on a keystroke,
/// a tap inside it, or a press that travels (a scroll). A drag that starts on the
/// window scrolls the page under it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_widgets.dart';

void main() {
  /// The key one domain's row carries.
  Key row(String domain) => ValueKey('auth-email-domain-$domain');

  /// The window itself, by its own key.
  final window = find.byKey(const ValueKey('auth-email-domains'));

  /// The clear cross.
  final cross = find.byKey(const ValueKey('auth-email-clear'));

  /// Pumps a bare Email box and returns its controller.
  Future<TextEditingController> pumpBox(WidgetTester tester) async {
    // A tall phone: MediaQuery must see the same size the widgets are laid out
    // in, which is the view's size rather than the binding's surface size.
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AuthEmailField(
              controller: controller,
              label: 'Email',
              hint: 'example@gmail.com',
            ),
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets('the cross appears with text and empties the box, keyboard too', (
    tester,
  ) async {
    final controller = await pumpBox(tester);

    // Nothing to clear yet, so no cross.
    expect(cross, findsNothing);

    await tester.enterText(find.byType(TextFormField), 'counsel');
    await tester.pump();
    expect(cross, findsOneWidget);
    expect(controller.text, 'counsel');
    // Typing put the focus (and the keyboard) in the box.
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    await tester.tap(cross);
    await tester.pumpAndSettle();

    expect(controller.text, isEmpty);
    // Cleared by the cross, the box lets the keyboard go (user request).
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
    expect(cross, findsNothing);
    expect(window, findsNothing);
  });

  testWidgets('one letter offers the six domains, in the order given', (
    tester,
  ) async {
    await pumpBox(tester);

    await tester.enterText(find.byType(TextFormField), 'john');
    await tester.pumpAndSettle();

    expect(window, findsOneWidget);
    var previous = double.negativeInfinity;
    for (final domain in emailDomainSuggestions) {
      expect(find.byKey(row(domain)), findsOneWidget, reason: domain);
      // The list reads top to bottom in the order it is written.
      final top = tester.getTopLeft(find.byKey(row(domain))).dy;
      expect(top, greaterThan(previous), reason: domain);
      previous = top;
    }
    // Nothing else is offered.
    expect(find.text('@icloud.com'), findsNothing);
  });

  testWidgets('the list hangs under the box in the app pop-over shape', (
    tester,
  ) async {
    await pumpBox(tester);

    await tester.enterText(find.byType(TextFormField), 'john');
    await tester.pumpAndSettle();

    final box = tester.getRect(find.byType(TextFormField));
    final panel = tester.getRect(window);
    // Under the box, as wide as it, and not over it.
    expect(panel.top, greaterThan(box.bottom));
    expect(panel.left, box.left);
    expect(panel.width, box.width);

    // The rounded window the account popover draws: 16 px corners, an 8 px
    // lift and the hairline divider edge.
    final material = tester.widget<Material>(window);
    expect(material.elevation, 8);
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.side.color, AppColors.outlineVariant);
    expect((shape.borderRadius as BorderRadius).topLeft.x, 16);
  });

  testWidgets('a bare number is not a letter, so it offers nothing', (
    tester,
  ) async {
    await pumpBox(tester);

    await tester.enterText(find.byType(TextFormField), '123');
    await tester.pumpAndSettle();

    expect(window, findsNothing);
  });

  testWidgets('what is typed after @ narrows the list', (tester) async {
    await pumpBox(tester);

    await tester.enterText(find.byType(TextFormField), 'john@g');
    await tester.pumpAndSettle();

    expect(find.byKey(row('@gmail.com')), findsOneWidget);
    expect(find.byKey(row('@yahoo.com')), findsNothing);
    expect(find.byKey(row('@proton.me')), findsNothing);

    // `@p` leaves the two proton addresses.
    await tester.enterText(find.byType(TextFormField), 'john@p');
    await tester.pumpAndSettle();
    expect(find.byKey(row('@protonmail.com')), findsOneWidget);
    expect(find.byKey(row('@proton.me')), findsOneWidget);
    expect(find.byKey(row('@gmail.com')), findsNothing);
  });

  testWidgets('a chosen domain is attached with no space and closes the list', (
    tester,
  ) async {
    final controller = await pumpBox(tester);

    await tester.enterText(find.byType(TextFormField), 'john');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(row('@yahoo.com')));
    await tester.pumpAndSettle();

    expect(controller.text, 'john@yahoo.com');
    expect(window, findsNothing);
    // A domain is a step in typing: the box keeps the keyboard.
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('a half-typed domain is replaced by the chosen one', (
    tester,
  ) async {
    final controller = await pumpBox(tester);

    await tester.enterText(find.byType(TextFormField), 'john@g');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(row('@gmail.com')));
    await tester.pumpAndSettle();

    // One domain, not two.
    expect(controller.text, 'john@gmail.com');
    expect(window, findsNothing);
  });

  testWidgets('tapping outside closes the list; typing brings it back', (
    tester,
  ) async {
    await pumpBox(tester);

    await tester.enterText(find.byType(TextFormField), 'john');
    await tester.pumpAndSettle();
    expect(window, findsOneWidget);

    // The page around the box is outside both it and the window.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(window, findsNothing);

    // The text is untouched, and the next keystroke offers the list again.
    await tester.enterText(find.byType(TextFormField), 'johns');
    await tester.pumpAndSettle();
    expect(window, findsOneWidget);
  });

  testWidgets('a tap inside the window is not an outside tap', (tester) async {
    await pumpBox(tester);

    await tester.enterText(find.byType(TextFormField), 'john');
    await tester.pumpAndSettle();

    // Pressing in the window's padding — not on a row — leaves it up.
    final windowBox = tester.getRect(window);
    await tester.tapAt(windowBox.topCenter + const Offset(0, 1));
    await tester.pumpAndSettle();

    expect(window, findsOneWidget);
  });

  testWidgets('emptying the box by hand takes the list away', (tester) async {
    await pumpBox(tester);

    await tester.enterText(find.byType(TextFormField), 'john');
    await tester.pumpAndSettle();
    expect(window, findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '');
    await tester.pumpAndSettle();

    expect(window, findsNothing);
  });

  testWidgets('each row shows the address the tap would produce', (
    tester,
  ) async {
    await pumpBox(tester);

    await tester.enterText(find.byType(TextFormField), 'john');
    await tester.pumpAndSettle();

    // The typed name, then the domain — the whole address, not just the tail.
    expect(find.text('john@gmail.com'), findsOneWidget);
    expect(find.text('john@yahoo.com'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'john@g');
    await tester.pumpAndSettle();

    expect(find.text('john@gmail.com'), findsOneWidget);
    expect(find.text('john@yahoo.com'), findsNothing);
  });

  testWidgets('holding and scrolling outside keeps the window; a tap closes it', (
    tester,
  ) async {
    await pumpBox(tester);

    await tester.enterText(find.byType(TextFormField), 'john');
    await tester.pumpAndSettle();
    expect(window, findsOneWidget);

    // A press outside that travels: a scroll of the page, not a tap.
    await tester.dragFrom(const Offset(8, 400), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(window, findsOneWidget);

    // The same place, tapped without travelling, closes it.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(window, findsNothing);
  });

  testWidgets('the page scrolls up to keep the window under the box', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 200),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AuthEmailField(
                    controller: controller,
                    label: 'Email',
                    hint: 'example@gmail.com',
                  ),
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'john');
    await tester.pumpAndSettle();

    final box = tester.getRect(find.byType(TextFormField));
    final panel = tester.getRect(window);
    // Under the box as always, and inside the room the keyboard leaves: the
    // box moved up to give it that room.
    expect(panel.top, greaterThan(box.bottom));
    expect(panel.bottom, lessThanOrEqualTo(341));
    expect(box.top, lessThan(200));
  });

  testWidgets('dragging the window scrolls the screen', (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                const SizedBox(height: 100),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AuthEmailField(
                    controller: controller,
                    label: 'Email',
                    hint: 'example@gmail.com',
                  ),
                ),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'john');
    await tester.pumpAndSettle();
    expect(window, findsOneWidget);
    expect(scroll.offset, 0);

    // Holding the window and moving the finger scrolls the page under it; the
    // window stays attached to the box and stays open.
    await tester.drag(window, const Offset(0, -140));
    await tester.pumpAndSettle();

    expect(scroll.offset, greaterThan(80));
    expect(window, findsOneWidget);
  });
}
