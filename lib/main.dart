import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'vision_detector_views/camera_view.dart';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FaceDetectorView(),
    );
  }
}

class FaceDetectorView extends StatefulWidget {
  const FaceDetectorView({
    super.key,
  });

  @override
  State<FaceDetectorView> createState() => _FaceDetectorViewState();
}

class _FaceDetectorViewState extends State<FaceDetectorView> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // 눈개폐확률, 웃고있는지
    ),
  );
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const double _closedEyeThreshold = 0.5; // 눈 개페율. 해당값 미만이면 감긴 것으로 판단.
  static const int _drowsinessFrameThreshold = 8; // 8프레임동안 눈 감긴상태가 지속되야 판단
  int _closedEyeFrameCount = 0;

  bool _isAlarmPlaying = false; // 알람 울리는중인지
  bool _showEyeCloseAlert = false; // 눈 감김 알림 상태 관리
  bool _canProcess = true;
  bool _isBusy = false;

  @override
  void dispose() {
    _canProcess = false; //이미지 처리를 중지
    _faceDetector.close();
    _audioPlayer.dispose(); // AudioPlayer 자원 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraView(
            onImage: _processImage,
            initialCameraLensDirection: CameraLensDirection.front,
          ),
          // 눈 감김 알림 위젯
          if (_showEyeCloseAlert)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '졸음감지!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 이미지 처리 함수
  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess || _isBusy) return; // 이미지처리 가능하고 처리중인지
    _isBusy = true; // 이미지 처리 시작

    final faces = await _faceDetector.processImage(inputImage); //얼굴인식, 졸음 감지 로직
    if (faces.isNotEmpty) {
      final face = faces.first;

      final double? leftEyeOpenProbability = face.leftEyeOpenProbability;
      final double? rightEyeOpenProbability = face.rightEyeOpenProbability;

      if (leftEyeOpenProbability != null && rightEyeOpenProbability != null) {
        _detectDrowsiness(leftEyeOpenProbability, rightEyeOpenProbability);
      }
    } else {
      _resetState(); // 얼굴이 감지되지 않으면
    }
    _isBusy = false; //이미지 처리 완료
  }

  // 졸음 감지 함수
  void _detectDrowsiness(double leftEyeOpenProb, double rightEyeOpenProb) {
    if (leftEyeOpenProb < _closedEyeThreshold &&
        rightEyeOpenProb < _closedEyeThreshold) {
      _closedEyeFrameCount++;

      //졸음 감지
      if (_closedEyeFrameCount >= _drowsinessFrameThreshold) {
        _triggerAlarm();
        setState(() => _showEyeCloseAlert = true);
        _closedEyeFrameCount = 0;
      }
    } else {
      _resetState(); // 졸음이 감지되지 않으면
    }
  }

  void _resetState() {
    _closedEyeFrameCount = 0;
    _stopAlarm();
    setState(() => _showEyeCloseAlert = false);
  }

  Future<void> _triggerAlarm() async {
    if (!_isAlarmPlaying) {
      _isAlarmPlaying = true;
      await _audioPlayer.play(AssetSource('alarm.wav'));
    }
  }

  Future<void> _stopAlarm() async {
    if (_isAlarmPlaying) {
      await _audioPlayer.stop();
      _isAlarmPlaying = false;
    }
  }
}
