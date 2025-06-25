import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A scrollable landing page for Mates.
class LandingPage extends StatelessWidget {
  const LandingPage({Key? key}) : super(key: key);

  Future<void> _launchStore(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFE8F5E9);
    const primaryDark = Color(0xFF388E3C);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar
              Container(
                height: 56,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Image.asset('assets/justlogo.png', height: 45),
                    const SizedBox(width: 8),
                    const Text(
                      'Mates',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              // Hero section
              Column(
                children: [
                  // 1st section with "Find Your Perfect Roommate" text
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 120,
                    ),
                    color: backgroundColor,
                    child: SizedBox(
                      height: 400,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              children: [
                                const TextSpan(text: 'Find Your Perfect '),
                                TextSpan(
                                  text: 'Roommate',
                                  style: const TextStyle(color: primaryDark),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Connect with verified, compatible people who share your lifestyle and interests. Make roommate searching simple, safe, and social.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              ElevatedButton(
                                onPressed:
                                    () => _launchStore(
                                      'https://play.google.com/store/apps/details?id=com.mates.app',
                                    ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryDark,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  'Start Matching',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryDark,
                                  side: const BorderSide(color: primaryDark),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  'Learn More',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 2nd section with "Why Choose Mates?" text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 120),
                    color: backgroundColor,
                    child: SizedBox(
                      height: 480,
                      child: Column(
                        children: [
                          const Text(
                            'Why Choose Mates?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'We make finding the right roommate simple with smart matching, verification, and intuitive features',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Row(
                            children: [
                              Expanded(
                                child: FeatureBox(
                                  icon: Icons.search,
                                  title: 'Smart Matching',
                                  description:
                                      'Our algorithm matches you with compatible roommates based on lifestyle, interests, location, and living preferences.',
                                  primaryColor: primaryDark,
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                child: FeatureBox(
                                  icon: Icons.shield,
                                  title: 'Verified & Safe',
                                  description:
                                      'All profiles are verified for phone, email, and identity confirmation. We maintain a safe, respectful community.',
                                  primaryColor: primaryDark,
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                child: FeatureBox(
                                  icon: Icons.chat,
                                  title: 'Easy Communication',
                                  description:
                                      'Chat directly with potential roommates in a secure environment before making important decisions.',
                                  primaryColor: primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 3rd section with "Verified Community" text
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 120,
                    ),
                    color: Colors.white,
                    child: SizedBox(
                      height: 400,
                      child: Column(
                        children: [
                          const Text(
                            'Verified Community',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Every member goes through our comprehensive verification process',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Row(
                            children: [
                              const SizedBox(width: 16),
                              Expanded(
                                child: FeatureBox(
                                  icon: Icons.looks_one,
                                  title: 'Phone Verification',
                                  description:
                                      'Verify your phone number with a secure SMS code',
                                  primaryColor: primaryDark,
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                child: FeatureBox(
                                  icon: Icons.looks_two,
                                  title: 'Email Verification',
                                  description:
                                      'Confirm your email address for account security and communication',
                                  primaryColor: primaryDark,
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                child: FeatureBox(
                                  icon: Icons.looks_3,
                                  title: 'Profile Review',
                                  description:
                                      'Our team reviews your profile and photos to ensure authenticity',
                                  primaryColor: primaryDark,
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                child: FeatureBox(
                                  icon: Icons.verified,
                                  title: 'Verified Badge',
                                  description:
                                      'Get your verified badge and start matching with confidence',
                                  primaryColor: primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color primaryColor;

  const FeatureBox({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: primaryColor),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
