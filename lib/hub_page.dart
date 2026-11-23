import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'data.dart';
import 'design.dart';
import 'hub_api.dart';

class HubPage extends StatefulWidget {
  const HubPage(this.store, {super.key, this.client});
  final HubApi? client;
  final Store store;
  @override
  State<HubPage> createState() => _HubPageState();
}

class _HubPageState extends State<HubPage> {
  late final api = widget.client ?? HubApi();
  final input = TextEditingController();
  String key = '', selected = '', note = '';
  bool busy = true;
  List<Map> accounts = [];
  HubShop? shop;
  String? providerView;
  Timer? tick;
  DateTime? fetched;
  @override
  void initState() {
    super.initState();
    run(() async {
      key = await bridge.invokeMethod<String>('hubRead') ?? '';
      if (key.isNotEmpty) await loadAccounts();
    });
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && shop?.expiry != null) setState(() {});
    });
  }

  @override
  void dispose() {
    tick?.cancel();
    api.client.close(force: true);
    input.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() fn) async {
    setState(() {
      busy = true;
      note = '';
    });
    try {
      await fn();
    } on HubFailure catch (e) {
      note = e.message;
    } catch (_) {
      note = 'Operasi gagal. Periksa koneksi atau coba lagi.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadAccounts() async {
    accounts = [];
    shop = null;
    providerView = null;
    fetched = null;
    final body = await api.get('accounts', key);
    if (body['accounts'] is! List) {
      throw const HubFailure(
        'Daftar akun dari Valoranthub tidak dapat dibaca.',
      );
    }
    accounts = (body['accounts'] as List)
        .whereType<Map>()
        .where((a) => a['puuid'] is String)
        .toList();
    if (accounts.isEmpty) {
      selected = '';
      note =
          'Belum ada akun tertaut ke key ini. Buka penautan akun di Valoranthub, lalu perbarui.';
      return;
    }
    if (!accounts.any((a) => a['puuid'] == selected)) {
      selected = accounts.first['puuid'];
    }
    await loadShop();
  }

  Future<void> loadShop() async {
    shop = null;
    providerView = null;
    fetched = null;
    if (!mounted) return;
    final aliases =
        jsonDecode(
              await DefaultAssetBundle.of(
                context,
              ).loadString('assets/hub_aliases.json'),
            )
            as Map;
    final body = await api.get('store', key, {'puuid': selected});
    fetched = DateTime.now();
    try {
      shop = HubShop.parse(body, widget.store.catalog, aliases, fetched!);
    } on HubFailure {
      providerView = const JsonEncoder.withIndent(
        '  ',
      ).convert(shopFields(body));
      rethrow;
    }
  }

  Future<void> portal(String page) async {
    try {
      await bridge.invokeMethod<void>('hubPortal', {'page': page});
    } catch (_) {
      if (mounted) {
        message(
          context,
          'Browser tidak dapat dibuka. Kunjungi valoranttracker.com/developers/docs.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    final expiry = shop?.expiry, now = DateTime.now();
    final expired = expiry != null && !expiry.isAfter(now);
    return Scaffold(
      appBar: AppBar(title: const Text('Toko Valoranthub')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Toko akun saya', style: display(38)),
            const SizedBox(height: 12),
            if (key.isEmpty) ...[
              const Text(
                'Gunakan API key pribadi Valoranthub yang sudah ditautkan ke akun Riot kamu. Key disimpan terenkripsi di HP ini.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: input,
                enabled: !busy,
                autocorrect: false,
                enableSuggestions: false,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API key Valoranthub',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        final v = input.text.trim();
                        if (v.isEmpty) {
                          throw const HubFailure(
                            'Isi API key pribadi lebih dulu.',
                          );
                        }
                        await bridge.invokeMethod<void>('hubWrite', {
                          'value': v,
                        });
                        key = v;
                        if (!mounted) return;
                        input.clear();
                        await loadAccounts();
                      }),
                child: const Text('Hubungkan dan lihat toko'),
              ),
            ] else ...[
              if (accounts.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Riot ID tertaut',
                  ),
                  items: accounts
                      .map(
                        (a) => DropdownMenuItem<String>(
                          value: a['puuid'],
                          child: Text(
                            a['gameName'] == null
                                ? a['puuid']
                                : '${a['gameName']}#${a['tagLine'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (v) {
                          if (v != null) {
                            run(() async {
                              selected = v;
                              await loadShop();
                            });
                          }
                        },
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : () => run(loadAccounts),
                icon: const Icon(Icons.refresh),
                label: const Text('Perbarui toko'),
              ),
            ],
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Notice(note),
              ),
            if (providerView != null)
              ExpansionTile(
                title: const Text('Lihat data toko dari penyedia'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(providerView!),
                  ),
                ],
              ),
            if (shop != null) ...[
              const SizedBox(height: 16),
              Text(
                expired ? 'Rotasi berakhir' : 'Penawaran harian',
                style: display(26),
              ),
              if (expiry != null)
                Text(
                  expired
                      ? 'Perbarui untuk melihat rotasi berikutnya.'
                      : 'Reset dalam ${leftTime(expiry.difference(now))}',
                ),
              if (!expired) ...[
                Text(
                  'Diambil pukul ${clock(fetched!)}',
                  style: const TextStyle(color: fog),
                ),
                if (shop!.offers.isEmpty)
                  const Text('Penyedia mengembalikan daftar penawaran kosong.'),
                for (final o in shop!.offers)
                  SkinRow(
                    widget.store,
                    o.skin,
                    onTap: () => details(c, widget.store, o.skin),
                    subtitle: o.vp == null
                        ? 'Harga tidak tersedia'
                        : '${vp(o.vp!)} VP',
                  ),
              ],
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => portal('keys'),
              child: const Text('Kelola API key di Valoranthub'),
            ),
            TextButton(
              onPressed: () => portal('link'),
              child: const Text('Penautan akun di Valoranthub'),
            ),
            TextButton(
              onPressed: () => portal('docs'),
              child: const Text('Panduan penautan dengan API key'),
            ),
            if (key.isNotEmpty)
              TextButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        await bridge.invokeMethod<void>('hubWrite', {
                          'value': '',
                        });
                        key = '';
                        selected = '';
                        accounts = [];
                        shop = null;
                        providerView = null;
                        fetched = null;
                      }),
                child: const Text('Hapus key dari HP'),
              ),
          ],
        ),
      ),
    );
  }
}
