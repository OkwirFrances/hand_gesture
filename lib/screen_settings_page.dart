import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScreenSettingsPage extends StatefulWidget {
  const ScreenSettingsPage({super.key});

  @override
  State<ScreenSettingsPage> createState() => _ScreenSettingsPageState();
}

class _ScreenSettingsPageState extends State<ScreenSettingsPage> {
  bool _keepScreenOn = true;
  double _brightness = 1.0;
  String _orientation = 'auto';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _keepScreenOn = prefs.getBool('keepScreenOn') ?? true;
        _brightness = prefs.getDouble('brightness') ?? 1.0;
        _orientation = prefs.getString('orientation') ?? 'auto';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading screen settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (value.runtimeType) {
        // ignore: type_literal_in_constant_pattern
        case bool:
          await prefs.setBool(key, value);
          break;
        // ignore: type_literal_in_constant_pattern
        case double:
          await prefs.setDouble(key, value);
          break;
        // ignore: type_literal_in_constant_pattern
        case String:
          await prefs.setString(key, value);
          break;
        default:
          debugPrint('Unsupported type for settings: ${value.runtimeType}');
      }
    } catch (e) {
      debugPrint('Error saving screen setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save setting')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blueAccent;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Settings'),
        elevation: 4,
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: SwitchListTile(
              activeColor: primaryColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(
                'Keep Screen On',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.grey[800],
                ),
              ),
              subtitle: Text(
                'Prevent screen from turning off',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              value: _keepScreenOn,
              onChanged: (bool value) {
                setState(() => _keepScreenOn = value);
                _saveSetting('keepScreenOn', value);
              },
            ),
          ),

          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Screen Brightness',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.grey[800],
                    ),
                  ),
                  Slider(
                    value: _brightness,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    activeColor: primaryColor,
                    label: '${(_brightness * 100).round()}%',
                    onChanged: (double value) {
                      setState(() => _brightness = value);
                      _saveSetting('brightness', value);
                    },
                  ),
                ],
              ),
            ),
          ),

          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(
                'Screen Orientation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.grey[800],
                ),
              ),
              subtitle: DropdownButton<String>(
                value: _orientation,
                isExpanded: true,
                underline: const SizedBox(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _orientation = newValue);
                    _saveSetting('orientation', newValue);
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Auto-rotate')),
                  DropdownMenuItem(value: 'portrait', child: Text('Portrait')),
                  DropdownMenuItem(
                    value: 'landscape',
                    child: Text('Landscape'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'These settings affect how the presentation screen behaves.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
