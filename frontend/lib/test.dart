


import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:io';



class SpeechServices {
  
  String simulator = "localhost";
  final String _baseUrl = "http://localhost:5250";
  Future<bool> CheckConnection() async {
    final String apiUrl = '$_baseUrl/api/test';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        debugPrint('Connection successful: ${response.body}');
        return true;
      } else {
        debugPrint('Connection failed. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error connecting to server: $e');
      return false;
    }
  }


  Future<List<String>> generateWordAsync(String userId, String difficulty) async {
    try{
      
    var wordRequest = {
      'userId': '5',
        'grade': '1',
        'readingLevel': "beginner",
        'interests': 'nature',
        'troubleWords': [],
        'difficulty': 'easy',

    };

    var response = await http.post(
      Uri.parse('$_baseUrl/api/AIstory/generate_word'),
      headers: {'Content-Type': 'application/json'},
      body:jsonEncode(wordRequest),
    );
    
    print('Status: ${response.statusCode}');
    print('Body: $response.body}');


    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final words = (jsonResponse['words'] as List?)?.map((e) => e.toString()).toList() ?? [];
      return words;
    } else {
      debugPrint('Error generating words: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    debugPrint('generateWordAsync error: $e');
    return [];
  }
  }
}