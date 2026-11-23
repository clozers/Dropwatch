import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'browse.dart';
import 'data.dart';
import 'design.dart';
import 'editor.dart';
import 'hub_page.dart';

class Home extends StatefulWidget {
  const Home(this.store, {super.key});
  final Store store;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 7),
            child: Row(
              children: [
                const Emblem(),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'DROPWATCH',
                        style: display(24).copyWith(
                          letterSpacing: .8,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tentang Dropwatch',
                  icon: const Icon(Icons.info_outline, size: 20),
                  onPressed: () => showAboutDialog(
                    context: c,
                    applicationName: 'Dropwatch',
                    applicationVersion: '1.1.0',
                    applicationIcon: const Emblem(),
                    children: const [
                      Text(
                        'Toko akun diambil dari Valoranthub. Rotasi manual berasal dari catatanmu. Katalog dan ilustrasi skin bersumber dari komunitas Valorant-API.',
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Dropwatch adalah aplikasi penggemar independen. VALORANT dan aset game merupakan milik Riot Games.',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Riwayat rotasi',
                  onPressed: () => Navigator.push(
                    c,
                    MaterialPageRoute(
                      builder: (_) => HistoryPage(widget.store),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: IndexedStack(
              index: tab,
              children: [
                Today(widget.store, onCatalog: () => setState(() => tab = 1)),
                BrowserPage(widget.store),
                BrowserPage(widget.store, wishlist: true),
              ],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: panel,
        indicatorColor: acid,
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            color: s.contains(WidgetState.selected) ? acid : fog,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? ink : fog,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (n) => setState(() => tab = n),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Toko',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Katalog',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Wishlist',
          ),
        ],
      ),
    ),
  );
}

class Today extends StatefulWidget {
  const Today(this.store, {super.key, required this.onCatalog});
  final Store store;
  final VoidCallback onCatalog;
  @override
  State<Today> createState() => _TodayState();
}

class _TodayState extends State<Today> with WidgetsBindingObserver {
  DateTime now = DateTime.now();
  Timer? ticks;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    start();
  }

  void start() {
    ticks?.cancel();
    ticks = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => now = DateTime.now());
      start();
    } else {
      ticks?.cancel();
    }
  }

  @override
  void dispose() {
    ticks?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> edit({Rotation? r, bool photo = false}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => Editor(widget.store, record: r, startWithPhoto: photo),
      ),
    );
    if (mounted && saved == true) {
      setState(() => now = DateTime.now());
      message(context, 'Rotasi disimpan di perangkat.');
    }
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: widget.store,
    builder: (c, _) {
      final store = widget.store, record = store.current(now);
      final featured =
          store.catalog.where((s) => s.name == 'Reaver Vandal').firstOrNull ??
          store.catalog.first;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          Text(
            '${days[now.weekday - 1]}, ${dateStamp(now)}'.toUpperCase(),
            style: label(acid),
          ),
          const SizedBox(height: 6),
          Text('Toko harian', style: display(46)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => HubPage(store)),
            ),
            icon: const Icon(Icons.storefront),
            label: const Text('Lihat toko akun saya'),
          ),
          const SizedBox(height: 12),
          if (record == null) ...[
            Spotlight(store, featured),
            const SizedBox(height: 22),
            SectionTitle('Rotasi saya'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: edge),
                color: panel,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: acid),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          store.history.isEmpty
                              ? 'BELUM ADA ROTASI'
                              : 'ROTASI TERAKHIR SELESAI',
                          style: label(acid),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Impor screenshot toko VALORANT kamu untuk melihat penawaran dan mencatat harga VP.',
                    style: TextStyle(color: fog, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => edit(photo: true),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Impor screenshot'),
                  ),
                  TextButton(
                    onPressed: () => edit(),
                    child: const Text('Pilih skin secara manual'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: const LinearGradient(
                  colors: [Color(0xff334536), Color(0xff202c28)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: acid),
                      const SizedBox(width: 8),
                      Text('WAKTU TERSISA', style: label(acid)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    leftTime(record.expires.difference(now)),
                    style: display(48),
                  ),
                  Text(
                    'Reset ${dateStamp(record.expires)}, ${clock(record.expires)} waktu lokal',
                    style: const TextStyle(color: fog, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionTitle(
              'Penawaran saya',
              end: TextButton.icon(
                onPressed: () => edit(r: record),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
            ),
            RotationInfo(store, record),
            const SizedBox(height: 24),
            Spotlight(store, featured),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onCatalog,
              icon: const Icon(Icons.grid_view, size: 16),
              label: const Text('Jelajahi katalog skin'),
            ),
          ),
        ],
      );
    },
  );
}

class Spotlight extends StatelessWidget {
  const Spotlight(this.store, this.skin, {super.key});
  final Store store;
  final Skin skin;
  @override
  Widget build(BuildContext c) {
    final title = skin.name.endsWith(' ${skin.weapon}')
        ? skin.name.substring(0, skin.name.length - skin.weapon.length - 1)
        : skin.name;
    return Semantics(
      button: true,
      label: 'Sorotan katalog. ${skin.name}. Lihat detail',
      excludeSemantics: true,
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xff3b2949),
        child: InkWell(
          onTap: () => details(c, store, skin),
          child: Container(
            height: 196,
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: lilac.withAlpha(50)),
              borderRadius: BorderRadius.circular(16),
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  Color(0xff241e30),
                  Color(0xff533966),
                  Color(0xff9472a4),
                ],
              ),
            ),
            child: LayoutBuilder(
              builder: (c, box) => Stack(
                children: [
                  const Positioned.fill(child: CustomPaint(painter: Stripes())),
                  Positioned(
                    right: 6,
                    top: 30,
                    width: box.maxWidth * .67,
                    height: 130,
                    child: Transform.rotate(
                      angle: -.16,
                      child: Art(store, skin),
                    ),
                  ),
                  Positioned(
                    left: 17,
                    top: 15,
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: lilac,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text('SOROTAN KATALOG', style: label(paper)),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 15,
                    right: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title.toUpperCase(), style: display(39)),
                              Text(
                                skin.weapon.toUpperCase(),
                                style: label(lilac),
                              ),
                            ],
                          ),
                        ),
                        const CircleAvatar(
                          radius: 15,
                          backgroundColor: Color(0xff40344e),
                          child: Icon(Icons.north_east, color: paper, size: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RotationInfo extends StatelessWidget {
  const RotationInfo(this.store, this.record, {super.key});
  final Store store;
  final Rotation record;
  @override
  Widget build(BuildContext c) {
    final count = record.offers
        .where((o) => store.wishes.containsKey(o.skin.id))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (count > 0) ...[
          Notice(
            '$count skin di rotasi ini ada di wishlist kamu.',
            icon: Icons.bookmark,
          ),
          const SizedBox(height: 6),
        ],
        for (final offer in record.offers)
          SkinRow(
            store,
            offer.skin,
            onTap: () => details(c, store, offer.skin),
            subtitle: offer.vp == null
                ? offer.skin.weapon
                : '${vp(offer.vp!)} VP',
            trailing: IconButton(
              tooltip: store.wishes.containsKey(offer.skin.id)
                  ? 'Hapus dari wishlist'
                  : 'Tambah ke wishlist',
              onPressed: () => favorite(c, store, offer.skin),
              icon: Icon(
                store.wishes.containsKey(offer.skin.id)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: store.wishes.containsKey(offer.skin.id) ? acid : fog,
              ),
            ),
          ),
        if (record.photo != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => photoViewer(c, store.photoPath(record.photo!)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(store.photoPath(record.photo!)),
                height: 115,
                fit: BoxFit.contain,
                cacheWidth: 800,
                errorBuilder: (c, e, s) =>
                    const Notice('Screenshot tidak tersedia.'),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => photoViewer(c, store.photoPath(record.photo!)),
            icon: const Icon(Icons.zoom_out_map, size: 16),
            label: const Text('Perbesar screenshot'),
          ),
        ],
      ],
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage(this.store, {super.key});
  final Store store;
  Future<void> remove(BuildContext c, Rotation r) async {
    final go = await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: const Text('Hapus rotasi ini?'),
        content: const Text(
          'Catatan dan screenshot rotasi ini akan dihapus dari perangkat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (go == true) {
      try {
        await store.remove(r);
      } catch (_) {
        if (c.mounted) message(c, 'Rotasi gagal dihapus.');
      }
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Riwayat rotasi')),
    body: ListenableBuilder(
      listenable: store,
      builder: (c, _) => store.history.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Rotasi yang kamu simpan akan muncul di sini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fog),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: store.history.length,
              separatorBuilder: (c, i) => const Divider(),
              itemBuilder: (c, i) {
                final r = store.history[i];
                return ExpansionTile(
                  key: ValueKey(r.id),
                  title: Text('${dateStamp(r.created)} · ${clock(r.created)}'),
                  subtitle: Text(
                    '${r.offers.length} skin${r.photo == null ? '' : ' · Screenshot'}',
                  ),
                  children: [
                    RotationInfo(store, r),
                    TextButton.icon(
                      onPressed: () => remove(c, r),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Hapus catatan'),
                    ),
                  ],
                );
              },
            ),
    ),
  );
}
