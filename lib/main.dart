import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'services/remote_config_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');

  final remote = RemoteConfigService();
  await remote.loadCached(); // آخر إعدادات محفوظة (يعمل بدون إنترنت)

  runApp(TodoApp(remote: remote));
}

class TodoApp extends StatelessWidget {
  final RemoteConfigService remote;
  const TodoApp({super.key, required this.remote});

  @override
  Widget build(BuildContext context) {
    // كل ما يتغيّر في config.json على GitHub يعيد بناء التطبيق تلقائياً.
    return ListenableBuilder(
      listenable: remote,
      builder: (context, _) {
        final cfg = remote.config;
        return MaterialApp(
          title: cfg.appTitle,
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: cfg.flutterThemeMode,
          theme: ThemeData(
            colorSchemeSeed: cfg.primaryColor,
            brightness: Brightness.light,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: cfg.primaryColor,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          home: HomeScreen(remote: remote),
        );
      },
    );
  }
}
