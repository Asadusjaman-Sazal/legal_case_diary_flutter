/// The shared pop-over frame and its adaptive action row.
///
/// Pins the standard corner (8 px), the elastic 294–420 px width, the 85 %
/// height cap, the 112 x 48 / 16 pt actions with a 12 px gap, and the pair
/// rule: one centred line while both fit, two full-width buttons when they do
/// not. The same actions and handlers are the caller's.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/theme/app_dialog_metrics.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/shared/widgets/app_dialog.dart';
import 'package:legal_case_diary/shared/widgets/app_dialog_actions.dart';

const Key _openKey = ValueKey('open-dialog');

/// The visible window card, not the route-sized box around it.
Finder _card() => find
    .descendant(
      of: find.byType(AlertDialog),
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.type == MaterialType.card,
      ),
    )
    .first;

void main() {
  /// Pumps a host with a button that opens [showAppDialog].
  Future<bool?> Function()? lastOpen;

  Future<void> pumpHost(
    WidgetTester tester, {
    required Size surface,
    required Widget title,
    Widget? content,
    required List<AppDialogAction> Function(BuildContext) actions,
    AppDialogActionMode mode = AppDialogActionMode.pair,
    double textScale = 1.0,
    EdgeInsets? insetPadding,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(const Locale('en')),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            key: _openKey,
            onPressed: () async {
              result = await showAppDialog<bool>(
                context,
                title: title,
                content: content,
                actions: actions,
                actionMode: mode,
                insetPadding: insetPadding,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    lastOpen = () async => result;
  }

  /// Two short actions that fit a 412 px phone.
  List<AppDialogAction> shortPair(BuildContext context) => [
    AppDialogAction(
      label: 'No',
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppDialogAction(
      label: 'Yes',
      kind: AppDialogActionKind.primary,
      onPressed: () => Navigator.of(context).pop(true),
    ),
  ];

  /// The Exit window's pair, which needs 236 px and so stacks at 360.
  List<AppDialogAction> longPair(BuildContext context) => [
    AppDialogAction(
      label: 'Cancel',
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppDialogAction(
      label: 'Exit',
      onPressed: () => Navigator.of(context).pop(true),
    ),
  ];

  testWidgets('the frame is 8 px, elastic 294-420, with standard actions', (
    tester,
  ) async {
    await pumpHost(
      tester,
      surface: const Size(412, 800),
      title: const Text('Exit App?'),
      content: const Text('Do you want to exit Legal Case Diary?'),
      actions: longPair,
    );

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    final corner =
        (dialog.shape! as RoundedRectangleBorder).borderRadius as BorderRadius;
    expect(corner.topLeft.x, 8);

    final width = tester.getSize(_card()).width;
    expect(width, greaterThanOrEqualTo(294));
    expect(width, lessThanOrEqualTo(420));

    // Cancel and Exit fit a 412 px phone: one centred line, 12 px apart.
    final cancel = find.widgetWithText(TextButton, 'Cancel');
    final exit = find.widgetWithText(TextButton, 'Exit');
    expect(tester.getRect(exit).top, closeTo(tester.getRect(cancel).top, 0.5));
    expect(
      tester.getRect(exit).left - tester.getRect(cancel).right,
      closeTo(12, 0.5),
    );

    // The Exit window's action style: 112 x 48 at 16 pt.
    final style = tester.widget<TextButton>(cancel).style!;
    expect(style.minimumSize!.resolve(<WidgetState>{}), const Size(112, 48));
    expect(style.textStyle!.resolve(<WidgetState>{})!.fontSize, 16);
  });

  testWidgets('at 360 px the margins narrow so the pair shares one line', (
    tester,
  ) async {
    await pumpHost(
      tester,
      surface: const Size(360, 800),
      title: const Text('Exit App?'),
      content: const Text('Do you want to exit Legal Case Diary?'),
      actions: longPair,
    );

    final cancel = find.widgetWithText(TextButton, 'Cancel');
    final exit = find.widgetWithText(TextButton, 'Exit');
    expect(tester.getRect(exit).top, closeTo(tester.getRect(cancel).top, 0.5));
    expect(
      tester.getRect(exit).left - tester.getRect(cancel).right,
      closeTo(12, 0.5),
    );
    // The 40 px margins would leave a 280 px window; they narrow just enough.
    final left = tester.getRect(_card()).left;
    expect(left, lessThan(40));
    expect(left, greaterThanOrEqualTo(AppDialogMetrics.minInset));
  });

  testWidgets('a pair still too wide at 320 px keeps the margins and stacks', (
    tester,
  ) async {
    await pumpHost(
      tester,
      surface: const Size(320, 800),
      title: const Text('Exit App?'),
      content: const Text('Do you want to exit Legal Case Diary?'),
      actions: longPair,
    );

    final cancel = find.widgetWithText(TextButton, 'Cancel');
    final exit = find.widgetWithText(TextButton, 'Exit');
    expect(tester.getRect(exit).top, greaterThan(tester.getRect(cancel).top));
    expect(
      tester.getSize(cancel).width,
      closeTo(tester.getSize(exit).width, 0.5),
    );
    expect(
      tester.getSize(cancel).width,
      closeTo(tester.getSize(_card()).width - 48, 0.5),
    );
    // Narrowing could not have made it fit, so the standard margin stays.
    expect(tester.getRect(_card()).left, closeTo(40, 0.5));
  });

  testWidgets('a long title grows the window no wider than 420', (
    tester,
  ) async {
    await pumpHost(
      tester,
      surface: const Size(800, 800),
      title: const Text(
        'This title is far longer than any phone window should ever grow, '
        'because the shared frame stops at four hundred and twenty pixels',
      ),
      actions: (context) => [
        AppDialogAction(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );

    expect(tester.getSize(_card()).width, closeTo(420, 1));
  });

  testWidgets('a pair that fits stays on one centred line with a 12 px gap', (
    tester,
  ) async {
    await pumpHost(
      tester,
      surface: const Size(412, 800),
      title: const Text('Delete this note?'),
      actions: shortPair,
    );

    final cancel = tester.getRect(find.widgetWithText(TextButton, 'No'));
    final confirm = tester.getRect(find.widgetWithText(FilledButton, 'Yes'));
    expect(confirm.top, closeTo(cancel.top, 0.5));
    expect(confirm.left - cancel.right, closeTo(12, 0.5));
    // Centred inside the window.
    final dialog = tester.getRect(find.byType(AlertDialog));
    final leftGap = cancel.left - dialog.left;
    final rightGap = dialog.right - confirm.right;
    expect(leftGap, closeTo(rightGap, 1));
  });

  testWidgets('the destructive action keeps the app red', (tester) async {
    await pumpHost(
      tester,
      surface: const Size(412, 800),
      title: const Text('Delete this note?'),
      actions: (context) => [
        AppDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppDialogAction(
          label: 'Delete',
          kind: AppDialogActionKind.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );

    final delete = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete'),
    );
    expect(
      delete.style!.backgroundColor!.resolve(<WidgetState>{}),
      AppColors.error,
    );
  });

  testWidgets('a tall body is capped and scrolls', (tester) async {
    await pumpHost(
      tester,
      surface: const Size(360, 400),
      title: const Text('Long window'),
      content: const SizedBox(height: 1000, child: Text('Body')),
      actions: (context) => [
        AppDialogAction(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );

    // 85 % of the height left after the 24 px vertical inset.
    final height = tester.getSize(_card()).height;
    expect(height, lessThanOrEqualTo((400 - 48) * 0.85 + 0.5));
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });

  testWidgets('three actions keep their own grouping', (tester) async {
    await pumpHost(
      tester,
      surface: const Size(412, 800),
      title: const Text('Invite Code'),
      actions: (context) => [
        AppDialogAction(
          label: 'Copy',
          kind: AppDialogActionKind.outlined,
          onPressed: () {},
        ),
        AppDialogAction(
          label: 'Share',
          kind: AppDialogActionKind.outlined,
          onPressed: () {},
        ),
        AppDialogAction(
          label: 'Close',
          kind: AppDialogActionKind.primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      mode: AppDialogActionMode.wrap,
    );

    final copy = tester.getRect(find.widgetWithText(OutlinedButton, 'Copy'));
    final share = tester.getRect(find.widgetWithText(OutlinedButton, 'Share'));
    final close = tester.getRect(find.widgetWithText(FilledButton, 'Close'));
    expect(share.top, closeTo(copy.top, 0.5));
    expect(close.top, greaterThan(copy.bottom));
  });

  testWidgets('actions return their answer and keep their handlers', (
    tester,
  ) async {
    await pumpHost(
      tester,
      surface: const Size(412, 800),
      title: const Text('Delete this note?'),
      actions: shortPair,
    );

    await tester.tap(find.widgetWithText(TextButton, 'No'));
    await tester.pumpAndSettle();
    expect(await lastOpen!(), isFalse);

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Yes'));
    await tester.pumpAndSettle();
    expect(await lastOpen!(), isTrue);
  });

  testWidgets('a long label at a large text step goes full width', (
    tester,
  ) async {
    await pumpHost(
      tester,
      surface: const Size(412, 800),
      title: const Text('Withdraw This Deletion Request?'),
      actions: (context) => [
        AppDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppDialogAction(
          label: 'Withdraw Request',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      textScale: 2.0,
    );

    final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
    final withdraw = tester.getRect(
      find.widgetWithText(TextButton, 'Withdraw Request'),
    );
    // Twice the text cannot fit a row: both are full width, one under the other.
    expect(withdraw.top, greaterThan(cancel.top));
    expect(withdraw.width, closeTo(cancel.width, 0.5));
    expect(tester.takeException(), isNull);
  });
}
