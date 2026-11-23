import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data.dart';
import 'design.dart';
import 'home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: panel,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const DropwatchApp());
}

class DropwatchApp extends StatelessWidget {
  const DropwatchApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dropwatch',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    locale: const Locale('id'),
    supportedLocales: const [Locale('id')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const Boot(),
  );
}

class Boot extends StatefulWidget {
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  late Future<Store> startup;
  @override
  void initState() {
    super.initState();
    startup = load();
  }

  Future<Store> load() async {
    final path = await bridge.invokeMethod<String>('directory');
    final store = Store(Directory(path!));
    await store.load();
    if (store.lastSync == null ||
        DateTime.now().difference(store.lastSync!) > const Duration(days: 1)) {
      unawaited(store.refresh());
    }
    return store;
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<Store>(
    future: startup,
    builder: (c, s) {
      if (s.hasData) return Home(s.data!);
      if (s.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Data perangkat belum bisa dibuka.'),
                  TextButton(
                    onPressed: () => setState(() => startup = load()),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: Emblem(size: 64)));
    },
  );
}
