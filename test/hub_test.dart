import 'package:dropwatch/data.dart';
import 'package:dropwatch/hub_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const skin = Skin('skin', 'Prime Vandal', 'Vandal', '');
  final now = DateTime.utc(2026, 11, 22);
  test('Offer IDs resolve to catalog skins with VP and reset', () {
    final shop = HubShop.parse(
      {
        'data': {
          'SkinsPanelLayout': {
            'SingleItemStoreOffers': [
              {
                'OfferID': 'level',
                'Cost': {'85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741': 1775},
              },
            ],
            'SingleItemOffersRemainingDurationInSeconds': 60,
          },
        },
      },
      [skin],
      {'level': 'skin'},
      now,
    );
    expect(shop.offers.single.skin, skin);
    expect(shop.offers.single.vp, 1775);
    expect(shop.expiry, now.add(const Duration(minutes: 1)));
  });
  test('Missing VP and expiry stay unknown', () {
    final shop = HubShop.parse(
      {
        'store': {
          'offers': [
            {'name': 'Prime Vandal'},
          ],
        },
      },
      [skin],
      {},
      now,
    );
    expect(shop.offers.single.vp, isNull);
    expect(shop.expiry, isNull);
  });
  test('Unknown catalog entries do not become unrelated offers', () {
    final shop = HubShop.parse(
      {
        'offers': ['fresh-uuid'],
      },
      [skin],
      {},
      now,
    );
    expect(shop.offers.single.skin.id, 'fresh-uuid');
    expect(
      () => HubShop.parse({'success': true}, [], {}, now),
      throwsA(isA<HubFailure>()),
    );
    expect(HubShop.parse({'offers': []}, [], {}, now).offers, isEmpty);
  });
  test('Readable fallback removes credential fields and links', () {
    expect(
      shopFields({
        'offers': [
          {
            'cost': 875,
            'accessToken': 'x',
            'loginUrl': 'x',
            'preview': 'https://example.test',
          },
        ],
      }),
      {
        'offers': [
          {'cost': 875, 'preview': '…'},
        ],
      },
    );
  });
}
