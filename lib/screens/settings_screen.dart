import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool swipeGestureEnabled = true;
  bool pinchGestureEnabled = true;
  double gestureSensitivity = 0.5;
  String theme = 'System';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Enable Swipe Gesture'),
            value: swipeGestureEnabled,
            onChanged: (bool value) {
              setState(() {
                swipeGestureEnabled = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Enable Pinch Gesture'),
            value: pinchGestureEnabled,
            onChanged: (bool value) {
              setState(() {
                pinchGestureEnabled = value;
              });
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Gesture Sensitivity',
            style: Theme.of(context).textTheme.titleMedium,
          ),

          Slider(
            value: gestureSensitivity,
            min: 0,
            max: 1,
            divisions: 10,
            label: (gestureSensitivity * 100).round().toString(),
            onChanged: (double value) {
              setState(() {
                gestureSensitivity = value;
              });
            },
          ),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('Theme'),
            trailing: DropdownButton<String>(
              value: theme,
              items:
                  <String>['Light', 'Dark', 'System'].map((String value) {
                    return DropdownMenuItem(value: value, child: Text(value));
                  }).toList(),
              onChanged: (String? newTheme) {
                if (newTheme != null) {
                  setState(() {
                    theme = newTheme;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement calibration logic here
              showDialog(
                context: context,
                builder:
                    (_) => AlertDialog(
                      title: const Text('Calibration'),
                      content: const Text('Gesture calibration started!'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
              );
            },
            child: const Text('Calibrate Gestures'),
          ),
        ],
      ),
    );
  }
}
