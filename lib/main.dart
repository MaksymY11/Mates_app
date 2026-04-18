import 'package:firebase_core/firebase_core.dart';
import 'package:mates/services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'login_page.dart';
import 'home_page.dart';
// import 'landing_page.dart';

/// App entry point. Initializes Flutter bindings, conditionally boots Firebase on platforms that support FCM
/// (Android/iOS/web — desktop is skipped to avoid native plugin crashes), then mounts [MyApp].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (PushNotificationService.isSupported) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const MyApp());
}

/// Startup gate shown briefly on cold launch while [_checkAuth] decides where to route the user.
/// Fetches /me with the stored token and navigates to [HomeShell] (verified) or [LoginPage] (unverified,
/// unauthenticated, or error).
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  // Probes /me with the stored access token to decide startup routing. Verified users land on [HomeShell].
  /// Unverified users (abandoned mid-verification) are logged out and sent to [LoginPage], reopening the app
  /// after a break shouldn't drop them mid-flow. Any failure (no token, expired, network error) also routes to
  /// [LoginPage]. All navigation uses pushReplacement so the splash never stays in the back stack.
  Future<void> _checkAuth() async {
    try {
      final me = await ApiService.get('/me');

      if (mounted) {
        if (me['email_verified'] == true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeShell()),
          );
        } else {
          await AuthService.logout();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
      }
    }
  }

  /// Placeholder UI displayed while [_checkAuth] runs: a centered spinner. Replaced immediately once routing completes.
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
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
      home: const _SplashGate(),
    );
  }
}
