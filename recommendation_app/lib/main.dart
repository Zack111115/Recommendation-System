import 'package:flutter/material.dart';

import 'models/demo_account.dart';
import 'screens/login_screen.dart';
import 'screens/store_shell.dart';
import 'services/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    RecommendationApp(
      auth: AuthController(),
    ),
  );
}

class RecommendationApp extends StatelessWidget {
  final AuthController auth;

  const RecommendationApp({
    super.key,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RecommendationSystem',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6558E8),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        fontFamily: 'Segoe UI',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F7FB),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6558E8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: ValueListenableBuilder<DemoAccount?>(
        valueListenable: auth.currentAccount,
        builder: (context, account, _) {
          if (account == null) {
            return LoginScreen(auth: auth);
          }

          return StoreShell(
            key: ValueKey(account.id),
            auth: auth,
            account: account,
          );
        },
      ),
    );
  }
}