import 'dart:convert';
import 'package:http/http.dart' as http;

class AvatarVideoService {
  final String _baseUrl = 'https://catechizable-spathose-aletha.ngrok-free.dev';

  Future<Map<String, dynamic>?> generateAvatarData({
    required String glbUrl,
    required String text,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/AvatarVideo/generate')
          .replace(queryParameters: {'glbUrl': glbUrl, 'text': text});

      final response = await http.post(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Backend error: ${response.statusCode} ${response.reasonPhrase}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error generating avatar: $e');
      return null;
    }
  }
}
