import 'dart:io';
import 'package:flutter/material.dart';
import 'data.dart';

const ink = Color(0xff101519),
    panel = Color(0xff1a2025),
    edge = Color(0xff343b40);
const fog = Color(0xffaeb8b8),
    paper = Color(0xfff5f5ed),
    acid = Color(0xffcefc63);
const lilac = Color(0xffd6baff);
TextStyle display(double size, {Color color = paper}) => TextStyle(
  fontFamily: 'Barlow Condensed',
  fontWeight: FontWeight.w700,
  fontSize: size,
  height: 1.02,
  letterSpacing: -0.4,
  color: color,
);
TextStyle label([Color color = fog]) => TextStyle(
  fontSize: 10.5,
  letterSpacing: 1.5,
  height: 1.35,
  fontWeight: FontWeight.w700,
  color: color,
);
const months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];
const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
String dateStamp(DateTime t) => '${t.day} ${months[t.month - 1]} ${t.year}';
String clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
String leftTime(Duration d) {
  if (d.isNegative) return '00:00:00';
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(d.inHours)}:${pad(d.inMinutes % 60)}:${pad(d.inSeconds % 60)}';
}

String vp(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
ThemeData appTheme() {
  const scheme = ColorScheme.dark(
    surface: ink,
    primary: acid,
    onPrimary: ink,
    secondary: lilac,
    onSurface: paper,
    surfaceContainerHighest: panel,
    outline: edge,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: ink,
    appBarTheme: const AppBarTheme(
      backgroundColor: ink,
      foregroundColor: paper,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: panel),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: panel,
      showDragHandle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: acid,
        foregroundColor: ink,
        minimumSize: const Size(48, 48),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: paper,
        side: const BorderSide(color: edge),
        shape: shape,
        minimumSize: const Size(48, 46),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: edge),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: edge),
      ),
    ),
    dividerTheme: const DividerThemeData(color: edge, space: 1),
  );
}

class Emblem extends StatelessWidget {
  const Emblem({super.key, this.size = 32});
  final double size;
  @override
  Widget build(BuildContext c) =>
      CustomPaint(size: Size.square(size), painter: MarkPainter());
}

class MarkPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 32, s.height / 32);
    final p = Paint()..color = acid;
    c.drawPath(
      Path()
        ..moveTo(4, 5)
        ..lineTo(15, 5)
        ..lineTo(23, 15)
        ..lineTo(17, 23)
        ..close(),
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(24, 7)
        ..lineTo(31, 7)
        ..lineTo(17, 29)
        ..lineTo(12, 23)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(MarkPainter old) => false;
}

class Art extends StatelessWidget {
  const Art(this.store, this.skin, {super.key});
  final Store store;
  final Skin skin;
  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext c, Object e, StackTrace? st) =>
        Center(child: Icon(Icons.image_outlined, color: fog.withAlpha(125)));
    if (store.bundled.contains(skin.id)) {
      return Image.asset(
        'assets/art/${skin.id}.webp',
        fit: BoxFit.contain,
        errorBuilder: fallback,
        excludeFromSemantics: true,
      );
    }
    return skin.image.startsWith('https://')
        ? Image.network(
            skin.image,
            fit: BoxFit.contain,
            cacheWidth: 640,
            errorBuilder: fallback,
            excludeFromSemantics: true,
          )
        : fallback(context, '', null);
  }
}

class Stripes extends CustomPainter {
  const Stripes();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.white.withAlpha(16)
      ..strokeWidth = .8;
    for (double x = s.width * .33; x < s.width + s.height; x += 18) {
      c.drawLine(Offset(x, 0), Offset(x - s.height * .6, s.height), p);
    }
  }

  @override
  bool shouldRepaint(Stripes old) => false;
}

class SkinRow extends StatelessWidget {
  const SkinRow(
    this.store,
    this.skin, {
    super.key,
    required this.onTap,
    this.trailing,
    this.subtitle,
  });
  final Store store;
  final Skin skin;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? subtitle;
  @override
  Widget build(BuildContext c) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    leading: Container(
      width: 72,
      height: 50,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Art(store, skin),
    ),
    title: Text(skin.name, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(
      subtitle ?? skin.weapon,
      style: const TextStyle(color: fog, fontSize: 12),
    ),
    trailing: trailing,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.end});
  final String text;
  final Widget? end;
  @override
  Widget build(BuildContext c) => Row(
    children: [
      Expanded(child: Text(text, style: display(28))),
      if (end != null) end!,
    ],
  );
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.icon = Icons.info_outline});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: acid),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: fog, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

void message(BuildContext c, String text) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));
Future<void> favorite(BuildContext c, Store s, Skin skin) async {
  try {
    await s.toggle(skin);
  } catch (_) {
    if (c.mounted) message(c, 'Wishlist gagal disimpan. Coba lagi.');
  }
}

Future<void> photoViewer(BuildContext c, String path) => showDialog<void>(
  context: c,
  builder: (ctx) => Dialog.fullscreen(
    backgroundColor: Colors.black,
    child: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 6,
              child: Center(
                child: Image.file(
                  File(path),
                  errorBuilder: (c, e, s) =>
                      const Text('Gambar tidak bisa dibuka.'),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton.filledTonal(
              tooltip: 'Tutup foto',
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    ),
  ),
);

Future<void> details(BuildContext c, Store store, Skin skin) =>
    showModalBottomSheet<void>(
      context: c,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
          child: ListenableBuilder(
            listenable: store,
            builder: (c, _) {
              final saved = store.wishes.containsKey(skin.id);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xff353044), Color(0xff21252d)],
                      ),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Art(store, skin),
                  ),
                  const SizedBox(height: 22),
                  Text(skin.weapon.toUpperCase(), style: label(lilac)),
                  Text(skin.name, style: display(38)),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => favorite(c, store, skin),
                    icon: Icon(
                      saved
                          ? Icons.bookmark_remove_outlined
                          : Icons.bookmark_add_outlined,
                    ),
                    label: Text(
                      saved ? 'Hapus dari wishlist' : 'Simpan ke wishlist',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
