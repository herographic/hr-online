// lib/screens/attendance/face_liveness_screen.dart

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';

enum FaceScanMode { register, verify }

enum LivenessAction {
  lookStraight,
  turnLeft,
  turnRight,
  lookUp,
  completed,
  failed
}

class FaceLivenessScreen extends StatefulWidget {
  final FaceScanMode mode;
  final String employeeId;

  const FaceLivenessScreen({
    super.key,
    required this.mode,
    required this.employeeId,
  });

  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

class _FaceLivenessScreenState extends State<FaceLivenessScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  late FaceDetector _faceDetector;

  LivenessAction _requiredAction = LivenessAction.lookStraight;
  final List<XFile> _capturedImages = [];
  Timer? _failureTimer;

  static const double _headTurnThreshold = 35.0;
  static const double _headTiltThreshold = 20.0;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true,
        enableLandmarks: true,
      ),
    );
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    _failureTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first);

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.high, // Use high resolution for registration
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
      _cameraController!.startImageStream(_processImageStream);
      _startFailureTimer();
    } catch (e) {
      _setAction(LivenessAction.failed, "ไม่สามารถเปิดกล้องได้");
    }
  }

  void _startFailureTimer() {
    _failureTimer?.cancel();
    _failureTimer = Timer(const Duration(seconds: 20), () {
      if (_requiredAction != LivenessAction.completed) {
        _setAction(LivenessAction.failed, "หมดเวลาในการดำเนินการ");
      }
    });
  }

  void _processImageStream(CameraImage image) {
    if (_isProcessing || !mounted) return;
    _isProcessing = true;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isProcessing = false;
      return;
    }

    _faceDetector.processImage(inputImage).then((faces) {
      if (faces.isNotEmpty) {
        _validateAction(faces.first);
      }
      _isProcessing = false;
    }).catchError((_) {
      _isProcessing = false;
    });
  }

  Future<void> _validateAction(Face face) async {
    final double headEulerAngleY = face.headEulerAngleY ?? 0;
    final double headEulerAngleX = face.headEulerAngleX ?? 0;

    bool actionCompleted = false;
    LivenessAction nextAction = _requiredAction;

    switch (_requiredAction) {
      case LivenessAction.lookStraight:
        if (headEulerAngleY.abs() < 5 && headEulerAngleX.abs() < 5) {
          actionCompleted = true;
          nextAction = LivenessAction.turnLeft;
        }
        break;
      case LivenessAction.turnLeft:
        if (headEulerAngleY > _headTurnThreshold) {
          actionCompleted = true;
          nextAction = LivenessAction.turnRight;
        }
        break;
      case LivenessAction.turnRight:
        if (headEulerAngleY < -_headTurnThreshold) {
          actionCompleted = true;
          nextAction = LivenessAction.lookUp;
        }
        break;
      case LivenessAction.lookUp:
        if (headEulerAngleX > _headTiltThreshold) {
          actionCompleted = true;
          nextAction = LivenessAction.completed;
        }
        break;
      default:
        break;
    }

    if (actionCompleted) {
      HapticFeedback.lightImpact();
      final image = await _cameraController?.takePicture();
      if (image != null) _capturedImages.add(image);

      if (nextAction == LivenessAction.completed) {
         _setAction(LivenessAction.completed, "ยืนยันตัวตนสำเร็จ!");
      } else {
        _setAction(nextAction);
      }
    }
  }

  void _setAction(LivenessAction action, [String? message]) {
    if (mounted) {
      setState(() => _requiredAction = action);
      if (action == LivenessAction.completed || action == LivenessAction.failed) {
        _failureTimer?.cancel();
        _cameraController?.stopImageStream();
        _showResultDialog(message ?? "เกิดข้อผิดพลาด", action == LivenessAction.completed);
      }
    }
  }

  void _showResultDialog(String message, bool isSuccess) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isSuccess ? 'สำเร็จ' : 'ไม่สำเร็จ'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (widget.mode == FaceScanMode.register) {
                Navigator.of(context).pop(isSuccess ? _capturedImages : null);
              } else {
                // In verify mode, you would proceed to check-in logic here
                // For now, just pop the screen
                Navigator.of(context).pop(isSuccess);
              }
            },
            child: const Text('ตกลง'),
          )
        ],
      ),
    );
  }

  String _getInstructionText() {
    switch (_requiredAction) {
      case LivenessAction.lookStraight: return 'กรุณามองตรง (1/4)';
      case LivenessAction.turnLeft: return 'กรุณาหันหน้าไปทางซ้าย (2/4)';
      case LivenessAction.turnRight: return 'ยอดเยี่ยม! ต่อไปหันไปทางขวา (3/4)';
      case LivenessAction.lookUp: return 'ดีมาก! กรุณาพยักหน้าขึ้น (4/4)';
      case LivenessAction.completed: return 'สำเร็จ!';
      case LivenessAction.failed: return 'ไม่สำเร็จ กรุณาลองใหม่';
      default: return '';
    }
  }

  IconData _getInstructionIcon() {
    switch (_requiredAction) {
      case LivenessAction.lookStraight: return Icons.camera_front;
      case LivenessAction.turnLeft: return Icons.arrow_back;
      case LivenessAction.turnRight: return Icons.arrow_forward;
      case LivenessAction.lookUp: return Icons.arrow_upward;
      case LivenessAction.completed: return Icons.check_circle;
      case LivenessAction.failed: return Icons.error;
      default: return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.mode == FaceScanMode.register ? 'ลงทะเบียนใบหน้า' : 'ยืนยันตัวตน')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _isCameraInitialized
                ? ClipOval(child: CameraPreview(_cameraController!))
                : const Center(child: CircularProgressIndicator()),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getInstructionIcon(), size: 60, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    _getInstructionText(),
                    style: GoogleFonts.anuphan(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      var rotationCompensation = (sensorOrientation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (defaultTargetPlatform == TargetPlatform.android && format != InputImageFormat.nv21) ||
        (defaultTargetPlatform == TargetPlatform.iOS && format != InputImageFormat.bgra8888)) return null;

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
