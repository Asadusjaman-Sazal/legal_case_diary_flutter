/// Where a tapped notification lands — one function, three payload kinds.
///
/// A hearing alert's payload is a case id, the admin payment alert carries its
/// own marker, and the pre-expiry subscription reminder carries another. All
/// three are read by the same function, so a reminder that opened a case detail
/// for a case id that does not exist would be a silent, confusing dead end.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/notifications/notification_scheduler.dart';
import 'package:legal_case_diary/core/push/payment_alert_message.dart';
import 'package:legal_case_diary/core/router/app_router.dart';

void main() {
  test('a subscription reminder opens the plans screen', () {
    expect(
      notificationPayloadRoute(subscriptionReminderPayload),
      AppRoutes.paywall,
    );
  });

  test('the two markers cannot be mistaken for one another', () {
    expect(subscriptionReminderPayload, isNot(paymentAlertPayload));
    expect(
      notificationPayloadRoute(paymentAlertPayload),
      AppRoutes.adminPaymentRequests,
    );
  });

  test('a case id still opens that case', () {
    const caseId = '6f1d9a52-2b7c-4e0f-9a4d-5b1f0c3d7e88';
    expect(
      notificationPayloadRoute(caseId),
      AppRoutes.caseDetailPath(caseId),
    );
  });
}
