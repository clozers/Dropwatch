import 'dart:io';
import 'package:dropwatch/browse.dart';
import 'package:dropwatch/data.dart';
import 'package:dropwatch/design.dart';
import 'package:dropwatch/editor.dart';
import 'package:dropwatch/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const oni = Skin('oni', 'Oni Phantom', 'Phantom', ''),
      prime = Skin('prime', 'Prime Vandal', 'Vandal', '');
  test('OCR menangani kapital, nama terpisah baris dan duplikat', () {
    expect(
      matchText('OFFERS\nONI\nPHANTOM\n1,775\nPRIME VANDAL\nOni Phantom', [
        prime,
        oni,
      ]),
      [oni, prime],
    );
    expect(matchText('oni phantomatic rising', [oni]), isEmpty);
    expect(matchText('VANDAL PRIME', [prime]), [prime]);
  });
  test('Rotasi berakhir tepat pada waktu reset', () {
    final start = DateTime.utc(2026, 1, 1, 2),
        end = start.add(const Duration(hours: 3));
    final r = Rotation('a', start, end, [const Offer(oni, 1775)], null);
    expect(r.activeAt(start), isTrue);
    expect(r.activeAt(end), isFalse);
    expect(r.activeAt(start.subtract(const Duration(seconds: 1))), isFalse);
    final roundTrip = Rotation.fromJson(r.toJson());
    expect(roundTrip.expires.isAtSameMomentAs(end), isTrue);
    expect(roundTrip.offers.single.vp, 1775);
  });
  test(
    'API mempertahankan UUID dan menggunakan gambar level saat chroma kosong',
    () {
      final skins = parseWeapons(
        '{"data":[{"displayName":"Phantom","skins":[{"uuid":"a","displayName":"Oni Phantom","contentTierUuid":"x","chromas":[],"levels":[{"displayIcon":"https://example.test/art"}]},{"uuid":"default","contentTierUuid":null}]}]}',
      );
      expect(skins.single.image, 'https://example.test/art');
      expect(skins.single.id, 'a');
      expect(() => parseWeapons('{"data":[]}'), throwsFormatException);
    },
  );
  test('Wishlist dan foto bertahan setelah aplikasi dibuka kembali', () async {
    final dir = await Directory.systemTemp.createTemp('dropwatch-test');
    addTearDown(() => dir.delete(recursive: true));
    final s = Store(dir);
    await Future.wait([s.toggle(oni), s.toggle(prime)]);
    final f = await File('${dir.path}/source').writeAsString('test image');
    final now = DateTime.now();
    await s.save(
      Rotation('day', now, now.add(const Duration(hours: 1)), [
        const Offer(prime, 1775),
      ], null),
      f,
    );
    final loaded = Store(dir);
    await loaded.load();
    expect(loaded.catalog.length, greaterThan(1000));
    expect(loaded.wishes.keys, containsAll(['oni', 'prime']));
    final r = loaded.current(now)!;
    expect(await File(loaded.photoPath(r.photo!)).readAsString(), 'test image');
    await loaded.save(
      Rotation(r.id, r.created, r.expires, [const Offer(oni)], r.photo),
      null,
    );
    expect(loaded.history.length, 1);
    await loaded.remove(loaded.history.single);
    expect(await File(loaded.photoPath(r.photo!)).exists(), false);
    final after = Store(dir);
    await after.load();
    expect(after.history, isEmpty);
  });
  testWidgets('Pemilihan skin dari katalog mengembalikan hasil pencarian', (
    tester,
  ) async {
    final s = Store(Directory.systemTemp)..catalog = [oni, prime];
    Skin? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async {
              selected = await Navigator.push<Skin>(
                c,
                MaterialPageRoute(builder: (_) => BrowserPage(s, pick: true)),
              );
            },
            child: const Text('Buka'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'vandal prime');
    await tester.pump();
    expect(find.text('Oni Phantom'), findsNothing);
    await tester.tap(find.text('Prime Vandal'));
    await tester.pumpAndSettle();
    expect(selected, prime);
  });
  testWidgets('Beranda membedakan sorotan katalog dan rotasi kosong', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = Store(Directory.systemTemp)..catalog = [oni];
    await tester.pumpWidget(MaterialApp(theme: appTheme(), home: Home(s)));
    expect(find.text('BELUM ADA ROTASI'), findsOneWidget);
    expect(find.text('SOROTAN KATALOG'), findsOneWidget);
    await tester.tap(find.text('Pilih skin secara manual'));
    await tester.pumpAndSettle();
    expect(find.byType(Editor), findsOneWidget);
    await tester.tap(find.text('Simpan rotasi'));
    await tester.pump();
    expect(
      find.text('Impor screenshot atau pilih setidaknya satu skin.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('Editor menyimpan skin dan timer yang dikonfirmasi pengguna', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = CaptureStore()..catalog = [prime];
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => Editor(store)),
            ),
            child: const Text('Buka'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih skin dari katalog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prime Vandal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ketuk untuk isi harga VP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1775');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '2');
    await tester.enterText(find.byType(TextField).last, '15');
    await tester.tap(find.text('Simpan rotasi'));
    await tester.pumpAndSettle();
    expect(store.latest?.offers.single.skin.id, prime.id);
    expect(store.latest?.offers.single.vp, 1775);
    expect(
      store.latest!.expires.difference(store.latest!.created),
      const Duration(hours: 2, minutes: 15),
    );
    expect(find.text('Buka'), findsOneWidget);
  });
}

class CaptureStore extends Store {
  CaptureStore() : super(Directory.systemTemp);
  Rotation? latest;
  @override
  Future<void> save(Rotation r, File? selected) async {
    latest = r;
  }
}
