import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';


class TTSService{

  final FlutterTts _tts = FlutterTts();
  
  TTSService(){
    _init();
  }

  Future<void> _init() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setVoice({"name": "en-us-x-sfg#male_1-local", "locale": "en-US"});
  }

  Future<void> speak(String text) async {
    await _tts.stop();  // optional: stop previous speech
    await _tts.speak(text);
  }
  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> setVoice(Map<String, String> voice) async {
    await _tts.setVoice(voice);
  }

  Future<void> speakAndWait(String text) async {
    final completer = Completer<void>();

    _tts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });

    await _tts.speak(text);
    await completer.future;
  }

}