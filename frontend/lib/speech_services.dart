
import 'package:frontend/speech_models.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:io';
import 'PA.dart';

  import 'dart:typed_data';
  import 'package:http/http.dart' as http;
  import 'package:audioplayers/audioplayers.dart';


class SpeechServices {
  
final String _baseUrl = 'https://catechizable-spathose-aletha.ngrok-free.dev';

  Future<PAResult> uploadAudio(File audioFile, String referenceText, GradingLevel level) async {

    String userId = "lolita";
    print("attempting to post to backend");
    final uri = Uri.parse('$_baseUrl/api/speechassess/assess');
    var request = http.MultipartRequest('POST', uri)
      ..fields['referenceText'] = referenceText
      ..fields['type'] = "word"
      ..fields['userId'] = userId
      ..fields['gradinglevel'] = level.name
      ..files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final result = await response.stream.bytesToString();

      final jsonMap = jsonDecode(result);
      //final json = jsonDecode(result);
      final paResult = PAResult.fromJson(jsonMap);
      
      //return json.toDouble() ?? 0.0;
      return paResult;

    } else {
      throw Exception('Failed to get assessment from backend: ${response.statusCode}');
    }
  }

  Future<void> playTts(String phoneme) async {
    debugPrint("even just made it to playtts #thankful");

    final uri = Uri.parse('$_baseUrl/api/tts/speak');
    final request = http.MultipartRequest('POST', uri)
      ..fields['text'] = phoneme;

    final response = await request.send();

    if (response.statusCode == 200) {
      final bytes = await response.stream.toBytes();

      // Play the audio
      final player = AudioPlayer();
      await player.play(BytesSource(bytes));
    } else {
      throw Exception('TTS failed: ${response.statusCode}');
    }
  }



}

