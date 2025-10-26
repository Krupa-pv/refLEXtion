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

  // this flag means "the LAST thing we asked you to do was the phoneme",
  // and we're currently evaluating that phoneme attempt.
  bool _isPhoneme = false;
  String lastPhoneme = "";

  int _stars = 0;
  String? _displayText;
  String current_word = "";

  late FaceDetector _faceDetector;

  final List<Map<String, dynamic>> _frames = [];
  int _frameIndex = 0;

  String? _lastRecordingJson;

  // Attempts logic
  // wordAttemptCount starts at 1 because we're on attempt #1 for this word when we show it
  int wordAttemptCount = 1;
  // we will allow exactly ONE phoneme attempt per miss
  int phonemeAttemptCount = 0;

  bool get canRetryWord => wordAttemptCount < 3;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initFaceDetector();
    current_word = word_generator.generate_word();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
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
    // popup dialog if _displayText != null
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_displayText != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stars row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    bool visible = index < (_stars ?? 0);
                    return AnimatedStar(visible: visible);
                  }),
                ),
                const SizedBox(height: 12),
                Text(_displayText!),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _displayText = null;
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

    // label at top:
    // if we're currently asking phoneme, show the phoneme; else show word
    final labelText = _isPhoneme && lastPhoneme.isNotEmpty
        ? lastPhoneme
        : current_word;

    return Scaffold(
      appBar: AppBar(title: const Text('Front Camera Stream')),
      body: Stack(
        children: [
          Column(
            children: [
              // Large label at the top
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  children: [
                    Text(
                      labelText,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    if (_isPhoneme)
                      const Text(
                        "(sound practice)",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.redAccent,
                        ),
                      ),
                  ],
                ),
              ),

              // Camera preview
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
                      onPressed: _isStreaming
                          ? null
                          : () async {
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
          ),

          // loading overlay
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  void _startStream() async {
    if (_isStreaming) return;
    setState(() {
      _isStreaming = true;
    });

    controller.startImageStream((CameraImage image) async {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;

      try {
        final inputImage = _convertToInputImage(
          image,
          controller.description.sensorOrientation,
        );

        final faces = await _faceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          final face = faces.first;

          final contourTypes = [
            FaceContourType.upperLipTop,
            FaceContourType.upperLipBottom,
            FaceContourType.lowerLipTop,
            FaceContourType.lowerLipBottom,
          ];

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
    if (!_isStreaming) {
      return "";
    }
    await controller.stopImageStream();
    setState(() => _isStreaming = false);

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/mouth_data.jsonl';
    final file = File(filePath);

    // Wrap frames in a "frame" field and write as single JSON object
    final wrappedFrames = {'frame': _frames};
    await file.writeAsString(jsonEncode(wrappedFrames));

    debugPrint('Saved ${_frames.length} frames to $filePath');

    String contents = "";
    if (await file.exists()) {
      contents = await file.readAsString();
      debugPrint('Current JSONL contents:\n$contents');
    }

    // clear buffer for safety
    _frames.clear();
    _frameIndex = 0;

    return contents;
  }

  InputImage _convertToInputImage(CameraImage image, int rotation) {
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(rotation) ??
            InputImageRotation.rotation0deg,
        format: InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // Start button behavior
  Future<void> onStartClicked() async {
    if (!_isPhoneme) {
      // WORD attempt start
      await _speechController.onStartClicked(current_word, context);
    } else {
      // PHONEME attempt start
      // we still use SpeechController so they produce that phoneme
      await _speechService.playTts(lastPhoneme);
      await _speechController.onStartClicked(lastPhoneme, context);
      
    }
  }

  // Stop button behavior:
  // grade attempt, branch logic
  Future<void> onStopClicked() async {
    debugPrint("calling onStopClicked()");
    setState(() {
      _isLoading = true;
    });

    // NOTE: we always call stopClicked with the word for scoring,
    // because we still want per-phoneme breakdown from that lib.
    // If your SpeechController supports passing either word or phoneme,
    // you could branch here.
    final result = await _speechController.onStopClicked(
      current_word,
      GradingLevel.Phoneme,
    );

    final wordsData = result?.words;
    double? accuracy = result?.accuracyScore;

    // figure out worst phoneme
    if (wordsData != null) {
      String worstPhonemeLocal = "";
      double minScore = 10000;

      for (var word in wordsData) {
        for (var p in word.phonemes) {
          if (p.accuracyScore < minScore) {
            minScore = p.accuracyScore;
            worstPhonemeLocal = p.phoneme;
          }
        }
      }

      // if this attempt was a WORD attempt and accuracy < 80,
      // we're going to immediately schedule a PHONEME follow-up using that worst phoneme
      if (!_isPhoneme && accuracy != null && accuracy < 80) {
        lastPhoneme = worstPhonemeLocal;
      }
    }

    setState(() {
      _isLoading = false;
    });

    if (accuracy == null) {
      debugPrint("accuracyScore null in result");
      return;
    }

    if (_isPhoneme) {
      // We just did a PHONEME attempt.
      // Evaluate mouth model once, then either retry word or advance.
      await _handlePhonemeEvaluation();
    } else {
      // We just did a WORD attempt.
      await _handleWordEvaluation(accuracy);
    }
  }

  // -------------------------
  // WORD evaluation path
  // -------------------------
  Future<void> _handleWordEvaluation(double accuracy) async {
    if (accuracy >= 80) {
      // success -> stars + next word
      setStar(3);
      await speakAndShow("Great job! You said the word correctly.");
      setStar(0);

      _advanceToNextWord();
      return;
    }

    // accuracy < 80
    // We will do ONE phoneme drill using lastPhoneme (if we have it).
    // Then after that phoneme drill we'll either retry the word or move on.
    if (lastPhoneme.isNotEmpty) {
      phonemeAttemptCount = 0; // reset for new phoneme drill
      _isPhoneme = true;       // <- mark that the NEXT attempt is phoneme-focused

      await _speechService.playTts(lastPhoneme);
    }

    // increment word attempt count AFTER scheduling phoneme drill
    // so we know how many total word tries they've burned
    wordAttemptCount += 1;
  }

  // -------------------------
  // PHONEME evaluation path
  // (called after child does that ONE phoneme attempt)
  // -------------------------
  Future<void> _handlePhonemeEvaluation() async {
    if (lastPhoneme.isEmpty) {
      debugPrint("No lastPhoneme set, can't phoneme-eval");
      // fallback: just go back to word or next word
      await _afterPhonemeDecision();
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

    phonemeAttemptCount += 1; // this was their ONE phoneme attempt

    // After exactly one phoneme attempt, we branch:
    await _afterPhonemeDecision();
  }

  // Decide what happens *after* the one phoneme attempt.
  // Rule you asked for:
  // - if they still have word attempts left (canRetryWord == true), ask them to say the WORD again
  // - else advance to next word
  Future<void> _afterPhonemeDecision() async {
    // We are done with dedicated phoneme mode no matter what.
    _isPhoneme = false;

    if (canRetryWord) {
      // we still have tries left for this word
      await _speechService.playTts("Now try the whole word $current_word again.");
      // (we don't advance wordAttemptCount here;
      //  it's already incremented in _handleWordEvaluation when we first failed the word)
    } else {
      // no tries left -> move to next word
      _advanceToNextWord();
    }
  }

  // advance to next word completely
  void _advanceToNextWord() {
    setState(() {
      wordAttemptCount = 1;       // reset attempts for new word
      phonemeAttemptCount = 0;    // reset
      _isPhoneme = false;         // we start in word mode
      lastPhoneme = "";           // clear
      current_word = word_generator.generate_word();
    });

    tts.speak("Say $current_word!");
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
