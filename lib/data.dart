import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const bridge = MethodChannel('dev.dropwatch/mobile');

class Skin {
  const Skin(this.id, this.name, this.weapon, this.image);
  final String id, name, weapon, image;
  factory Skin.fromJson(Map<String, dynamic> j) => Skin(
    j['id'] as String,
    j['name'] as String,
    j['weapon'] as String,
    j['image'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'weapon': weapon,
    'image': image,
  };
}

List<Skin> parseWeapons(String body) {
  final ws = (jsonDecode(body) as Map)['data'] as List;
  final skins = <Skin>[];
  for (final w in ws) {
    for (final s in w['skins'] as List) {
      if (s['contentTierUuid'] == null) continue;
      final chromas = s['chromas'] as List? ?? [];
      final levels = s['levels'] as List? ?? [];
      final art =
          (chromas.isEmpty ? null : chromas.first['fullRender']) ??
          s['displayIcon'] ??
          (levels.isEmpty ? null : levels.first['displayIcon']) ??
          '';
      skins.add(Skin(s['uuid'], s['displayName'], w['displayName'], art));
    }
  }
  if (skins.isEmpty) throw const FormatException('Katalog kosong');
  return skins;
}

String normalized(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
List<Skin> matchText(String input, List<Skin> catalog) {
  // Word boundaries avoid matching Ion in Singularity. Across-line matching
  // also supports game layouts that wrap the collection and weapon names.
  final lines = input
      .split('\n')
      .map(normalized)
      .where((s) => s.isNotEmpty)
      .toList();
  final joined = ' ${lines.join(' ')} ';
  final matches = <(int, Skin)>[];
  for (final skin in catalog) {
    final name = normalized(skin.name);
    if (name.isEmpty) continue;
    var at = joined.indexOf(' $name ');
    final weapon = normalized(skin.weapon);
    if (at < 0 && name.endsWith(' $weapon')) {
      final collection = name.substring(0, name.length - weapon.length - 1);
      at = joined.indexOf(' $weapon $collection ');
    }
    if (at >= 0) matches.add((at, skin));
  }
  matches.sort(
    (a, b) => a.$1 != b.$1
        ? a.$1.compareTo(b.$1)
        : b.$2.name.length.compareTo(a.$2.name.length),
  );
  var end = -1;
  final result = <Skin>[];
  for (final m in matches) {
    if (m.$1 < end) continue;
    result.add(m.$2);
    end = m.$1 + normalized(m.$2.name).length;
    if (result.length == 4) break;
  }
  return result;
}

class Offer {
  const Offer(this.skin, [this.vp]);
  final Skin skin;
  final int? vp;
  factory Offer.fromJson(Map<String, dynamic> j) =>
      Offer(Skin.fromJson(j['skin']), j['vp'] as int?);
  Map<String, dynamic> toJson() => {'skin': skin.toJson(), 'vp': vp};
}

class Rotation {
  const Rotation(this.id, this.created, this.expires, this.offers, this.photo);
  final String id;
  final DateTime created, expires;
  final List<Offer> offers;
  final String? photo;
  bool activeAt(DateTime t) => !t.isBefore(created) && t.isBefore(expires);
  factory Rotation.fromJson(Map<String, dynamic> j) => Rotation(
    j['id'],
    DateTime.parse(j['created']).toLocal(),
    DateTime.parse(j['expires']).toLocal(),
    (j['offers'] as List).map((o) => Offer.fromJson(o)).toList(),
    j['photo'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'created': created.toUtc().toIso8601String(),
    'expires': expires.toUtc().toIso8601String(),
    'offers': offers.map((e) => e.toJson()).toList(),
    'photo': photo,
  };
}

Future<void> atomicWrite(File file, Object value) async {
  final temp = File('${file.path}.tmp');
  await temp.writeAsString(jsonEncode(value), flush: true);
  await temp.rename(file.path);
}

class Store extends ChangeNotifier {
  Store(this.dir);
  final Directory dir;
  List<Skin> catalog = [];
  Set<String> bundled = {};
  Map<String, Skin> wishes = {};
  List<Rotation> history = [];
  DateTime? lastSync;
  bool syncing = false;
  String? syncError;
  Future<void> _writes = Future.value();
  String photoPath(String name) => '${dir.path}/$name';
  File get _library => File('${dir.path}/library.json');
  File get _cache => File('${dir.path}/catalog.json');

  Future<void> load() async {
    final seeds =
        jsonDecode(await rootBundle.loadString('assets/catalog.json')) as List;
    catalog = seeds.map((e) => Skin.fromJson(e)).toList();
    bundled =
        (jsonDecode(await rootBundle.loadString('assets/bundled.json')) as List)
            .cast<String>()
            .toSet();
    if (await _cache.exists()) {
      try {
        final saved = jsonDecode(await _cache.readAsString());
        final cached = (saved['items'] as List)
            .map((s) => Skin.fromJson(s))
            .toList();
        if (cached.isNotEmpty) {
          lastSync = DateTime.parse(saved['at']).toLocal();
          catalog = cached;
        }
      } catch (_) {
        syncError = 'Cache katalog tidak terbaca. Katalog bawaan digunakan.';
      }
    }
    if (await _library.exists()) {
      final saved = jsonDecode(await _library.readAsString());
      final skins = (saved['wishes'] as List).map((s) => Skin.fromJson(s));
      wishes = {for (final s in skins) s.id: s};
      history = (saved['history'] as List)
          .map((r) => Rotation.fromJson(r))
          .toList();
    }
    _order();
  }

  void _order() {
    catalog.sort((a, b) {
      if (bundled.contains(a.id) != bundled.contains(b.id)) {
        return bundled.contains(a.id) ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });
    history.sort((a, b) => b.created.compareTo(a.created));
  }

  Future<void> refresh() async {
    if (syncing) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await http
          .getUrl(
            Uri.https('valorant-api.com', '/v1/weapons', {'language': 'en-US'}),
          )
          .timeout(const Duration(seconds: 12));
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final body = await utf8.decoder
          .bind(res)
          .join()
          .timeout(const Duration(seconds: 20));
      final list = await compute(parseWeapons, body);
      final now = DateTime.now();
      await atomicWrite(_cache, {
        'at': now.toUtc().toIso8601String(),
        'items': list.map((s) => s.toJson()).toList(),
      });
      catalog = list;
      lastSync = now;
      _order();
    } catch (_) {
      syncError =
          'Katalog belum bisa diperbarui. Koleksi tersimpan tetap tersedia.';
    } finally {
      http.close(force: true);
      syncing = false;
      notifyListeners();
    }
  }

  Rotation? current(DateTime now) =>
      history.where((r) => r.activeAt(now)).firstOrNull;
  Future<void> _change(Future<void> Function() fn) {
    final job = _writes.then((_) => fn());
    _writes = job.catchError((Object _) {});
    return job;
  }

  Future<void> _persist(
    Map<String, Skin> nextWishes,
    List<Rotation> nextHistory,
  ) async {
    await atomicWrite(_library, {
      'wishes': nextWishes.values.map((s) => s.toJson()).toList(),
      'history': nextHistory.map((r) => r.toJson()).toList(),
    });
    wishes = nextWishes;
    history = nextHistory;
    notifyListeners();
  }

  Future<void> toggle(Skin s) => _change(() async {
    final next = {...wishes};
    if (next.remove(s.id) == null) next[s.id] = s;
    await _persist(next, history);
  });

  Future<void> save(Rotation r, File? selected) => _change(() async {
    final filename = selected == null
        ? r.photo
        : 'rotasi-${r.id}-${DateTime.now().microsecondsSinceEpoch}.img';
    File? copied;
    try {
      if (selected != null) {
        copied = File(photoPath(filename!));
        await selected.copy(copied.path);
      }
      final record = Rotation(r.id, r.created, r.expires, r.offers, filename);
      final old = history.where((x) => x.id == r.id).firstOrNull;
      final next = [record, ...history.where((x) => x.id != r.id)]
        ..sort((a, b) => b.created.compareTo(a.created));
      await _persist(wishes, next);
      if (old?.photo != null && old!.photo != filename) {
        await _discard(old.photo!);
      }
    } catch (_) {
      if (copied != null && !history.any((r) => r.photo == filename)) {
        await _discard(filename!);
      }
      rethrow;
    }
  });
  Future<void> _discard(String name) async {
    try {
      await File(photoPath(name)).delete();
    } on FileSystemException {
      /* Cleanup can be retried by the OS on uninstall. */
    }
  }

  Future<void> remove(Rotation r) => _change(() async {
    await _persist(wishes, history.where((x) => x.id != r.id).toList());
    if (r.photo != null) await _discard(r.photo!);
  });
}
