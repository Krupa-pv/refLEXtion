import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:frontend/phoneme_classifier.dart';
import 'package:frontend/speech_models.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'word_generation.dart';
import 'tts.dart';
import 'speech_controller.dart';
import 'PA.dart';
import 'star.dart';
import 'speech_services.dart';





class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final tts = TTSService();
  final _speechController = SpeechController();
  final SpeechServices _speechService = SpeechServices();
  final PhonemeQualityModel _model = PhonemeQualityModel();

  late CameraController controller;
  late List<CameraDescription> _cameras;

  WordGeneration word_generator = WordGeneration();

  bool _isCameraInitialized = false;
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  bool _isLoading = false;

  bool _isPhoneme = false;         
  String lastPhoneme = "";

  int _stars = 0;
  String? _displayText;
  String current_word = "";

  late FaceDetector _faceDetector;

  final List<Map<String, dynamic>> _frames = [];
  int _frameIndex = 0;

  String? _lastRecordingJson;

  int wordAttemptCount = 1;        // how many times the current word has been attempted
  int phonemeAttemptCount = 0;     // attempts for the current phoneme practice

  
  bool get canRetryWord => wordAttemptCount < 3;
  
  bool get canRetryPhoneme => phonemeAttemptCount < 1;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initFaceDetector();
    current_word = word_generator.generate_word();
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

      tts.speak("Say $current_word!");

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_displayText != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stars at the top based on _stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  // _stars is your state variable (0-3)
                  bool visible = index < (_stars ?? 0); 
                  return AnimatedStar(visible: visible);
                }),
              ),
              const SizedBox(height: 12),
              // The main text
              Text(_displayText!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _displayText = null; // hide popup
                });
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  });

    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Front Camera Stream')),
      body: Stack(children: [Column(
        children: [
          // Large word label at the top
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              current_word,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),

          // Camera preview expands to fill remaining space
          Expanded(
            child: CameraPreview(controller),
          ),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isStreaming ? null : () async{
                    _startStream();
                    await onStartClicked();
                  },
                  child: const Text('Start Stream'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: !_isStreaming
                      ? null
                      : () async {
                           final jsonfile = await _stopStream();
                           _lastRecordingJson = jsonfile;
                           await onStopClicked();
                           
                        },
                  child: const Text('Stop Stream'),
                ),
              ],
            ),
          ),
        ],
      ), if (_isLoading)
      Container(
        color: Colors.black45, // semi-transparent overlay
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),])

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
        // Convert CameraImage -> InputImage
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

  Future<String> _stopStream() async {
    if (!_isStreaming){
      return "";
    }
    await controller.stopImageStream();
    setState(() => _isStreaming = false);


    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/mouth_data.jsonl';
    final file = File(filePath);
    var contents = "";
    // Wrap frames in a "frame" field and write as a single JSON object
    final wrappedFrames = {'frame': _frames};
    await file.writeAsString(jsonEncode(wrappedFrames));

    debugPrint('Saved ${_frames.length} frames to $filePath');

    if (await file.exists()) {
      contents = await file.readAsString();
      debugPrint('Current JSONL contents:\n$contents');
    } else {
      debugPrint('JSONL file not found yet.');
    }

    // Optional: clear memory after saving
    _frames.clear();
    _frameIndex = 0;

    return contents;
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

  Future<void> onStartClicked() async {
    if (!_isPhoneme) {
      // starting word-level ASR grading
      await _speechController.onStartClicked(current_word, context);
    } else {
      // already in phoneme practice mode
      // could play prompt like "Say /p/ again"
      await _speechService.playTts("Say $lastPhoneme");
    }
  }

  Future<void> onStopClicked() async {
    debugPrint("calling onStopClicked()");
    setState(() {
      _isLoading = true;
    });

    final result =
        await _speechController.onStopClicked(current_word, GradingLevel.Phoneme);

    final wordsData = result?.words;

    if (wordsData != null) {
      for (var word in wordsData) {
        debugPrint('Word: ${word.word}');
        double min = 10000;
        for (var p in word.phonemes) {
          debugPrint('Phoneme: ${p.phoneme}, Accuracy: ${p.accuracyScore}');
          if (p.accuracyScore<min){
            lastPhoneme = p.phoneme;
            min = p.accuracyScore;
            _isPhoneme = true;
          }
        }
      }

      // if in phoneme mode, run visual mouth model now
      if (_isPhoneme) {
        await _handlePhonemeEvaluation();
      }
    } else {
      debugPrint('No words data available');
    }

    final double? accuracy = result?.accuracyScore;

    setState(() {
      _isLoading = false;
    });

    if (accuracy == null) {
      debugPrint("accuracyScore null in result");
      return;
    }

    if (_isPhoneme) {
      // phoneme branch already handled in _handlePhonemeEvaluation
      return;
    } else {
      await _handleWordEvaluation(accuracy);
    }
  }

  // word mode result logic
  Future<void> _handleWordEvaluation(double accuracy) async {
    if (accuracy < 80) {
      // word not good enough -> enter phoneme mode
      if (lastPhoneme.isNotEmpty) {
        phonemeAttemptCount = 0;
        _isPhoneme = true;

        //await speakAndShow("Let's practice the sound $lastPhoneme.");
        await _speechService.playTts("Say $lastPhoneme");
      }

      wordAttemptCount += 1;
      return;
    }

    // success at word level
    setStar(3);
    await speakAndShow("Great job! You said the word correctly.");
    setStar(0);

    _advanceToNextWord();
  }

  // phoneme mode result logic
  Future<void> _handlePhonemeEvaluation() async {
    if (lastPhoneme.isEmpty) {
      debugPrint("No lastPhoneme set, can't phoneme-eval");
      return;
    }

    if (_lastRecordingJson != null) {
      await _model.loadModel(lastPhoneme);

      final feedback = await _model.getPhonemeFeedback(_lastRecordingJson!);
      debugPrint("visual feedback for $lastPhoneme: $feedback");
      await speakAndShow(feedback);
    } else {
      debugPrint("no _lastRecordingJson available for phoneme eval");
    }

    phonemeAttemptCount += 1;

    if (!canRetryPhoneme) {
      _finishPhonemeAndAdvance();
    } else {
      await _speechService.playTts("Try $lastPhoneme again.");
    }
  }

  void _finishPhonemeAndAdvance() {
    setStar(0);
    _isPhoneme = false;
    _advanceToNextWord();
  }

  void _advanceToNextWord() {
    setState(() {
      wordAttemptCount = 1;
      phonemeAttemptCount = 0;
      _isPhoneme = false;
      current_word = word_generator.generate_word();
    });
  }

  Future<void> speakAndShow(String text) async {
    setState(() {
      _displayText = text;
    });

    await tts.speakAndWait(text);

    if (!mounted) return;

    setState(() {
      _displayText = null;
    });
  }

  void setStar(int stars) {
    setState(() {
      _stars = stars;
    });
  }
}