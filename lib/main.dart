import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Import the plugin's main class.
import 'package:hand_landmarker/hand_landmarker.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Hand Landmarker Example',
      home: HandTrackerView(),
    );
  }
}

class HandTrackerView extends StatefulWidget {
  const HandTrackerView({super.key});

  @override
  State<HandTrackerView> createState() => _HandTrackerViewState();
}

class _HandTrackerViewState extends State<HandTrackerView> {
  CameraController? _controller;
  // The plugin instance that will handle all the heavy lifting.
  HandLandmarkerPlugin? _plugin;
  // The results from the plugin will be stored in this list.
  List<Hand> _landmarks = [];
  // A flag to show a loading indicator while the camera and plugin are initializing.
  bool _isInitialized = false;
  // A guard to prevent processing multiple frames at once.
  bool _isDetecting = false;
  int _frameCount = 0;

  // WebSocket connection to PC
  WebSocket? _socket;
  String _lastAction = 'None';

  // PC connection settings
  final String _pcIP = '192.168.43.6';
  final int _pcPort = 8080;

  @override
  void initState() {
    super.initState();
    _initialize();
    _connectWebSocket();
  }

  Future<void> _initialize() async {
    final camera = _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );
    _controller = CameraController(
      camera,
      ResolutionPreset.low, // Lower resolution for faster processing
      enableAudio: false,
    );
    _plugin = HandLandmarkerPlugin.create();
    await _controller!.initialize();
    await _controller!.startImageStream(_processCameraImage);
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      _socket?.close();
      _socket = await WebSocket.connect('ws://$_pcIP:$_pcPort/ws');
      _socket!.listen((message) {
        debugPrint('Received from server: $message');
      }, onDone: () async {
        setState(() {
          _socket = null;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) await _connectWebSocket();
      }, onError: (e) async {
        debugPrint('WebSocket error: $e');
        setState(() {
          _socket = null;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) await _connectWebSocket();
      });
      setState(() {});
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      setState(() {
        _socket = null;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) await _connectWebSocket();
    }
  }

  @override
  void dispose() {
    // Stop the image stream and dispose of the controller.
    _controller?.stopImageStream();
    _controller?.dispose();
    // Dispose of the plugin to release native resources.
    _plugin?.dispose();
    _socket?.close();
    super.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    _frameCount++;
    if (_frameCount % 2 != 0) return; // Only process every 2nd frame for speed
    if (_isDetecting || !_isInitialized || _plugin == null) return;

    _isDetecting = true;

    try {
      // The detect method is now synchronous (not async).
      final hands = _plugin!.detect(
        image,
        _controller!.description.sensorOrientation,
      );
      if (mounted) {
        setState(() {
          _landmarks = hands;
        });
        if (hands.isNotEmpty) {
          _detectGesture(hands.first);
        }
      }
    } catch (e) {
      debugPrint('Error detecting landmarks: $e');
    } finally {
      // Allow the next frame to be processed.
      _isDetecting = false;
    }
  }

  void _detectGesture(Hand hand) {
    if (hand.landmarks.length < 21) return;
    String gesture = _classifyGesture(hand.landmarks);
    if (gesture != 'None') {
      _sendCommandWebSocket(gesture);
      setState(() {
        _lastAction = gesture;
      });
    }
  }

  String _classifyGesture(List<Landmark> landmarks) {
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
    final wrist = landmarks[0];
    bool thumbUp = thumbTip.y < thumbIP.y && thumbTip.y < wrist.y;
    bool indexUp = indexTip.y < indexPIP.y;
    bool middleUp = middleTip.y < middlePIP.y;
    bool ringUp = ringTip.y < ringPIP.y;
    bool pinkyUp = pinkyTip.y < pinkyPIP.y;
    int extendedFingers = 0;
    if (thumbUp) extendedFingers++;
    if (indexUp) extendedFingers++;
    if (middleUp) extendedFingers++;
    if (ringUp) extendedFingers++;
    if (pinkyUp) extendedFingers++;
    if (thumbUp && !indexUp && !middleUp && !ringUp && !pinkyUp) {
      return 'START';
    } else if (extendedFingers == 0) {
      return 'END';
    } else if (!thumbUp && indexUp && !middleUp && !ringUp && !pinkyUp) {
      return 'NEXT';
    } else if (!thumbUp && indexUp && middleUp && !ringUp && !pinkyUp) {
      return 'PREV';
    } else if (extendedFingers == 5) {
      return 'PAUSE';
    }
    return 'None';
  }

  void _sendCommandWebSocket(String command) {
    if (_socket == null || _socket!.readyState != WebSocket.open) return;
    _socket!.add(command);
    debugPrint('WebSocket sent: $command');
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while initializing.
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final controller = _controller!;
    final previewSize = controller.value.previewSize!;
    final previewAspectRatio = previewSize.height / previewSize.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Hand Tracking')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: previewAspectRatio,
              child: Stack(
                children: [
                  CameraPreview(controller),
                  CustomPaint(
                    // Tell the painter to fill the available space
                    size: Size.infinite,
                    painter: LandmarkPainter(
                      hands: _landmarks,
                      // Pass the camera's resolution explicitly
                      previewSize: previewSize,
                      lensDirection: controller.description.lensDirection,
                      sensorOrientation:
                          controller.description.sensorOrientation,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Last Action: $_lastAction',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// A custom painter that renders the hand landmarks and connections.
class LandmarkPainter extends CustomPainter {
  LandmarkPainter({
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
    final scale = size.width / previewSize.height;
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 8 / scale
      ..strokeCap = StrokeCap.round;
    final linePaint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 4 / scale;
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
      for (final landmark in hand.landmarks) {
        final dx = (landmark.x - 0.5) * logicalWidth;
        final dy = (landmark.y - 0.5) * logicalHeight;
        canvas.drawCircle(Offset(dx, dy), 8 / scale, paint);
      }
      for (final connection in HandLandmarkConnections.connections) {
        if (connection[0] < hand.landmarks.length &&
            connection[1] < hand.landmarks.length) {
          final start = hand.landmarks[connection[0]];
          final end = hand.landmarks[connection[1]];
          final startDx = (start.x - 0.5) * logicalWidth;
          final startDy = (start.y - 0.5) * logicalHeight;
          final endDx = (end.x - 0.5) * logicalWidth;
          final endDy = (end.y - 0.5) * logicalHeight;
          canvas.drawLine(
            Offset(startDx, startDy),
            Offset(endDx, endDy),
            linePaint,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Helper class.
class HandLandmarkConnections {
  static const List<List<int>> connections = [
    [0, 1], [1, 2], [2, 3], [3, 4], // Thumb
    [0, 5], [5, 6], [6, 7], [7, 8], // Index finger
    [5, 9], [9, 10], [10, 11], [11, 12], // Middle finger
    [9, 13], [13, 14], [14, 15], [15, 16], // Ring finger
    [13, 17], [0, 17], [17, 18], [18, 19], [19, 20], // Pinky
  ];
}
