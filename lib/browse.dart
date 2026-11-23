import 'package:flutter/material.dart';
import 'data.dart';
import 'design.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage(
    this.store, {
    super.key,
    this.wishlist = false,
    this.pick = false,
    this.excluded = const {},
  });
  final Store store;
  final bool wishlist, pick;
  final Set<String> excluded;
  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  final query = TextEditingController();
  String? weapon;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: widget.store,
    builder: (c, _) {
      final store = widget.store;
      final source = widget.wishlist
          ? store.wishes.values.toList()
          : store.catalog;
      final words = normalized(
        query.text,
      ).split(' ').where((s) => s.isNotEmpty);
      bool matches(Skin s) =>
          !widget.excluded.contains(s.id) &&
          (weapon == null || s.weapon == weapon) &&
          words.every(normalized('${s.name} ${s.weapon}').contains);
      final items = source.where(matches).toList();
      final weapons = source.map((s) => s.weapon).toSet().toList()..sort();
      final filters = <String>{
        'Vandal',
        'Phantom',
        'Melee',
        if (weapon != null) weapon!,
      }.where(weapons.contains);
      Future<void> allTypes() async {
        final choice = await showModalBottomSheet<String>(
          context: c,
          builder: (ctx) => SafeArea(
            child: ListView(
              children: [
                for (final option in ['Semua', ...weapons])
                  ListTile(
                    title: Text(option),
                    trailing: option == (weapon ?? 'Semua')
                        ? const Icon(Icons.check, color: acid)
                        : null,
                    onTap: () => Navigator.pop(ctx, option),
                  ),
              ],
            ),
          ),
        );
        if (mounted && choice != null) {
          setState(() => weapon = choice == 'Semua' ? null : choice);
        }
      }

      return Scaffold(
        appBar: widget.pick ? AppBar(title: const Text('Pilih skin')) : null,
        body: SafeArea(
          top: widget.pick,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.pick) ...[
                      Text(
                        widget.wishlist ? 'KOLEKSI PRIBADI' : 'VALORANT',
                        style: label(acid),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.wishlist ? 'Wishlist' : 'Katalog skin',
                              style: display(44),
                            ),
                          ),
                          if (!widget.wishlist)
                            IconButton(
                              tooltip: 'Perbarui katalog',
                              onPressed: store.syncing ? null : store.refresh,
                              icon: store.syncing
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: query,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Cari nama skin atau senjata',
                        suffixIcon: query.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Hapus pencarian',
                                onPressed: () {
                                  query.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.wishlist || source.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      for (final category in ['Semua', ...filters])
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            showCheckmark: false,
                            label: Text(
                              category,
                              style: TextStyle(
                                color: category == (weapon ?? 'Semua')
                                    ? ink
                                    : paper,
                              ),
                            ),
                            selectedColor: acid,
                            selected: category == (weapon ?? 'Semua'),
                            onSelected: (_) => setState(
                              () => weapon = category == 'Semua'
                                  ? null
                                  : category,
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Semua jenis senjata',
                        onPressed: allTypes,
                        icon: const Icon(Icons.tune),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 11, 20, 9),
                child: Text('${items.length} SKIN', style: label()),
              ),
              if (!widget.wishlist && !widget.pick && store.syncError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Text(
                    store.syncError!,
                    style: const TextStyle(color: fog, fontSize: 12),
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            widget.wishlist && source.isEmpty
                                ? 'Tandai skin di Katalog untuk mengisi wishlist.'
                                : 'Tidak ada skin yang cocok.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: fog),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: items.length,
                        separatorBuilder: (c, i) => const Divider(),
                        itemBuilder: (c, i) {
                          final s = items[i];
                          return SkinRow(
                            store,
                            s,
                            onTap: () => widget.pick
                                ? Navigator.pop(c, s)
                                : details(c, store, s),
                            trailing: widget.pick
                                ? const Icon(
                                    Icons.add_circle_outline,
                                    color: acid,
                                  )
                                : IconButton(
                                    tooltip: store.wishes.containsKey(s.id)
                                        ? 'Hapus dari wishlist'
                                        : 'Tambah ke wishlist',
                                    onPressed: () => favorite(c, store, s),
                                    icon: Icon(
                                      store.wishes.containsKey(s.id)
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                      color: store.wishes.containsKey(s.id)
                                          ? acid
                                          : fog,
                                    ),
                                  ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
