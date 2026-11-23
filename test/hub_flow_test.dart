import 'dart:io';
import 'package:dropwatch/data.dart';
import 'package:dropwatch/design.dart';
import 'package:dropwatch/hub_api.dart';
import 'package:dropwatch/hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class TestHub extends HubApi {
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> get(
    String path,
    String key, [
    Map<String, String>? query,
  ]) async {
    calls.add('$path/${query?['puuid'] ?? ''}');
    expect(key, 'test-only');
    if (path == 'accounts') {
      return {
        'success': true,
        'accounts': [
          {'gameName': 'Test', 'tagLine': 'ID', 'puuid': 'account-1'},
        ],
      };
    }
    return {
      'success': true,
      'store': {
        'offers': [
          {'name': 'Prime Vandal', 'vp': 1775},
        ],
      },
    };
  }
}

class TestAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(key);
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      key == 'assets/hub_aliases.json'
      ? '{}'
      : super.loadString(key, cache: cache);
}

void main() {
  testWidgets('Loads linked Riot ID and requests its daily offers', (
    tester,
  ) async {
    final api = TestHub();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      bridge,
      (call) async => call.method == 'hubRead' ? 'test-only' : null,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(bridge, null));
    final store = Store(Directory.systemTemp)
      ..catalog = [const Skin('skin', 'Prime Vandal', 'Vandal', '')];
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: DefaultAssetBundle(
          bundle: TestAssets(),
          child: HubPage(store, client: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.calls, ['accounts/', 'store/account-1']);
    expect(find.text('Test#ID'), findsOneWidget);
    expect(find.text('Prime Vandal'), findsOneWidget);
    expect(find.text('1.775 VP'), findsOneWidget);
    await tester.tap(find.text('Perbarui toko'));
    await tester.pumpAndSettle();
    expect(api.calls.length, 4);
    await tester.pumpWidget(const SizedBox());
  });
}
