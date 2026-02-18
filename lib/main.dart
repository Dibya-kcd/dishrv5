import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data/repository.dart';
import 'firebase_options.dart';
import 'providers/restaurant_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/employee_provider.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Suppress the 'flutter/lifecycle' channel overflow warning during long initialization.
  // This happens when engine events occur before runApp() is called.
  if (!kIsWeb) {
    DartPluginRegistrant.ensureInitialized();
  }
  ChannelBuffers().allowOverflow('flutter/lifecycle', true);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await FirebaseAppCheck.instance.activate();
  } catch (_) {}

  await Repository.instance.init();
  // Automatic seeding disabled to prevent unwanted duplicate sample data.
  // Use System Diagnostics to seed sample data manually if needed.
  // await ensureSampleEmployees();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RestaurantProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()..loadExpenses()),
        ChangeNotifierProvider(create: (_) => EmployeeProvider()..loadEmployees()..checkAndGenerateSalaries()),
      ],
      child: const TheDishApp(),
    ),
  );
}

class TheDishApp extends StatelessWidget {
  const TheDishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Dish',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF9500),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF2A2A2A),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
        ),
        cardColor: const Color(0xFF2A2A2A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ).copyWith(
          titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          titleMedium: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0),
          bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0),
          bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0),
          labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ).copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        }),
      ),
      home: const LoginScreen(),
    );
  }
}
