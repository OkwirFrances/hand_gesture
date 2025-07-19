import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SettingsPage extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeChanged;
  final ValueChanged<bool>? onNotificationChanged;

  const SettingsPage({
    super.key,
    this.onThemeChanged,
    this.onNotificationChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _notifications = true;
  double _sensitivity = 0.5;
  bool _isLoading = true;
  String _serverIp = '';
  String _serverPort = '5000';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _darkMode = prefs.getBool('darkMode') ?? false;
        _notifications = prefs.getBool('notifications') ?? true;
        _sensitivity = prefs.getDouble('sensitivity') ?? 0.5;
        _serverIp = prefs.getString('serverIp') ?? '';
        _serverPort = prefs.getString('serverPort') ?? '5000';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
        if (key == 'darkMode') {
          widget.onThemeChanged?.call(value ? ThemeMode.dark : ThemeMode.light);
        } else if (key == 'notifications') {
          widget.onNotificationChanged?.call(value);
        }
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else {
        debugPrint('Unsupported type for settings: ${value.runtimeType}');
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save setting')));
      }
    }
  }

  Future<void> _testConnection() async {
    final uri = Uri.parse('http://$_serverIp:$_serverPort/status');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        _showSnackbar('Connection successful ✅');
      } else {
        _showSnackbar('Connection failed ❌');
      }
    } catch (e) {
      _showSnackbar('Connection error: $e');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 2,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueGrey, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          children: [
            // Server IP input
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.router, color: Colors.blue),
                title: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Server IP Address',
                    border: InputBorder.none,
                  ),
                  controller: TextEditingController(text: _serverIp),
                  onChanged: (value) {
                    _serverIp = value;
                    _saveSetting('serverIp', value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Server Port input
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.settings_ethernet,
                  color: Colors.green,
                ),
                title: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Server Port',
                    border: InputBorder.none,
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: _serverPort),
                  onChanged: (value) {
                    _serverPort = value;
                    _saveSetting('serverPort', value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Test connection button
            ElevatedButton.icon(
              onPressed: _testConnection,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Test Connection'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const Divider(height: 40),

            // Dark mode toggle
            SwitchListTile(
              title: const Text('Dark Mode'),
              secondary: const Icon(Icons.dark_mode),
              value: _darkMode,
              onChanged: (value) {
                setState(() => _darkMode = value);
                _saveSetting('darkMode', value);
              },
            ),
            const Divider(),

            // Notifications toggle
            SwitchListTile(
              title: const Text('Notifications'),
              secondary: const Icon(Icons.notifications),
              value: _notifications,
              onChanged: (value) {
                setState(() => _notifications = value);
                _saveSetting('notifications', value);
              },
            ),
            const Divider(),

            // Gesture sensitivity slider
            ListTile(
              leading: const Icon(Icons.touch_app, color: Colors.orange),
              title: const Text('Gesture Sensitivity'),
              subtitle: Slider(
                value: _sensitivity,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: '${(_sensitivity * 100).round()}%',
                onChanged: (value) {
                  setState(() => _sensitivity = value);
                  _saveSetting('sensitivity', value);
                },
              ),
            ),

            const SizedBox(height: 30),

            // App version
            const Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
