import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/strings.dart';
import 'features/todo/ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ShiguangApp()));
}

class ShiguangApp extends StatelessWidget {
  const ShiguangApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: S.appName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.create(Brightness.light),
    darkTheme: AppTheme.create(Brightness.dark),
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const HomeScreen(),
  );
}
