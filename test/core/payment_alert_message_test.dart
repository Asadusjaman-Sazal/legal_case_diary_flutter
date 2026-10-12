/// The admin payment-alert message: what the sender's payload means, and what
/// the notification says.
///
/// The notification itself is posted through a platform channel that only
/// answers on a device, so the two halves that *can* be checked here are checked
/// here: the payload parse (a message this app does not understand must never
/// clear a line that is still true) and the words — including the count in the
/// active language's own digits, which is the whole reason the sender sends
/// numbers and the device writes the sentence.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/push/payment_alert_message.dart';

void main() {
  group('reading the sender\'s payload', () {
    test('a pending count and the arrival flag are read as sent', () {
      final alert = PaymentAlert.fromData(<String, dynamic>{
        'pending': '10',
        'alert': 'true',
      });

      expect(alert, isNotNull);
      expect(alert!.pending, 10);
      expect(alert.alert, isTrue);
    });

    test('a correction is not an arrival', () {
      expect(
        PaymentAlert.fromData(<String, dynamic>{
          'pending': '3',
          'alert': 'false',
        })!.alert,
        isFalse,
      );
      // A message whose flag is absent is a correction too: the arrival is the
      // one state the sender has to say out loud.
      expect(
        PaymentAlert.fromData(<String, dynamic>{'pending': '3'})!.alert,
        isFalse,
      );
    });

    test('zero is a real count, not a missing one', () {
      expect(
        PaymentAlert.fromData(<String, dynamic>{'pending': '0'})!.pending,
        0,
      );
    });

    test('a payload this app cannot read is ignored, not treated as zero', () {
      // Clearing the tray on a message whose count could not be read would take
      // down a line that is still true.
      expect(PaymentAlert.fromData(const <String, dynamic>{}), isNull);
      expect(
        PaymentAlert.fromData(const <String, dynamic>{'pending': 'many'}),
        isNull,
      );
      expect(
        PaymentAlert.fromData(const <String, dynamic>{'pending': ''}),
        isNull,
      );
    });
  });

  group('the words', () {
    test('one request is a sentence of its own in English', () {
      final notice = buildPaymentAlertNotice(
        const PaymentAlert(pending: 1, alert: true),
        'en',
      );

      expect(notice.title, 'Payment Requests Pending');
      expect(notice.body, 'One payment request is waiting for your approval.');
      expect(notice.alert, isTrue);
    });

    test('a count is written in the language\'s own digits', () {
      final english = buildPaymentAlertNotice(
        const PaymentAlert(pending: 10, alert: false),
        'en',
      );
      final bengali = buildPaymentAlertNotice(
        const PaymentAlert(pending: 10, alert: false),
        'bn',
      );

      expect(english.body, '10 payment requests are waiting for your approval.');
      // The same message, unreadable the same way to anyone who cannot read
      // Latin digits — which is why the server never composes this sentence.
      expect(bengali.body, contains('১০'));
      expect(bengali.body, isNot(contains('10')));
      expect(bengali.title, isNot(english.title));
    });

    test('a one-request alert is Bengali in Bengali, not English', () {
      final notice = buildPaymentAlertNotice(
        const PaymentAlert(pending: 1, alert: true),
        'bn',
      );

      expect(notice.body, contains('একটি'));
    });
  });
}
