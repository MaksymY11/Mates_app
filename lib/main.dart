import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mates',
      home: kIsWeb ? const LandingPage() : LoginPage(),
      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => const SignUpPage(),
      },
    );
  }
}
