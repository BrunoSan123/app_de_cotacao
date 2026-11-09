import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/brapi_service.dart';
import 'state/trade_sim_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  final dotenvToken = dotenv.env['BRAPI_TOKEN']?.trim();
  final token = dotenvToken == null || dotenvToken.isEmpty
      ? const String.fromEnvironment('BRAPI_TOKEN')
      : dotenvToken;

  runApp(
    ChangeNotifierProvider(
      create: (_) => TradeSimController(
        brapiService: BrapiService(token: token),
      )..initialize(),
      child: const TradeSimApp(),
    ),
  );
}

class TradeSimApp extends StatelessWidget {
  const TradeSimApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF087F5B);
    return MaterialApp(
      title: 'TradeSim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
          surface: const Color(0xFFF7F9F8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F9F8),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE9EFEC)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1E9E5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1E9E5)),
          ),
        ),
      ),
      home: Consumer<TradeSimController>(
        builder: (context, controller, _) {
          if (controller.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return controller.user == null
              ? const AuthScreen()
              : const HomeScreen();
        },
      ),
    );
  }
}
