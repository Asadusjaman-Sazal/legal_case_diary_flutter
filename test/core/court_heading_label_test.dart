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
      expect(
        shortenCourtHeading('নারায়ণগঞ্জ জেলা জজ আদালত'),
        'নাঃগঞ্জ জেলা জজ আদালত',
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
      expect(
        shortenCourtHeading('নারা\u09af\u09bcণগঞ্জ জেলা জজ আদালত'),
        'নাঃগঞ্জ জেলা জজ আদালত',
      );
    });

    test('a court can bring its own heading wording', () {
      const id = 'court-lower_courts-dhaka-narayanganj-district_courts_civil-senior_civil_judge_2nd_court_siddhirganj_and_fatulla_narayanganj';
      expect(courtHeadingOverride(id, bengali: false), 'Senior Civil Judge Sadar, Narayanganj');
      expect(courtHeadingOverride(id, bengali: true), 'সিনিয়র সিভিল জজ সদর আদালত, নারায়ণগঞ্জ');
      expect(shortenCourtHeading(courtHeadingOverride(id, bengali: true)!), 'সিনিঃ সিভিল জজ সদর আদালত, নাঃগঞ্জ');
      expect(courtHeadingOverride('court-unknown', bengali: true), isNull);
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
