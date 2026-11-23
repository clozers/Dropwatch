import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'browse.dart';
import 'data.dart';
import 'design.dart';

class Editor extends StatefulWidget {
  const Editor(
    this.store, {
    super.key,
    this.record,
    this.startWithPhoto = false,
  });
  final Store store;
  final Rotation? record;
  final bool startWithPhoto;
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  late final List<Offer> offers;
  late DateTime observed;
  final hours = TextEditingController(), minutes = TextEditingController();
  DateTime? previousExpiry;
  File? picked;
  bool busy = false;
  String? note, problem;
  @override
  void initState() {
    super.initState();
    observed = DateTime.now();
    offers = [...?widget.record?.offers];
    previousExpiry = widget.record?.expires;
    if (previousExpiry != null) {
      final left = previousExpiry!
          .difference(observed)
          .inMinutes
          .clamp(0, 1440);
      hours.text = (left ~/ 60).toString();
      minutes.text = (left % 60).toString();
    }
    if (widget.startWithPhoto) {
      WidgetsBinding.instance.addPostFrameCallback((_) => importPhoto());
    }
  }

  @override
  void dispose() {
    hours.dispose();
    minutes.dispose();
    final f = picked;
    if (f != null) _clean(f);
    super.dispose();
  }

  Future<void> _clean(File f) async {
    try {
      await f.delete();
    } on FileSystemException {
      /* Temporary gallery copy. */
    }
  }

  Future<void> importPhoto() async {
    if (busy) return;
    setState(() {
      busy = true;
      problem = null;
    });
    try {
      final result = await bridge.invokeMapMethod<String, dynamic>('pick');
      if (result == null) return;
      final f = File(result['path'] as String);
      if (!mounted) {
        await _clean(f);
        return;
      }
      final found = matchText(
        result['text'] as String? ?? '',
        widget.store.catalog,
      );
      final before = picked;
      setState(() {
        picked = f;
        final old = {for (final offer in offers) offer.skin.id: offer};
        offers
          ..clear()
          ..addAll(found.map((s) => old[s.id] ?? Offer(s)));
        note = found.isEmpty
            ? 'Screenshot siap. Pilih skin dari katalog jika ingin mencatat nama dan harga.'
            : '${found.length} skin terbaca. Periksa nama dan isi harga VP sesuai game.';
      });
      if (before != null) await _clean(before);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => problem = e.message ?? 'Gambar tidak bisa dibuka.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => problem =
              'Gagal membaca gambar. Kamu bisa memilih skin secara manual.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickSkin() async {
    final s = await Navigator.push<Skin>(
      context,
      MaterialPageRoute(
        builder: (_) => BrowserPage(
          widget.store,
          pick: true,
          excluded: offers.map((o) => o.skin.id).toSet(),
        ),
      ),
    );
    if (s != null && mounted) {
      setState(() {
        offers.add(Offer(s));
        problem = null;
      });
    }
  }

  Future<void> editPrice(int i) async {
    final input = TextEditingController(text: offers[i].vp?.toString() ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Harga di game'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Harga (VP)',
            hintText: 'Contoh 1775',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, input.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    // The dialog can still animate after its route resolves.
    Future<void>.delayed(const Duration(milliseconds: 350), input.dispose);
    if (value == null || !mounted) return;
    final n = int.tryParse(value);
    if (value.isNotEmpty && (n == null || n <= 0)) {
      message(context, 'Harga harus lebih dari 0 VP.');
      return;
    }
    setState(() => offers[i] = Offer(offers[i].skin, n));
  }

  Future<void> save() async {
    final h = int.tryParse(hours.text.trim()) ?? 0;
    final m = int.tryParse(minutes.text.trim()) ?? 0;
    final expiry =
        previousExpiry ?? observed.add(Duration(hours: h, minutes: m));
    if (picked == null && widget.record?.photo == null && offers.isEmpty) {
      setState(
        () => problem = 'Impor screenshot atau pilih setidaknya satu skin.',
      );
      return;
    }
    if (previousExpiry == null &&
            (m > 59 || h > 24 || h * 60 + m > 1440 || h * 60 + m == 0) ||
        !expiry.isAfter(DateTime.now())) {
      setState(
        () => problem =
            'Isi sisa waktu 1 menit sampai 24 jam sesuai timer di game.',
      );
      return;
    }
    setState(() {
      busy = true;
      problem = null;
    });
    try {
      final r = widget.record;
      await widget.store.save(
        Rotation(
          r?.id ?? observed.microsecondsSinceEpoch.toString(),
          r?.created ?? observed,
          expiry,
          List.of(offers),
          r?.photo,
        ),
        picked,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => problem =
              'Rotasi gagal disimpan. Periksa ruang penyimpanan lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget durationField(TextEditingController controller, String name) =>
      Expanded(
        child: TextField(
          controller: controller,
          onChanged: (_) {
            previousExpiry = null;
          },
          keyboardType: TextInputType.number,
          maxLength: 2,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: name,
            hintText: '00',
            counterText: '',
          ),
        ),
      );
  @override
  Widget build(BuildContext c) {
    final path =
        picked?.path ??
        (widget.record?.photo == null
            ? null
            : widget.store.photoPath(widget.record!.photo!));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.record == null ? 'Catat rotasi' : 'Edit rotasi'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (path != null) ...[
              InkWell(
                onTap: () => photoViewer(c, path),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(path),
                    height: 152,
                    fit: BoxFit.contain,
                    cacheWidth: 900,
                    errorBuilder: (c, e, s) =>
                        const Notice('Gambar tidak tersedia.'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: busy ? null : importPhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                busy
                    ? 'Memproses…'
                    : path == null
                    ? 'Impor screenshot toko'
                    : 'Pilih screenshot lain',
              ),
            ),
            if (note != null) ...[const SizedBox(height: 10), Notice(note!)],
            const SizedBox(height: 22),
            SectionTitle(
              'Penawaran',
              end: Text('${offers.length} / 4', style: label(acid)),
            ),
            for (var i = 0; i < offers.length; i++)
              SkinRow(
                widget.store,
                offers[i].skin,
                onTap: () => editPrice(i),
                subtitle: offers[i].vp == null
                    ? 'Ketuk untuk isi harga VP'
                    : '${vp(offers[i].vp!)} VP · Edit harga',
                trailing: IconButton(
                  tooltip: 'Hapus skin',
                  onPressed: () => setState(() => offers.removeAt(i)),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ),
            if (offers.length < 4)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: busy ? null : pickSkin,
                  icon: const Icon(Icons.add),
                  label: const Text('Pilih skin dari katalog'),
                ),
              ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 20),
            SectionTitle('Sisa waktu di game'),
            const SizedBox(height: 6),
            const Text(
              'Salin jam dan menit yang tertera di toko saat mencatat rotasi.',
              style: TextStyle(color: fog),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                durationField(hours, 'Jam'),
                const SizedBox(width: 12),
                durationField(minutes, 'Menit'),
              ],
            ),
            if (problem != null) ...[
              const SizedBox(height: 14),
              Notice(problem!, icon: Icons.error_outline),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy ? null : save,
              icon: const Icon(Icons.check),
              label: const Text('Simpan rotasi'),
            ),
          ],
        ),
      ),
    );
  }
}
