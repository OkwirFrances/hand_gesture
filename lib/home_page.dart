import 'package:flutter/material.dart';
import 'gesture_control_page.dart';
import 'screen_settings_page.dart';
import 'settings_page.dart';
import 'about_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EDUSENSE'),
        elevation: 2,
        centerTitle: true,
        leading: const Icon(Icons.home),
      ),
      body: Stack(
        children: [
          // Background image (more visible)
          Positioned.fill(
            child: Image.asset(
              'assets/images/mj2.webp', // <-- your background image path
              fit: BoxFit.cover,
            ),
          ),

          // Semi-transparent overlay for readability (reduced opacity to show image)
          // ignore: deprecated_member_use
          Container(color: Colors.white.withOpacity(0.2)),

          // Main content
          Column(
            children: [
              const SizedBox(height: 30),

              // Enhanced Jumbotron
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(0.85),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 30,
                      horizontal: 20,
                    ),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.shade700,
                            boxShadow: [
                              BoxShadow(
                                // ignore: deprecated_member_use
                                color: Colors.blue.shade200.withOpacity(0.6),
                                blurRadius: 15,
                                spreadRadius: 5,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: const Icon(
                            Icons.touch_app,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Gesture Control',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            shadows: [
                              Shadow(
                                blurRadius: 8,
                                color: Colors.black12,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Control presentations with intuitive gestures',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Expanded(child: Container()),

              // Navigation buttons with spacing
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavButton(
                      context,
                      icon: Icons.gesture,
                      label: 'Gestures',
                      color: Colors.blue.shade600,
                      destination: const GestureControlPage(),
                    ),
                    const SizedBox(width: 12),
                    _buildNavButton(
                      context,
                      icon: Icons.settings_display,
                      label: 'Screen',
                      color: Colors.green.shade600,
                      destination: const ScreenSettingsPage(),
                    ),
                    const SizedBox(width: 12),
                    _buildNavButton(
                      context,
                      icon: Icons.settings,
                      label: 'Settings',
                      color: Colors.orange.shade600,
                      destination: const SettingsPage(),
                    ),
                    const SizedBox(width: 12),
                    _buildNavButton(
                      context,
                      icon: Icons.info,
                      label: 'About',
                      color: Colors.purple.shade600,
                      destination: const AboutPage(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Widget destination,
  }) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size(60, 70),
          elevation: 4,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
