import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';


class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController controller;
  late List<CameraDescription> _cameras;
  bool _isCameraInitialized = false;
  bool _isStreaming = false;
  bool _isProcessingFrame = false;

  late FaceDetector _faceDetector;
  List<Map<String, dynamic>> _frames = [];
  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initFaceDetector();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    //controller = CameraController(_cameras[0], ResolutionPreset.max);
    final frontCamera = _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
    );
    controller = CameraController(frontCamera, ResolutionPreset.high);


    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      if (e is CameraException) {
        // Handle errors like access denied
        debugPrint('Camera error: ${e.code}');
      }
    }
  }

  void _initFaceDetector() {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Front Camera Stream')),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CameraPreview(controller),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isStreaming ? null : _startStream,
                  child: const Text('Start Stream'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _isStreaming ? _stopStream : null,
                  child: const Text('Stop Stream'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startStream() async{
    if (_isStreaming) return;
    setState(() {
      _isStreaming = true;
    });

    controller.startImageStream((CameraImage image) async {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;

      try {
        // Convert CameraImage → InputImage
        final inputImage = _convertToInputImage(image, controller.description.sensorOrientation);

        // Run face detection
        final faces = await _faceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          final face = faces.first;

          // Get all mouth contour types you care about
          final contourTypes = [
            FaceContourType.upperLipTop,
            FaceContourType.upperLipBottom,
            FaceContourType.lowerLipTop,
            FaceContourType.lowerLipBottom,
          ];

          // Build your structure like in Swift
          final mouthContours = <String, List<Map<String, double>>>{};


          for (final contourType in contourTypes) {
            final contour = face.contours[contourType];
            if (contour != null && contour.points.isNotEmpty) {
              mouthContours[contourType.name] = contour.points
                  .map((p) => {
                    'x': p.x / image.width,
                    'y': p.y / image.height,
                  })
                  .toList();
            }
          }

          // For debugging, print the full structured map

          if (mouthContours.isNotEmpty) {
            final frameData = {
              'frame_index': _frameIndex,
              'timestamp': DateTime.now().toIso8601String(),
              'mouthContours': mouthContours,
            };

            _frames.add(frameData);
            _frameIndex++;
          }
        }
      } catch (e) {
        debugPrint('Error in frame processing: $e');
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  void _stopStream() async {
    if (!_isStreaming) return;
    await controller.stopImageStream();
    setState(() => _isStreaming = false);


    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/mouth_data.jsonl';
    final file = File(filePath);

    // Wrap frames in a "frame" field and write as a single JSON object
    final wrappedFrames = {'frame': _frames};
    await file.writeAsString(jsonEncode(wrappedFrames));

    debugPrint('✅ Saved ${_frames.length} frames to $filePath');

    if (await file.exists()) {
      final contents = await file.readAsString();
      debugPrint('Current JSONL contents:\n$contents');
    } else {
      debugPrint('JSONL file not found yet.');
    }

    // Optional: clear memory after saving
    _frames.clear();
    _frameIndex = 0;
  }

  InputImage _convertToInputImage(CameraImage image, int rotation) {
    // MLKit expects InputImage in plane format
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(rotation) ?? InputImageRotation.rotation0deg,
        format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

}
