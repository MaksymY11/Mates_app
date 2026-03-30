import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'login_page.dart';
import 'landing_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF4CAF50);
    const brandLight = Color(0xFF7CFF7C);

    return MaterialApp(
      navigatorKey: ApiService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Mates',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brand,
        ).copyWith(primary: brand, secondary: brandLight),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: brandLight,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: brand,
            side: const BorderSide(color: brandLight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: brand),
      ),
      home: LoginPage(),
    );
  }
}
