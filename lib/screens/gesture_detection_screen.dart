import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For MethodChannel
import 'package:tflite_flutter/tflite_flutter.dart';

late List<CameraDescription> cameras;

class GestureDetectionScreen extends StatefulWidget {
  const GestureDetectionScreen({super.key});

  @override
  State<GestureDetectionScreen> createState() => _GestureDetectionScreenState();
}

class _GestureDetectionScreenState extends State<GestureDetectionScreen> {
  static const platform = MethodChannel('com.yourcompany.mediapipe/hands');

  late CameraController _cameraController;
  late Interpreter _keypointInterpreter;
  late Interpreter _gestureInterpreter;
  List<String> _keypointLabels = [];
  List<String> _gestureLabels = [];
  int _currentSlideIndex = 0;
  final PageController _pageController = PageController();
  bool _isProcessingFrame = false;

  @override
  void initState() {
    super.initState();
    _initializeCameraAndModels();
  }

  Future<void> _initializeCameraAndModels() async {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
    await _initCamera();
    await _loadModels();
  }

  Future<void> _initCamera() async {
    _cameraController = CameraController(
      cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      ),
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController.initialize();
    setState(() {});
    _startFrameStream();
  }

  Future<void> _loadModels() async {
    _keypointInterpreter = await Interpreter.fromAsset(
      'keypoint_classifier.tflite',
    );
    _gestureInterpreter = await Interpreter.fromAsset(
      'point_history_classifier.tflite',
    );

    _keypointLabels =
        (await rootBundle.loadString(
          'assets/keypoint_classifier_label.csv',
        )).split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    _gestureLabels =
        (await rootBundle.loadString(
          'assets/point_history_classifier_label.csv',
        )).split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  void _startFrameStream() {
    _cameraController.startImageStream((CameraImage image) async {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;

      try {
        // ✅ Uses the native MethodChannel
        List<double> keypoints = await _extractKeypointsFromImage(image);

        if (keypoints.isNotEmpty) {
          List<double> keypointFeatures = _runKeypointModel(keypoints);
          String gesture = _runGestureModel(keypointFeatures);
          _handleGesture(gesture);
        }
      } catch (e) {
        debugPrint('Frame processing error: $e');
      }

      _isProcessingFrame = false;
    });
  }

  Future<List<double>> _extractKeypointsFromImage(CameraImage image) async {
    try {
      final List<dynamic> landmarks = await platform.invokeMethod(
        'processFrame',
        {
          'bytes': image.planes[0].bytes,
          'width': image.width,
          'height': image.height,
        },
      );

      return landmarks.cast<double>();
    } on PlatformException catch (e) {
      debugPrint('Failed to get landmarks: ${e.message}');
      return [];
    }
  }

  List<double> _runKeypointModel(List<double> keypoints) {
    var input = [keypoints];
    var output = List.filled(
      _keypointLabels.length,
      0.0,
    ).reshape([1, _keypointLabels.length]);
    _keypointInterpreter.run(input, output);
    return output[0];
  }

  String _runGestureModel(List<double> keypointFeatures) {
    var input = [keypointFeatures];
    var output = List.filled(
      _gestureLabels.length,
      0.0,
    ).reshape([1, _gestureLabels.length]);
    _gestureInterpreter.run(input, output);

    double maxScore = output[0][0];
    int maxIndex = 0;
    for (int i = 1; i < output[0].length; i++) {
      if (output[0][i] > maxScore) {
        maxScore = output[0][i];
        maxIndex = i;
      }
    }

    return _gestureLabels[maxIndex];
  }

  void _handleGesture(String gesture) {
    debugPrint('Detected gesture: $gesture');

    switch (gesture) {
      case "swipe_right":
        _nextSlide();
        break;
      case "swipe_left":
        _previousSlide();
        break;
      case "palm_open":
        _startPresentation();
        break;
      case "fist":
        _pausePresentation();
        break;
      case "wave":
        _endPresentation();
        break;
      case "thumbs_up":
        _confirmAction();
        break;
    }
  }

  void _nextSlide() {
    if (_currentSlideIndex < 4) {
      setState(() {
        _currentSlideIndex++;
        _pageController.animateToPage(
          _currentSlideIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
      });
    }
  }

  void _previousSlide() {
    if (_currentSlideIndex > 0) {
      setState(() {
        _currentSlideIndex--;
        _pageController.animateToPage(
          _currentSlideIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
      });
    }
  }

  void _startPresentation() {
    debugPrint("Presentation started");
  }

  void _pausePresentation() {
    debugPrint("Presentation paused/resumed");
  }

  void _endPresentation() {
    debugPrint("Presentation ended");
  }

  void _confirmAction() {
    debugPrint("Action confirmed");
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_cameraController),
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              5,
              (index) => Center(
                child: Text(
                  'Slide ${index + 1}',
                  style: const TextStyle(fontSize: 30, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
