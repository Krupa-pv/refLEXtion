import 'package:frontend/speech_models.dart';

import 'recorder_controller.dart';
import 'PA.dart';
import 'package:flutter/material.dart';
import 'speech_services.dart';


class SpeechController {
  final RecordingService _recorder = RecordingService();
  final SpeechServices _speechService = SpeechServices();

  /// Called by your “Start” button.
  Future<void> onStartClicked(String expectedWord, BuildContext context) async {
    try {
      print("recorder started");
      await _recorder.start();
    } on MicPermissionException catch (e) {
    print(' start error (mic permission): $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
    }catch (e) {
      print(' start error: $e');
    }
  }

  /// Called by your “Stop / Upload” button.
  Future<PAResult?> onStopClicked(String expectedWord, GradingLevel level) async {
    try {
      print("recorder has been stopped");
      final file = await _recorder.stop();
      if (file == null) throw Exception('No file recorded');
      //_recorder.exportRecordingToDownloads(file);
      return await _speechService.uploadAudio(file, expectedWord, level);
    } catch (e) {
      print('stop/upload error: $e');

      return null;
    }
  }


  /// Forward dispose when your controller dies.
  Future<void> dispose() => _recorder.dispose();
}
