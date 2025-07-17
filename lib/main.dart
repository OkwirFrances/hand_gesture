import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:hand_landmarker/hand_landmarker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gesture Slide Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const GestureControllerView(),
    );
  }
}

class GestureControllerView extends StatefulWidget {
  const GestureControllerView({super.key});

  @override
  State<GestureControllerView> createState() => _GestureControllerViewState();
}

class _GestureControllerViewState extends State<GestureControllerView> {
  HandLandmarkerPlugin? _plugin;
  CameraController? _controller;
  List<Hand> _landmarks = [];
  bool _isInitialized = false;
  bool _isDetecting = false;
  bool _isConnected = false;
  bool _gestureControlEnabled = true;
  
  // PC connection settings
  String _pcIP = '192.168.43.6';
  int _pcPort = 8080;
  
  // Gesture detection variables
  String _currentGesture = 'None';
  String _lastAction = 'None';
  DateTime _lastGestureTime = DateTime.now();
  int _gestureCount = 0;
  final int _minGestureFrames = 8;
  final Duration _gestureCooldown = const Duration(milliseconds: 2000);
  
  // Statistics
  int _nextSlideCount = 0;
  int _previousSlideCount = 0;
  int _startPresentationCount = 0;
  int _endPresentationCount = 0;
  int _pauseResumeCount = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Get available cameras and select front camera
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      // Create plugin instance (synchronous in v2.0.0)
      _plugin = HandLandmarkerPlugin.create();

      // Initialize camera and start image stream
      await _controller!.initialize();
      await _controller!.startImageStream(_processCameraImage);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    // Dispose is now synchronous in v2.0.0
    _plugin?.dispose();
    super.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    // Guard to prevent processing multiple frames at once
    if (_isDetecting || !_isInitialized || _plugin == null || !_gestureControlEnabled) return;

    _isDetecting = true;

    try {
      // The detect method is synchronous in v2.0.0
      final hands = _plugin!.detect(
        image,
        _controller!.description.sensorOrientation,
      );
      
      if (mounted) {
        setState(() {
          _landmarks = hands;
        });
        
        // Process gestures if hands are detected
        if (hands.isNotEmpty) {
          _detectGesture(hands.first);
        } else {
          _resetGestureDetection();
        }
      }
    } catch (e) {
      debugPrint('Error detecting landmarks: $e');
    } finally {
      _isDetecting = false;
    }
  }

  void _detectGesture(Hand hand) {
    if (hand.landmarks.length < 21) return;

    String detectedGesture = _classifyGesture(hand.landmarks);
    
    if (detectedGesture == _currentGesture) {
      _gestureCount++;
    } else {
      _currentGesture = detectedGesture;
      _gestureCount = 1;
    }

    // Execute gesture if confirmed and cooldown has passed
    if (_gestureCount >= _minGestureFrames && 
        DateTime.now().difference(_lastGestureTime) > _gestureCooldown) {
      _executeGesture(detectedGesture);
    }
  }

  String _classifyGesture(List<Landmark> landmarks) {
    // Key landmark indices based on MediaPipe hand model
    final thumbTip = landmarks[4];
    final thumbIP = landmarks[3];
    final indexTip = landmarks[8];
    final indexPIP = landmarks[6];
    final middleTip = landmarks[12];
    final middlePIP = landmarks[10];
    final ringTip = landmarks[16];
    final ringPIP = landmarks[14];
    final pinkyTip = landmarks[20];
    final pinkyPIP = landmarks[18];
    
    // Wrist reference point
    final wrist = landmarks[0];
    
    // Calculate if fingers are extended (tip is higher than middle joint)
    bool thumbUp = thumbTip.y < thumbIP.y && thumbTip.y < wrist.y;
    bool indexUp = indexTip.y < indexPIP.y;
    bool middleUp = middleTip.y < middlePIP.y;
    bool ringUp = ringTip.y < ringPIP.y;
    bool pinkyUp = pinkyTip.y < pinkyPIP.y;
    
    // Count extended fingers
    int extendedFingers = 0;
    if (thumbUp) extendedFingers++;
    if (indexUp) extendedFingers++;
    if (middleUp) extendedFingers++;
    if (ringUp) extendedFingers++;
    if (pinkyUp) extendedFingers++;
    
    // Gesture classification with improved accuracy
    if (thumbUp && !indexUp && !middleUp && !ringUp && !pinkyUp) {
      return 'Thumbs Up';
    } else if (extendedFingers == 0) {
      return 'Fist';
    } else if (!thumbUp && indexUp && !middleUp && !ringUp && !pinkyUp) {
      return 'Point';
    } else if (!thumbUp && indexUp && middleUp && !ringUp && !pinkyUp) {
      return 'Peace';
    } else if (extendedFingers == 5) {
      return 'Open Palm';
    } else if (!thumbUp && !indexUp && !middleUp && !ringUp && pinkyUp) {
      return 'Pinky';
    }
    
    return 'None';
  }

  void _resetGestureDetection() {
    _currentGesture = 'None';
    _gestureCount = 0;
  }

  Future<void> _executeGesture(String gesture) async {
    if (!_isConnected) return;
    
    _lastGestureTime = DateTime.now();
    _resetGestureDetection();
    
    String action = '';
    switch (gesture) {
      case 'Thumbs Up':
        action = 'start_presentation';
        _startPresentationCount++;
        break;
      case 'Fist':
        action = 'end_presentation';
        _endPresentationCount++;
        break;
      case 'Point':
        action = 'next_slide';
        _nextSlideCount++;
        break;
      case 'Peace':
        action = 'previous_slide';
        _previousSlideCount++;
        break;
      case 'Open Palm':
        action = 'pause_resume';
        _pauseResumeCount++;
        break;
      case 'Pinky':
        action = 'laser_pointer';
        break;
    }
    
    if (action.isNotEmpty) {
      await _sendCommand(action);
      setState(() {
        _lastAction = action.replaceAll('_', ' ').toUpperCase();
      });
      
      // Provide haptic feedback
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _sendCommand(String command) async {
    try {
      final response = await http.post(
        Uri.parse('http://$_pcIP:$_pcPort/gesture'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'command': command,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        debugPrint('Command sent successfully: $command');
      } else {
        debugPrint('Failed to send command: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending command: $e');
      setState(() {
        _isConnected = false;
      });
    }
  }

  Future<void> _testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('http://$_pcIP:$_pcPort/ping'),
      ).timeout(const Duration(seconds: 5));
      
      setState(() {
        _isConnected = response.statusCode == 200;
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isConnected ? 'Connected to PC successfully!' : 'Failed to connect to PC'),
          backgroundColor: _isConnected ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSettingsDialog() {
    final ipController = TextEditingController(text: _pcIP);
    final portController = TextEditingController(text: _pcPort.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PC Connection Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'PC IP Address',
                hintText: '192.168.43.6',
                prefixIcon: Icon(Icons.computer),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '8080',
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _pcIP = ipController.text.trim();
              _pcPort = int.tryParse(portController.text.trim()) ?? 8080;
              Navigator.pop(context);
              _testConnection();
            },
            child: const Text('Test Connection'),
          ),
        ],
      ),
    );
  }

  void _showGestureGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gesture Guide'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('👍 Thumbs Up: Start Presentation'),
            Text('✊ Fist: End Presentation'),
            Text('👉 Point: Next Slide'),
            Text('✌️ Peace: Previous Slide'),
            Text('🖐️ Open Palm: Pause/Resume'),
            Text('🤙 Pinky: Laser Pointer'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing camera...'),
            ],
          ),
        ),
      );
    }

    final controller = _controller!;
    final previewSize = controller.value.previewSize!;
    final previewAspectRatio = previewSize.height / previewSize.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gesture Slide Controller'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showGestureGuide,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
              border: Border(
                bottom: BorderSide(
                  color: _isConnected ? Colors.green : Colors.red,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.wifi : Icons.wifi_off,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected ? 'Connected to $_pcIP:$_pcPort' : 'Disconnected',
                      style: TextStyle(
                        color: _isConnected ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Gesture Control'),
                    const SizedBox(width: 8),
                    Switch(
                      value: _gestureControlEnabled,
                      onChanged: (value) {
                        setState(() {
                          _gestureControlEnabled = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Camera preview with gesture overlay
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: AspectRatio(
                aspectRatio: previewAspectRatio,
                child: Stack(
                  children: [
                    CameraPreview(controller),
                    CustomPaint(
                      size: Size.infinite,
                      painter: GesturePainter(
                        hands: _landmarks,
                        previewSize: previewSize,
                        lensDirection: controller.description.lensDirection,
                        sensorOrientation: controller.description.sensorOrientation,
                      ),
                    ),
                    // Gesture status overlay
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _currentGesture != 'None' ? Icons.pan_tool : Icons.back_hand,
                              color: _currentGesture != 'None' ? Colors.green : Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _currentGesture,
                              style: TextStyle(
                                color: _currentGesture != 'None' ? Colors.green : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Gesture confirmation progress
                    if (_gestureCount > 0 && _currentGesture != 'None')
                      Positioned(
                        top: 60,
                        left: 16,
                        child: Container(
                          width: 100,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: LinearProgressIndicator(
                            value: _gestureCount / _minGestureFrames,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          // Control panel
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Last action display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.touch_app, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Last Action: $_lastAction',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Statistics grid
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        _buildStatCard('Next', _nextSlideCount, Icons.arrow_forward, Colors.green),
                        _buildStatCard('Previous', _previousSlideCount, Icons.arrow_back, Colors.orange),
                        _buildStatCard('Start', _startPresentationCount, Icons.play_arrow, Colors.blue),
                        _buildStatCard('End', _endPresentationCount, Icons.stop, Colors.red),
                        _buildStatCard('Pause', _pauseResumeCount, Icons.pause, Colors.purple),
                        _buildStatCard('Hands', _landmarks.length, Icons.back_hand, Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _testConnection,
        tooltip: 'Test Connection',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GesturePainter extends CustomPainter {
  GesturePainter({
    required this.hands,
    required this.previewSize,
    required this.lensDirection,
    required this.sensorOrientation,
  });

  final List<Hand> hands;
  final Size previewSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;

  @override
  void paint(Canvas canvas, Size size) {
    if (hands.isEmpty) return;
    
    final scale = size.width / previewSize.height;

    final landmarkPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4 / scale
      ..strokeCap = StrokeCap.round;

    final connectionPaint = Paint()
      ..color = Colors.lightBlue
      ..strokeWidth = 2 / scale
      ..strokeCap = StrokeCap.round;

    final fingerTipPaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 6 / scale
      ..strokeCap = StrokeCap.round;

    canvas.save();

    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sensorOrientation * math.pi / 180);

    if (lensDirection == CameraLensDirection.front) {
      canvas.scale(-1, 1);
      canvas.rotate(math.pi);
    }

    canvas.scale(scale);

    final logicalWidth = previewSize.width;
    final logicalHeight = previewSize.height;

    for (final hand in hands) {
      if (hand.landmarks.length < 21) continue;
      
      // Draw connections first
      for (final connection in HandLandmarkConnections.connections) {
        if (connection[0] < hand.landmarks.length && connection[1] < hand.landmarks.length) {
          final start = hand.landmarks[connection[0]];
          final end = hand.landmarks[connection[1]];
          final startDx = (start.x - 0.5) * logicalWidth;
          final startDy = (start.y - 0.5) * logicalHeight;
          final endDx = (end.x - 0.5) * logicalWidth;
          final endDy = (end.y - 0.5) * logicalHeight;
          
          canvas.drawLine(
            Offset(startDx, startDy),
            Offset(endDx, endDy),
            connectionPaint,
          );
        }
      }
      
      // Draw all landmarks
      for (int i = 0; i < hand.landmarks.length; i++) {
        final landmark = hand.landmarks[i];
        final dx = (landmark.x - 0.5) * logicalWidth;
        final dy = (landmark.y - 0.5) * logicalHeight;
        
        // Highlight fingertips
        final paint = [4, 8, 12, 16, 20].contains(i) ? fingerTipPaint : landmarkPaint;
        canvas.drawCircle(Offset(dx, dy), 4 / scale, paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HandLandmarkConnections {
  static const List<List<int>> connections = [
    [0, 1], [1, 2], [2, 3], [3, 4], // Thumb
    [0, 5], [5, 6], [6, 7], [7, 8], // Index finger
    [5, 9], [9, 10], [10, 11], [11, 12], // Middle finger
    [9, 13], [13, 14], [14, 15], [15, 16], // Ring finger
    [13, 17], [0, 17], [17, 18], [18, 19], [19, 20], // Pinky
  ];
}
// import 'dart:async';
// import 'dart:math' as math;
// import 'dart:convert';
// // import 'dart:isolate';
// import 'package:camera/camera.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:hand_landmarker/hand_landmarker.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Gesture Slide Controller',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         useMaterial3: true,
//       ),
//       home: const GestureControllerView(),
//     );
//   }
// }

// // Optimized data structures
// class GestureState {
//   final String gesture;
//   final int count;
//   final DateTime timestamp;
  
//   const GestureState({
//     required this.gesture,
//     required this.count,
//     required this.timestamp,
//   });
// }

// class OptimizedLandmark {
//   final double x, y;
//   const OptimizedLandmark(this.x, this.y);
// }

// class GestureControllerView extends StatefulWidget {
//   const GestureControllerView({super.key});

//   @override
//   State<GestureControllerView> createState() => _GestureControllerViewState();
// }

// class _GestureControllerViewState extends State<GestureControllerView> 
//     with WidgetsBindingObserver {
//   HandLandmarkerPlugin? _plugin;
//   CameraController? _controller;
//   List<Hand> _landmarks = [];
//   bool _isInitialized = false;
//   bool _isDetecting = false;
//   bool _isConnected = false;
//   bool _gestureControlEnabled = true;
  
//   // Frame skipping for performance
//   int _frameSkipCount = 0;
//   static const int _frameSkipInterval = 2; // Process every 3rd frame
  
//   // PC connection settings
//   String _pcIP = '192.168.43.6';
//   int _pcPort = 8080;
  
//   // Optimized gesture detection variables
//   String _currentGesture = 'None';
//   String _lastAction = 'None';
//   DateTime _lastGestureTime = DateTime.now();
//   int _gestureCount = 0;
//   final int _minGestureFrames = 5; // Reduced from 8 for faster response
//   final Duration _gestureCooldown = const Duration(milliseconds: 1500); // Reduced cooldown
  
//   // Gesture history for smoothing
//   final List<String> _gestureHistory = [];
//   static const int _historySize = 3;
  
//   // Pre-computed finger tip indices for performance
//   static const List<int> _fingerTips = [4, 8, 12, 16, 20];
//   static const List<int> _fingerPips = [3, 6, 10, 14, 18];
  
//   // Statistics
//   int _nextSlideCount = 0;
//   int _previousSlideCount = 0;
//   int _startPresentationCount = 0;
//   int _endPresentationCount = 0;
//   int _pauseResumeCount = 0;
  
//   // Performance monitoring
//   int _fps = 0;
//   int _frameCount = 0;
//   // DateTime _lastFpsUpdate = DateTime.now();
  
//   // HTTP client reuse
//   static final http.Client _httpClient = http.Client();
  
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _initialize();
//     _startFpsCounter();
//   }
  
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       _initialize();
//     } else if (state == AppLifecycleState.paused) {
//       _controller?.stopImageStream();
//     }
//   }

//   void _startFpsCounter() {
//     Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (mounted) {
//         setState(() {
//           _fps = _frameCount;
//           _frameCount = 0;
//         });
//       } else {
//         timer.cancel();
//       }
//     });
//   }

//   Future<void> _initialize() async {
//     try {
//       // Get available cameras and select front camera
//       final cameras = await availableCameras();
//       final camera = cameras.firstWhere(
//         (cam) => cam.lensDirection == CameraLensDirection.front,
//         orElse: () => cameras.first,
//       );

//       _controller = CameraController(
//         camera,
//         ResolutionPreset.low, // Reduced resolution for better performance
//         enableAudio: false,
//         imageFormatGroup: ImageFormatGroup.yuv420, // Optimized format
//       );

//       // Create plugin instance
//       _plugin = HandLandmarkerPlugin.create();

//       // Initialize camera with optimized settings
//       await _controller!.initialize();
//       await _controller!.setFocusMode(FocusMode.locked);
//       await _controller!.setExposureMode(ExposureMode.locked);
//       await _controller!.startImageStream(_processCameraImage);

//       if (mounted) {
//         setState(() {
//           _isInitialized = true;
//         });
//       }
//     } catch (e) {
//       debugPrint('Error initializing camera: $e');
//     }
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _controller?.stopImageStream();
//     _controller?.dispose();
//     _plugin?.dispose();
//     _httpClient.close();
//     super.dispose();
//   }

//   Future<void> _processCameraImage(CameraImage image) async {
//     // Frame skipping for performance
//     if (_frameSkipCount < _frameSkipInterval) {
//       _frameSkipCount++;
//       return;
//     }
//     _frameSkipCount = 0;
    
//     // Guard to prevent processing multiple frames at once
//     if (_isDetecting || !_isInitialized || _plugin == null || !_gestureControlEnabled) {
//       return;
//     }

//     _isDetecting = true;
//     _frameCount++;

//     try {
//       // Use compute for heavy processing in isolate
//       final hands = await compute(_detectHands, {
//         'image': image,
//         'plugin': _plugin!,
//         'sensorOrientation': _controller!.description.sensorOrientation,
//       });
      
//       if (mounted) {
//         setState(() {
//           _landmarks = hands;
//         });
        
//         // Process gestures if hands are detected
//         if (hands.isNotEmpty) {
//           _detectGestureOptimized(hands.first);
//         } else {
//           _resetGestureDetection();
//         }
//       }
//     } catch (e) {
//       debugPrint('Error detecting landmarks: $e');
//     } finally {
//       _isDetecting = false;
//     }
//   }

//   // Static function for compute isolation
//   static List<Hand> _detectHands(Map<String, dynamic> params) {
//     final image = params['image'] as CameraImage;
//     final plugin = params['plugin'] as HandLandmarkerPlugin;
//     final sensorOrientation = params['sensorOrientation'] as int;
    
//     return plugin.detect(image, sensorOrientation);
//   }

//   void _detectGestureOptimized(Hand hand) {
//     if (hand.landmarks.length < 21) return;

//     final detectedGesture = _classifyGestureOptimized(hand.landmarks);
    
//     // Add to history for smoothing
//     _gestureHistory.add(detectedGesture);
//     if (_gestureHistory.length > _historySize) {
//       _gestureHistory.removeAt(0);
//     }
    
//     // Use most common gesture in history
//     final smoothedGesture = _getMostCommonGesture();
    
//     if (smoothedGesture == _currentGesture) {
//       _gestureCount++;
//     } else {
//       _currentGesture = smoothedGesture;
//       _gestureCount = 1;
//     }

//     // Execute gesture if confirmed and cooldown has passed
//     if (_gestureCount >= _minGestureFrames && 
//         DateTime.now().difference(_lastGestureTime) > _gestureCooldown) {
//       _executeGesture(smoothedGesture);
//     }
//   }

//   String _getMostCommonGesture() {
//     if (_gestureHistory.isEmpty) return 'None';
    
//     final counts = <String, int>{};
//     for (final gesture in _gestureHistory) {
//       counts[gesture] = (counts[gesture] ?? 0) + 1;
//     }
    
//     return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
//   }

//   String _classifyGestureOptimized(List<Landmark> landmarks) {
//     // Pre-compute commonly used landmarks
//     final wrist = landmarks[0];
//     final thumbTip = landmarks[4];
//     final thumbIP = landmarks[3];
    
//     // Optimized finger extension detection using pre-computed indices
//     final fingerStates = <bool>[];
    
//     // Thumb (special case)
//     fingerStates.add(thumbTip.y < thumbIP.y && thumbTip.y < wrist.y);
    
//     // Other fingers
//     for (int i = 0; i < 4; i++) {
//       final tipIdx = _fingerTips[i + 1];
//       final pipIdx = _fingerPips[i + 1];
//       fingerStates.add(landmarks[tipIdx].y < landmarks[pipIdx].y);
//     }
    
//     // Count extended fingers
//     final extendedCount = fingerStates.where((extended) => extended).length;
    
//     // Optimized gesture classification
//     if (fingerStates[0] && extendedCount == 1) {
//       return 'Thumbs Up';
//     } else if (extendedCount == 0) {
//       return 'Fist';
//     } else if (!fingerStates[0] && fingerStates[1] && extendedCount == 1) {
//       return 'Point';
//     } else if (!fingerStates[0] && fingerStates[1] && fingerStates[2] && extendedCount == 2) {
//       return 'Peace';
//     } else if (extendedCount == 5) {
//       return 'Open Palm';
//     } else if (!fingerStates[0] && !fingerStates[1] && !fingerStates[2] && !fingerStates[3] && fingerStates[4]) {
//       return 'Pinky';
//     }
    
//     return 'None';
//   }

//   void _resetGestureDetection() {
//     _currentGesture = 'None';
//     _gestureCount = 0;
//     _gestureHistory.clear();
//   }

//   Future<void> _executeGesture(String gesture) async {
//     if (!_isConnected) return;
    
//     _lastGestureTime = DateTime.now();
//     _resetGestureDetection();
    
//     String action = '';
//     switch (gesture) {
//       case 'Thumbs Up':
//         action = 'start_presentation';
//         _startPresentationCount++;
//         break;
//       case 'Fist':
//         action = 'end_presentation';
//         _endPresentationCount++;
//         break;
//       case 'Point':
//         action = 'next_slide';
//         _nextSlideCount++;
//         break;
//       case 'Peace':
//         action = 'previous_slide';
//         _previousSlideCount++;
//         break;
//       case 'Open Palm':
//         action = 'pause_resume';
//         _pauseResumeCount++;
//         break;
//       case 'Pinky':
//         action = 'laser_pointer';
//         break;
//     }
    
//     if (action.isNotEmpty) {
//       // Fire and forget for better performance
//       unawaited(_sendCommandOptimized(action));
      
//       if (mounted) {
//         setState(() {
//           _lastAction = action.replaceAll('_', ' ').toUpperCase();
//         });
//       }
      
//       // Provide haptic feedback
//       HapticFeedback.lightImpact(); // Changed to light for better performance
//     }
//   }

//   Future<void> _sendCommandOptimized(String command) async {
//     try {
//       final response = await _httpClient.post(
//         Uri.parse('http://$_pcIP:$_pcPort/gesture'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'command': command,
//           'timestamp': DateTime.now().millisecondsSinceEpoch,
//         }),
//       ).timeout(const Duration(seconds: 2)); // Reduced timeout
      
//       if (response.statusCode == 200) {
//         debugPrint('Command sent successfully: $command');
//       } else {
//         debugPrint('Failed to send command: ${response.statusCode}');
//       }
//     } catch (e) {
//       debugPrint('Error sending command: $e');
//       if (mounted) {
//         setState(() {
//           _isConnected = false;
//         });
//       }
//     }
//   }

//   Future<void> _testConnection() async {
//     try {
//       final response = await _httpClient.get(
//         Uri.parse('http://$_pcIP:$_pcPort/ping'),
//       ).timeout(const Duration(seconds: 3));
      
//       if (mounted) {
//         setState(() {
//           _isConnected = response.statusCode == 200;
//         });
        
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(_isConnected ? 'Connected to PC successfully!' : 'Failed to connect to PC'),
//             backgroundColor: _isConnected ? Colors.green : Colors.red,
//             duration: const Duration(seconds: 2),
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _isConnected = false;
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Connection failed: $e'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 2),
//           ),
//         );
//       }
//     }
//   }

//   void _showSettingsDialog() {
//     final ipController = TextEditingController(text: _pcIP);
//     final portController = TextEditingController(text: _pcPort.toString());
    
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('PC Connection Settings'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: ipController,
//               decoration: const InputDecoration(
//                 labelText: 'PC IP Address',
//                 hintText: '192.168.43.6',
//                 prefixIcon: Icon(Icons.computer),
//               ),
//               keyboardType: const TextInputType.numberWithOptions(decimal: true),
//             ),
//             const SizedBox(height: 16),
//             TextField(
//               controller: portController,
//               decoration: const InputDecoration(
//                 labelText: 'Port',
//                 hintText: '8080',
//                 prefixIcon: Icon(Icons.settings_ethernet),
//               ),
//               keyboardType: TextInputType.number,
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               _pcIP = ipController.text.trim();
//               _pcPort = int.tryParse(portController.text.trim()) ?? 8080;
//               Navigator.pop(context);
//               _testConnection();
//             },
//             child: const Text('Test Connection'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showGestureGuide() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Gesture Guide'),
//         content: const Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('👍 Thumbs Up: Start Presentation'),
//             Text('✊ Fist: End Presentation'),
//             Text('👉 Point: Next Slide'),
//             Text('✌️ Peace: Previous Slide'),
//             Text('🖐️ Open Palm: Pause/Resume'),
//             Text('🤙 Pinky: Laser Pointer'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Got it'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (!_isInitialized) {
//       return const Scaffold(
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircularProgressIndicator(),
//               SizedBox(height: 16),
//               Text('Initializing camera...'),
//             ],
//           ),
//         ),
//       );
//     }

//     final controller = _controller!;
//     final previewSize = controller.value.previewSize!;
//     final previewAspectRatio = previewSize.height / previewSize.width;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Gesture Slide Controller'),
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         actions: [
//           // FPS indicator
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 8.0),
//             child: Center(
//               child: Text(
//                 '$_fps FPS',
//                 style: TextStyle(
//                   color: _fps > 15 ? Colors.green : Colors.orange,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ),
//           IconButton(
//             icon: const Icon(Icons.help_outline),
//             onPressed: _showGestureGuide,
//           ),
//           IconButton(
//             icon: const Icon(Icons.settings),
//             onPressed: _showSettingsDialog,
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Status bar
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
//               border: Border(
//                 bottom: BorderSide(
//                   color: _isConnected ? Colors.green : Colors.red,
//                   width: 2,
//                 ),
//               ),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Row(
//                   children: [
//                     Icon(
//                       _isConnected ? Icons.wifi : Icons.wifi_off,
//                       color: _isConnected ? Colors.green : Colors.red,
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       _isConnected ? 'Connected to $_pcIP:$_pcPort' : 'Disconnected',
//                       style: TextStyle(
//                         color: _isConnected ? Colors.green.shade800 : Colors.red.shade800,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//                 Row(
//                   children: [
//                     const Text('Gesture Control'),
//                     const SizedBox(width: 8),
//                     Switch(
//                       value: _gestureControlEnabled,
//                       onChanged: (value) {
//                         setState(() {
//                           _gestureControlEnabled = value;
//                         });
//                       },
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
          
//           // Camera preview with gesture overlay
//           Expanded(
//             flex: 3,
//             child: Container(
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.grey.shade300),
//               ),
//               child: AspectRatio(
//                 aspectRatio: previewAspectRatio,
//                 child: Stack(
//                   children: [
//                     CameraPreview(controller),
//                     // Reduced repaint frequency for better performance
//                     RepaintBoundary(
//                       child: CustomPaint(
//                         size: Size.infinite,
//                         painter: OptimizedGesturePainter(
//                           hands: _landmarks,
//                           previewSize: previewSize,
//                           lensDirection: controller.description.lensDirection,
//                           sensorOrientation: controller.description.sensorOrientation,
//                         ),
//                       ),
//                     ),
//                     // Gesture status overlay
//                     Positioned(
//                       top: 16,
//                       left: 16,
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                         decoration: BoxDecoration(
//                           color: Colors.black.withValues(alpha: 0.8),
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Icon(
//                               _currentGesture != 'None' ? Icons.pan_tool : Icons.back_hand,
//                               color: _currentGesture != 'None' ? Colors.green : Colors.white,
//                               size: 16,
//                             ),
//                             const SizedBox(width: 6),
//                             Text(
//                               _currentGesture,
//                               style: TextStyle(
//                                 color: _currentGesture != 'None' ? Colors.green : Colors.white,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 12,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     // Gesture confirmation progress
//                     if (_gestureCount > 0 && _currentGesture != 'None')
//                       Positioned(
//                         top: 60,
//                         left: 16,
//                         child: Container(
//                           width: 100,
//                           height: 4,
//                           decoration: BoxDecoration(
//                             color: Colors.black.withValues(alpha: 0.3),
//                             borderRadius: BorderRadius.circular(2),
//                           ),
//                           child: LinearProgressIndicator(
//                             value: _gestureCount / _minGestureFrames,
//                             backgroundColor: Colors.transparent,
//                             valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
          
//           // Control panel
//           Expanded(
//             flex: 1,
//             child: Container(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   // Last action display
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.blue.shade50,
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(color: Colors.blue.shade200),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Icon(Icons.touch_app, color: Colors.blue),
//                         const SizedBox(width: 8),
//                         Text(
//                           'Last Action: $_lastAction',
//                           style: const TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.blue,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 12),
                  
//                   // Statistics grid
//                   Expanded(
//                     child: GridView.count(
//                       crossAxisCount: 3,
//                       mainAxisSpacing: 8,
//                       crossAxisSpacing: 8,
//                       children: [
//                         _buildStatCard('Next', _nextSlideCount, Icons.arrow_forward, Colors.green),
//                         _buildStatCard('Previous', _previousSlideCount, Icons.arrow_back, Colors.orange),
//                         _buildStatCard('Start', _startPresentationCount, Icons.play_arrow, Colors.blue),
//                         _buildStatCard('End', _endPresentationCount, Icons.stop, Colors.red),
//                         _buildStatCard('Pause', _pauseResumeCount, Icons.pause, Colors.purple),
//                         _buildStatCard('Hands', _landmarks.length, Icons.back_hand, Colors.grey),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _testConnection,
//         tooltip: 'Test Connection',
//         child: const Icon(Icons.refresh),
//       ),
//     );
//   }

//   Widget _buildStatCard(String label, int count, IconData icon, Color color) {
//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(8),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(icon, size: 24, color: color),
//             const SizedBox(height: 4),
//             Text(
//               label,
//               style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
//               textAlign: TextAlign.center,
//             ),
//             Text(
//               '$count',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: color,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Optimized painter with reduced complexity
// class OptimizedGesturePainter extends CustomPainter {
//   OptimizedGesturePainter({
//     required this.hands,
//     required this.previewSize,
//     required this.lensDirection,
//     required this.sensorOrientation,
//   });

//   final List<Hand> hands;
//   final Size previewSize;
//   final CameraLensDirection lensDirection;
//   final int sensorOrientation;

//   @override
//   void paint(Canvas canvas, Size size) {
//     if (hands.isEmpty) return;
    
//     final scale = size.width / previewSize.height;

//     // Simplified paint objects
//     final landmarkPaint = Paint()
//       ..color = Colors.red
//       ..strokeWidth = 3 / scale
//       ..strokeCap = StrokeCap.round;

//     final connectionPaint = Paint()
//       ..color = Colors.lightBlue.withValues(alpha: 0.6)
//       ..strokeWidth = 1.5 / scale
//       ..strokeCap = StrokeCap.round;

//     final fingerTipPaint = Paint()
//       ..color = Colors.yellow
//       ..strokeWidth = 4 / scale
//       ..strokeCap = StrokeCap.round;

//     canvas.save();

//     final center = Offset(size.width / 2, size.height / 2);
//     canvas.translate(center.dx, center.dy);
//     canvas.rotate(sensorOrientation * math.pi / 180);

//     if (lensDirection == CameraLensDirection.front) {
//       canvas.scale(-1, 1);
//       canvas.rotate(math.pi);
//     }

//     canvas.scale(scale);

//     final logicalWidth = previewSize.width;
//     final logicalHeight = previewSize.height;

//     // Only draw the first hand for performance
//     final hand = hands.first;
//     if (hand.landmarks.length < 21) {
//       canvas.restore();
//       return;
//     }
    
//     // Draw simplified connections (only main structure)
//     final importantConnections = [
//       [0, 1], [1, 2], [2, 3], [3, 4], // Thumb
//       [0, 5], [5, 6], [6, 7], [7, 8], // Index
//       [5, 9], [9, 10], [10, 11], [11, 12], // Middle
//       [9, 13], [13, 14], [14, 15], [15, 16], // Ring
//       [13, 17], [17, 18], [18, 19], [19, 20], // Pinky
//     ];
    
//     for (final connection in importantConnections) {
//       final start = hand.landmarks[connection[0]];
//       final end = hand.landmarks[connection[1]];
//       final startDx = (start.x - 0.5) * logicalWidth;
//       final startDy = (start.y - 0.5) * logicalHeight;
//       final endDx = (end.x - 0.5) * logicalWidth;
//       final endDy = (end.y - 0.5) * logicalHeight;
      
//       canvas.drawLine(
//         Offset(startDx, startDy),
//         Offset(endDx, endDy),
//         connectionPaint,
//       );
//     }
    
//     // Draw only fingertips and key landmarks
//     final keyLandmarks = [0, 4, 8, 12, 16, 20]; // Wrist + fingertips
//     for (final i in keyLandmarks) {
//       final landmark = hand.landmarks[i];
//       final dx = (landmark.x - 0.5) * logicalWidth;
//       final dy = (landmark.y - 0.5) * logicalHeight;
      
//       final paint = i == 0 ? landmarkPaint : fingerTipPaint;
//       canvas.drawCircle(Offset(dx, dy), 3 / scale, paint);
//     }

//     canvas.restore();
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }

// // Helper function for fire-and-forget async calls
// void unawaited(Future<void> future) {
//   // Intentionally not awaiting
// }