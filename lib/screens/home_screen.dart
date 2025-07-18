import 'package:flutter/material.dart';
import '../styles/app_styles.dart'; // Import your styles here

class HomeScreen extends StatelessWidget {
  final String groupName = 'Gesture Control Group';
  final String appPurpose =
      'Empowering inclusive learning through gesture recognition';
  const HomeScreen({super.key}); // <-- here

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppStyles.appBarColor,
        title: Text('Smart Lecture Assistant', style: AppStyles.jumbotronTitle),
        actions: [
          IconButton(
            icon: Icon(Icons.pan_tool_alt),
            tooltip: 'Gesture Detection',
            onPressed: () {
              Navigator.pushNamed(context, '/gesture');
            },
          ),
          IconButton(
            icon: Icon(Icons.sign_language),
            tooltip: 'Sign Language Translator',
            onPressed: () {
              Navigator.pushNamed(context, '/translator');
            },
          ),
          IconButton(
            icon: Icon(Icons.present_to_all),
            tooltip: 'Projector Control',
            onPressed: () {
              Navigator.pushNamed(context, '/projector');
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),

      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Jumbotron
          Container(
            margin: EdgeInsets.all(20),
            padding: EdgeInsets.all(30),
            decoration: AppStyles.jumbotronBox, // Use your BoxDecoration here
            child: Column(
              children: [
                Text(
                  groupName,
                  style: AppStyles.jumbotronTitle, // Use your TextStyle here
                ),
                SizedBox(height: 10),
                Text(
                  appPurpose,
                  textAlign: TextAlign.center,
                  style: AppStyles.jumbotronText, // Use your TextStyle here
                ),
              ],
            ),
          ),

          Spacer(),

          // Footer
          BottomNavigationBar(
            backgroundColor: AppStyles.footerColor, // Use footer color here
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.info_outline),
                label: 'About',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.help_outline),
                label: 'Help',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.contact_mail),
                label: 'Contact',
              ),
            ],
            onTap: (index) {
              // Handle footer taps if needed
            },
          ),
        ],
      ),
    );
  }
}
