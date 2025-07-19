import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<PackageInfo> _getPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  void _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blueAccent;

    return Scaffold(
      appBar: AppBar(title: const Text('About Edusense'), elevation: 2),
      body: FutureBuilder<PackageInfo>(
        future: _getPackageInfo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final version = snapshot.data?.version ?? '1.0.0';
          final buildNumber = snapshot.data?.buildNumber ?? '1';

          return SingleChildScrollView(
            child: Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon and Name
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: primaryColor,
                        child: const Icon(
                          Icons.gesture,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Edusense',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Version $version (Build $buildNumber)',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 4,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Edusense is a gesture-controlled mobile app that lets you effortlessly control your presentation slides using simple swipes and taps. Designed to keep presenters mobile and engaged, it empowers you to move freely while seamlessly navigating your slides projected on any screen.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Developer Info
                  _sectionTitle('Developer / Company Info'),
                  _infoTile('Developer', 'GROUP 32 MAKERERE UNIVERSITY'),
                  _linkTile(
                    'Email',
                    'support@edusense.com',
                    'mailto:support@edusense.com',
                  ),
                  _linkTile(
                    'Website',
                    'www.edusense.com',
                    'https://www.edusense.com',
                  ),
                  _linkTile(
                    'Twitter',
                    '@EdusenseApp',
                    'https://twitter.com/EdusenseApp',
                  ),
                  _linkTile(
                    'LinkedIn',
                    'Edusense Company',
                    'https://linkedin.com/company/edusense',
                  ),

                  const SizedBox(height: 24),

                  // Features Summary
                  _sectionTitle('App Features Summary'),
                  _bulletPoint('Swipe left/right to navigate slides'),
                  _bulletPoint('Swipe up to start the presentation'),
                  _bulletPoint('Swipe down to end the presentation'),
                  _bulletPoint('Tap to pause or resume slides'),
                  _bulletPoint('Double tap to blackout/unblackout screen'),
                  _bulletPoint('Promotes presenter mobility and engagement'),

                  const SizedBox(height: 24),

                  // Privacy Policy
                  _sectionTitle('Privacy Policy / Terms of Use'),
                  const Text(
                    'We respect your privacy. Edusense collects minimal data necessary for app functionality.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _linkTile(
                    'Privacy Policy',
                    'View here',
                    'https://www.edusense.com/privacy',
                  ),
                  _linkTile(
                    'Terms & Conditions',
                    'View here',
                    'https://www.edusense.com/terms',
                  ),

                  const SizedBox(height: 24),

                  // Licenses
                  TextButton(
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'Edusense',
                        applicationVersion: version,
                      );
                    },
                    child: const Text('View Licenses'),
                  ),

                  const SizedBox(height: 24),

                  // Copyright
                  const Text(
                    '© 2025 Edusense\nAll rights reserved',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper widget for section titles
  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  // Helper widget for bullet points
  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 20, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  // Helper widget for info tiles
  Widget _infoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  // Helper widget for link tiles
  Widget _linkTile(String title, String display, String url) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              '$title: ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Expanded(
              child: Text(
                display,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blueAccent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
