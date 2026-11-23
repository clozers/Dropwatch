import 'dart:convert';
import 'dart:io';
import 'data.dart';

class HubFailure implements Exception {
  const HubFailure(this.message);
  final String message;
}

class HubApi {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 9);
  Future<Map<String, dynamic>> get(
    String path,
    String key, [
    Map<String, String>? query,
  ]) async {
    final uri = Uri.https(
      'api.valoranttracker.com',
      '/public/v1/me/$path',
      query,
    );
    final req = await client.getUrl(uri).timeout(const Duration(seconds: 12));
    req.followRedirects = false;
    req.headers.set('X-API-Key', key);
    req.headers.set('Accept', 'application/json');
    final res = await req.close().timeout(const Duration(seconds: 15));
    final raw = await utf8.decoder
        .bind(res)
        .join()
        .timeout(const Duration(seconds: 16));
    final dynamic decoded = raw.trimLeft().startsWith('{')
        ? jsonDecode(raw)
        : null;
    final body = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (body['code'] == 'NEED_REAUTH' || body['error'] == 'NEED_REAUTH') {
      throw const HubFailure(
        'Sesi Riot berakhir. Tautkan ulang akun di Valoranthub, lalu perbarui.',
      );
    }
    switch (res.statusCode) {
      case 401:
      case 403:
        throw const HubFailure(
          'Akses ditolak. Periksa API key pribadi dan akses akun di Valoranthub.',
        );
      case 404:
        throw const HubFailure('Akun atau toko tidak tersedia untuk key ini.');
      case 429:
        throw const HubFailure(
          'Batas permintaan Valoranthub tercapai. Coba lagi nanti.',
        );
    }
    if (res.statusCode != 200 || body.isEmpty || body['success'] == false) {
      throw const HubFailure(
        'Valoranthub belum bisa menyediakan data. Coba lagi nanti.',
      );
    }
    return body;
  }
}

class HubShop {
  HubShop(this.offers, this.expiry);
  final List<Offer> offers;
  final DateTime? expiry;
  static HubShop parse(
    Map body,
    List<Skin> catalog,
    Map aliases,
    DateTime now,
  ) {
    final byId = {for (final s in catalog) s.id: s},
        byName = {for (final s in catalog) s.name.toLowerCase(): s};
    dynamic node = body;
    DateTime? expires;
    List? rows;
    for (var depth = 0; depth < 7; depth++) {
      if (node is List) {
        rows = node;
        break;
      }
      if (node is! Map) break;
      final seconds = int.tryParse(
        '${node['SingleItemOffersRemainingDurationInSeconds'] ?? node['remainingSeconds'] ?? node['remaining_seconds'] ?? node['remainingDurationInSeconds'] ?? ''}',
      );
      if (seconds != null && seconds >= 0 && seconds <= 86400) {
        expires = now.add(Duration(seconds: seconds));
      }
      final absolute = node['expiresAt'] ?? node['expires_at'];
      if (absolute is String) {
        expires = DateTime.tryParse(absolute)?.toLocal() ?? expires;
      }
      node =
          node['SkinsPanelLayout'] ??
          node['SingleItemStoreOffers'] ??
          node['SingleItemOffers'] ??
          node['dailyOffers'] ??
          node['daily_offers'] ??
          node['dailyShop'] ??
          node['daily'] ??
          node['offers'] ??
          node['items'] ??
          node['skins'] ??
          node['store'] ??
          node['shop'] ??
          node['data'];
    }
    if (rows == null) {
      throw const HubFailure(
        'Format toko dari Valoranthub belum dikenali. Tidak ada penawaran yang bisa ditampilkan.',
      );
    }
    final offers = <Offer>[];
    for (final row in rows) {
      final m = row is Map ? row : const {};
      final skin = m['skin'] is Map ? m['skin'] as Map : m;
      final id =
          (skin['uuid'] ??
                  skin['skinUuid'] ??
                  skin['skin_uuid'] ??
                  skin['id'] ??
                  m['OfferID'] ??
                  (row is String ? row : ''))
              .toString();
      final name =
          skin['displayName'] ??
          skin['name'] ??
          skin['display_name'] ??
          skin['skinName'];
      final known =
          byId[id] ??
          byId[aliases[id]] ??
          (name is String ? byName[name.toLowerCase()] : null);
      if (known == null && (name is! String || name.isEmpty) && id.isEmpty) {
        throw const HubFailure(
          'Detail penawaran dari Valoranthub belum dikenali.',
        );
      }
      final price = m['price'] ?? m['vp'] ?? m['cost'] ?? m['Cost'];
      final value = price is Map
          ? price['85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741'] ?? price['vp']
          : price;
      offers.add(
        Offer(
          known ?? Skin(id, name is String ? name : 'Skin $id', 'VALORANT', ''),
          int.tryParse('$value'),
        ),
      );
    }
    return HubShop(offers, expires);
  }
}

// The provider does not publish a schema for its successful store response.
// Keep unknown store data readable without showing links or account secrets.
Object? shopFields(Object? value) {
  if (value is Map) {
    final hidden = RegExp(
      r'key|token|password|secret|cookie|auth|session|url|email|puuid|login|credential',
      caseSensitive: false,
    );
    return {
      for (final e in value.entries)
        if (!hidden.hasMatch(e.key.toString()))
          e.key.toString(): shopFields(e.value),
    };
  }
  if (value is List) return value.map(shopFields).toList();
  if (value is String && (value.startsWith('http') || value.length > 200)) {
    return '…';
  }
  return value;
}
