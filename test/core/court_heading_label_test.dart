import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/l10n/app_translations.dart';

/// The heading above the case cards shortens five Bengali words and nothing
/// else; every other surface keeps the full court name.
void main() {
  group('shortenCourtHeading', () {
    test('shortens the five words the heading abbreviates', () {
      expect(
        shortenCourtHeading('সহকারি কমিশনার (ভূমি), ঢাকা'),
        'সহঃ কমিশনার (ভূমি), ঢাকা',
      );
      expect(
        shortenCourtHeading('সিনিয়র সিভিল জজ আদালত, ঢাকা'),
        'সিনিঃ সিভিল জজ আদালত, ঢাকা',
      );
      expect(
        shortenCourtHeading('জুডিসিয়াল ম্যাজিস্ট্রেট আদালত, ঢাকা'),
        'জুডিঃ ম্যাজিঃ আদালত, ঢাকা',
      );
      expect(
        shortenCourtHeading('অতিরিক্ত জেলা জজ ১ম আদালত, ঢাকা'),
        'অতিঃ জেলা জজ ১ম আদালত, ঢাকা',
      );
    });

    test('shortens the deed form of Bengali ya too', () {
      expect(
        shortenCourtHeading('সিনি\u09af\u09bcর সিভিল জজ আদালত'),
        'সিনিঃ সিভিল জজ আদালত',
      );
      expect(
        shortenCourtHeading('জুডিসি\u09af\u09bc\u09beল ম্যাজিস্ট্রেট আদালত'),
        'জুডিঃ ম্যাজিঃ আদালত',
      );
    });

    test('leaves English names and every other word alone', () {
      expect(
        shortenCourtHeading('Chief Judicial Magistrate Court, Dhaka'),
        'Chief Judicial Magistrate Court, Dhaka',
      );
      expect(
        shortenCourtHeading('জেলা জজ আদালত, ফরিদপুর'),
        'জেলা জজ আদালত, ফরিদপুর',
      );
    });
  });
}
