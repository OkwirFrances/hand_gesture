import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GestureControlPage extends StatefulWidget {
  const GestureControlPage({super.key});

  @override
  State<GestureControlPage> createState() => _GestureControlPageState();
}

class _GestureControlPageState extends State<GestureControlPage> {
  String? _serverIp;
  final int _serverPort = 5000;
  String _status = 'No action yet';

  @override
  void initState() {
    super.initState();
    _loadServerIp();
  }

  Future<void> _loadServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverIp = prefs.getString('serverIp');
    });
  }

  Future<void> sendCommand(String cmd) async {
    if (_serverIp == null || _serverIp!.isEmpty) {
      _updateStatus('Server IP not set. Please set it in Settings.');
      return;
    }

    final url = Uri.parse('http://$_serverIp:$_serverPort/$cmd');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        _updateStatus('Command "$cmd" sent successfully');
      } else {
        _updateStatus('Failed to send command "$cmd"');
      }
    } catch (e) {
      _updateStatus('Error sending command: $e');
    }
  }

  void _updateStatus(String action) {
    setState(() {
      _status = 'Last action: $action';
    });
    debugPrint('Action: $action');
  }

  Widget _buildGestureArea() {
    return GestureDetector(
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;

        if (velocity.dx.abs() > velocity.dy.abs()) {
          if (velocity.dx > 0) {
            sendCommand('previous');
          } else {
            sendCommand('next');
          }
        } else {
          if (velocity.dy > 0) {
            sendCommand('end');
          } else {
            sendCommand('start');
          }
        }
      },
      onTap: () => sendCommand('pause'),
      onDoubleTap: () => sendCommand('blackout'),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF90CAF9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Text(
            'Try gestures:\n'
            'Swipe Left → Next Slide\n'
            'Swipe Right → Previous Slide\n'
            'Swipe Up → Start Presentation\n'
            'Swipe Down → End Presentation\n'
            'Tap → Pause/Resume\n'
            'Double Tap → Blackout Screen',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 6,
                  color: Colors.black45,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      backgroundColor: Colors.blue.shade700,
    );

    return Container(
      color: Colors.grey.shade100,
      child: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(20),
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        children: [
          ElevatedButton.icon(
            style: buttonStyle,
            onPressed: () => sendCommand('start'),
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: const Text(
              'Start\nPresentation',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
          ElevatedButton.icon(
            style: buttonStyle.copyWith(
              // ignore: deprecated_member_use
              backgroundColor: MaterialStateProperty.all(Colors.red.shade700),
            ),
            onPressed: () => sendCommand('end'),
            icon: const Icon(Icons.stop, color: Colors.white),
            label: const Text(
              'End\nPresentation',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
          ElevatedButton.icon(
            style: buttonStyle.copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.black87),
            ),
            onPressed: () => sendCommand('blackout'),
            icon: const Icon(Icons.visibility_off, color: Colors.white),
            label: const Text(
              'Blackout\nScreen',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
          ElevatedButton.icon(
            style: buttonStyle.copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.orange.shade800),
            ),
            onPressed: () => sendCommand('pause'),
            icon: const Icon(Icons.pause, color: Colors.white),
            label: const Text(
              'Pause/\nResume',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gesture Control'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
      ),
      body: Column(
        children: [
          Expanded(child: _buildGestureArea()),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _status,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(child: _buildControlButtons()),
        ],
      ),
    );
  }
}
