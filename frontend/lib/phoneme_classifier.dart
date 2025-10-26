import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:onnxruntime/onnxruntime.dart';


import 'package:frontend/model/feature_extraction.dart';

extension ArgMaxExt on List<double> {
  int argMaxIndex() {
    var maxIdx = 0;
    var maxVal = this[0];
    for (var i = 1; i < length; i++) {
      if (this[i] > maxVal) {
        maxVal = this[i];
        maxIdx = i;
      }
    }
    return maxIdx;
  }
}

class PhonemeQualityModel {
  late OrtSession _session;
  late String _phoneme;

  // maps class index -> class label string ("GOOD", "BAD", etc.)
  // comes from <phoneme>_class_label_map.json
  late Map<String, dynamic> _idxToLabel;

  // maps label string -> feedback string
  // comes from <phoneme>_label_feedback_map.json
  late Map<String, dynamic> _labelToFeedback;

  bool _loaded = false;
  bool get isLoaded => _loaded;
  Map<String, String> phonemeMap = {'u': "O", 'æ': "A", 'p':"P"};

  /// load ONNX model + label maps for a specific phoneme
  ///
 
  Future<void> loadModel(String phoneme) async {
    _phoneme = phonemeMap[phoneme]!;
    
    // load label maps
    final classMapAsset = 'assets/models/mappings/class_label_map_$_phoneme.json';
    final feedbackMapAsset = 'assets/models/mappings/label_feedback_map_$_phoneme.json';

    final classJsonString = await rootBundle.loadString(classMapAsset);
    _idxToLabel = jsonDecode(classJsonString);

    final feedbackJsonString = await rootBundle.loadString(feedbackMapAsset);
    _labelToFeedback = jsonDecode(feedbackJsonString);

    // load ONNX model bytes from assets and copy to a local file path
    final modelAssetPath = 'assets/models/phoneme_models/${_phoneme}_model.onnx';
    final onnxBytes = await rootBundle.load(modelAssetPath);

    final appDir = await getApplicationDocumentsDirectory();
    final modelDirPath = '${appDir.path}/loaded_models';
    await Directory(modelDirPath).create(recursive: true);

    final modelPath = '$modelDirPath/${_phoneme}_model.onnx';
    final modelFile = File(modelPath);

    await modelFile.writeAsBytes(
      onnxBytes.buffer.asUint8List(),
      flush: true,
    );

    // create ONNX Runtime session
    final sessionOptions = OrtSessionOptions();
    _session = OrtSession.fromFile(modelFile, sessionOptions);

    _loaded = true;
    print("onnx model for $_phoneme loaded at $modelPath");
  }

  

  /// convert a FrameFeatures struct into model input vector
  /// this list must stay in sync with feature_cols used during training
  ///
  /// current order:
  /// lip_gap_norm,
  /// mouth_height_norm,
  /// round_ratio,
  /// lip_gap_prev_norm,
  /// lip_gap_delta_norm,
  /// mouth_height_delta_norm
  

  /// smooth frame-level predictions so jittery 1-frame mistakes don't dominate
  /// window = how far back to look (inclusive of current frame)
  List<String> _smoothSlidingMajority(List<String> rawLabels,
      {int window = 5}) {
    final smoothed = <String>[];

    for (int i = 0; i < rawLabels.length; i++) {
      final start = (i - window + 1) < 0 ? 0 : (i - window + 1);
      final slice = rawLabels.sublist(start, i + 1);

      final counts = <String, int>{};
      for (final l in slice) {
        counts[l] = (counts[l] ?? 0) + 1;
      }

      String best = slice.first;
      int bestCount = 0;
      counts.forEach((lbl, c) {
        if (c > bestCount) {
          bestCount = c;
          best = lbl;
        }
      });

      smoothed.add(best);
    }

    return smoothed;
  }

  /// pick the mode of a list of labels
  String _majorityVote(List<String> labels) {
    final counts = <String, int>{};
    for (final l in labels) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
    String bestLabel = labels.first;
    int bestCount = 0;
    counts.forEach((lbl, c) {
      if (c > bestCount) {
        bestCount = c;
        bestLabel = lbl;
      }
    });
    return bestLabel;
  }

  /// full attempt scoring:
  /// - parse raw JSON with all frames from one attempt
  /// - extract mouth features per frame
  /// - run ONNX per frame
  /// - smooth timeline
  /// - majority vote final label
  /// - map to human feedback
  ///
  /// returns: feedback string for this attempt
  Future<String> getPhonemeFeedback(String jsonInput) async {
  if (!_loaded) {
    throw StateError("model not loaded");
  }

  // 1. parse attempt JSON into raw per-frame geometry
  final rawFrames = extractAllRawFrameFeaturesFromPayload(jsonInput);
  if (rawFrames.isEmpty) {
    return "No mouth data.";
  }

  // 2. build 15-dim feature vectors for every frame, in order
  final frameVectors = buildFeatureVectorsForAttempt(rawFrames);
  // frameVectors[i] is List<double> length 15

  // 3. run model on each frame and collect predicted labels
  final preds = <String>[];
  for (final vec in frameVectors) {
    final label = predictClassForVector(vec); // we'll write this below
    preds.add(label);
  }

  // 4. majority vote
  final finalLabel = _majorityVote(preds);

  // 5. map to feedback
  final feedback = _labelToFeedback[finalLabel] ??
      "Keep practicing $_phoneme.";

  return feedback;
}

int _argMaxIndex(List<double> vals) {
  var bestI = 0;
  var bestV = vals[0];
  for (var i = 1; i < vals.length; i++) {
    if (vals[i] > bestV) {
      bestV = vals[i];
      bestI = i;
    }
  }
  return bestI;
}

OrtValueTensor _makeInputTensor(List<double> featureVec) {
  final data = Float32List.fromList(featureVec);
  final shape = [1, featureVec.length]; // [1, 15]
  return OrtValueTensor.createTensorWithDataList(data, shape);
}

String predictClassForVector(List<double> featureVec) {
  if (!_loaded) {
    throw StateError("model not loaded yet");
  }

  // 1. Build input tensor: shape [1, feature_dim]
  final inputFloats = Float32List.fromList(featureVec);
  final inputShape = [1, featureVec.length];
  final inputTensor = OrtValueTensor.createTensorWithDataList(
    inputFloats,
    inputShape,
  );

  // 2. Names
  final inputName = _session.inputNames.first;
  final outputName = _session.outputNames.first;

  // 3. Inputs map
  final inputs = <String, OrtValueTensor>{
    inputName: inputTensor,
  };

  final runOptions = OrtRunOptions();

  // 4. Run inference
  final results = _session.run(
    runOptions,
    inputs,
    [outputName],
  );

  if (results.isEmpty || results[0] == null) {
    throw StateError("onnx runtime returned empty/null output");
  }

  final outTensor = results[0] as OrtValueTensor;
  final rawVal = outTensor.value;

  // 5. Normalize rawVal → List<double> logits
  late final List<double> logits;

  if (rawVal is Float32List) {
    // flat float32
    logits = rawVal.toList();
  } else if (rawVal is List<double>) {
    // already flat doubles
    logits = rawVal;
  } else if (rawVal is List<num>) {
    // flat nums
    logits = rawVal.map((n) => n.toDouble()).toList();
  } else if (rawVal is List<List<double>>) {
    // shape [1, num_classes] as List<List<double>>
    if (rawVal.isEmpty) {
      throw StateError("model output empty outer list");
    }
    logits = rawVal.first;
  } else if (rawVal is List<List<num>>) {
    // shape [1, num_classes] as List<List<num>>
    if (rawVal.isEmpty) {
      throw StateError("model output empty outer list");
    }
    logits = rawVal.first.map((n) => n.toDouble()).toList();
  } else {
    throw StateError("Unexpected tensor value type: ${rawVal.runtimeType}");
  }

  // 6. Argmax -> class index -> human label
  final predIdx = _argMaxIndex(logits);
  final predLabel = _idxToLabel["$predIdx"] ?? "UNKNOWN";

  return predLabel;
}


}