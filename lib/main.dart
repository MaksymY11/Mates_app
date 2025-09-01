import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mates/home_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'landing_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF7CFF7C); // same as login button

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mates',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brand,
        ).copyWith(primary: brand, secondary: brand),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: brand,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: brand,
            side: const BorderSide(color: brand),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: brand),
      ),
      home: kIsWeb ? const LandingPage() : LoginPage(),
      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomeShell(),
      },
    );
  }
}
