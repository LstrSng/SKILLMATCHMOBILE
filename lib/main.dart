import 'package:flutter/material.dart';
import 'pages/splash_page.dart';
import 'services/session_store.dart';
import 'services/theme_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionStore.load();
  themeNotifier.value = await ThemeStore.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'SkillMatch+',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          // Clamp text scale so layouts don't break on accessibility/large-font devices.
          // Also ensures consistent sizing across small (4") and large (7"+) screens.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(
                  mq.textScaler.scale(1.0).clamp(0.85, 1.15),
                ),
              ),
              child: child!,
            );
          },
          theme: buildAppTheme(),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF111827),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1F2937),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            cardColor: const Color(0xFF1F2937),
          ),
          home: const SplashPage(),
        );
      },
    );
  }
}
