import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'models/app_settings.dart';

// Tworzymy globalny powiadamiacz o zmianie motywu
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pl_PL', null);

  // Wczytujemy ustawienia przy starcie, żeby wiedzieć jaki motyw włączyć
  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString('app_settings');
  if (data != null) {
    final settings = AppSettings.fromJson(jsonDecode(data));
    themeNotifier.value = settings.isDarkMode
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  runApp(const WorkScheduleApp());
}

class WorkScheduleApp extends StatelessWidget {
  const WorkScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder sprawia, że apka przebuduje się po zmianie themeNotifier
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Grafik Pracy',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode, // To steruje motywem
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pl', 'PL')],
          home: const HomeScreen(),
        );
      },
    );
  }
}
