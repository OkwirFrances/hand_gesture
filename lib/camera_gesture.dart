import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MaterialApp(home: SlideRemote()));
}

class SlideRemote extends StatefulWidget {
  const SlideRemote({super.key});
  @override
  State<SlideRemote> createState() => _SlideRemoteState();
}

class _SlideRemoteState extends State<SlideRemote> {
  CameraController? _cam;
  HandLandmarkerPlugin? _plugin;
  WebSocketChannel? _ws;
  Timer? _reconnectTimer;

  bool _isDetecting = false;
  String _status = 'Connecting…';

  // ---------- INIT ----------
  @override
  void initState() {
    super.initState();
    _initCamera();
    _connectWS();
  }

  Future<void> _initCamera() async {
    final cam = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _cam = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
    await _cam!.initialize();

    // correct constructor (positional args)
    _plugin = HandLandmarkerPlugin.create();

    _cam!.startImageStream(_onFrame);
    if (mounted) setState(() {});
  }

  // ---------- WebSocket ----------
  void _connectWS() {
    _ws?.sink.close();
    try {
      _ws = WebSocketChannel.connect(Uri.parse('ws://192.168.43.6:8080'));
      _ws!.ready.then((_) {
        if (mounted) setState(() => _status = 'Ready');
      }).onError((_, __) {
        _scheduleReconnect();
        return null;
      });

      _ws!.stream.listen(
        (_) {},
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (mounted) setState(() => _status = 'Reconnecting…');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), _connectWS);
  }

  // ---------- FRAME ----------
  Future<void> _onFrame(CameraImage frame) async {
    if (_isDetecting || _plugin == null || _cam == null) return;
    _isDetecting = true;

    try {
      final hands = _plugin!.detect(frame, _cam!.description.sensorOrientation);
      if (hands.isNotEmpty) {
        final lm = hands.first.landmarks;
        final thumbTip = lm[4], indexTip = lm[8], middleTip = lm[12];

        String? cmd;
        final pinch = (thumbTip.x - indexTip.x).abs() +
                      (thumbTip.y - indexTip.y).abs();
        if (pinch < 0.07) {
          cmd = 'next';
        } else if (middleTip.y < indexTip.y - 0.05) {
          cmd = 'prev';
        } else if (indexTip.y < 0.35 && middleTip.y < 0.35) {
          cmd = 'play';
        }

        if (cmd != null) {
          _ws?.sink.add(cmd);
          setState(() => _status = cmd ?? '');
          await Future.delayed(const Duration(milliseconds: 350));
        }
      }
    } catch (_) {}
    _isDetecting = false;
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    if (_cam == null || !_cam!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text('Slide Remote – $_status')),
      body: AspectRatio(
        aspectRatio: _cam!.value.aspectRatio,
        child: CameraPreview(_cam!),
      ),
    );
  }

  // ---------- CLEANUP ----------
  @override
  void dispose() {
    _cam?.dispose();
    _plugin?.dispose();
    _reconnectTimer?.cancel();
    _ws?.sink.close();
    super.dispose();
  }
}