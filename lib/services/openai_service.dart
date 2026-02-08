import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  OpenAIService() {
    final key = dotenv.env['OPENAI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('OPENAI_API_KEY missing in .env');
    }
    _apiKey = key;
    _model = dotenv.env['OPENAI_MODEL']?.trim().isNotEmpty == true
        ? dotenv.env['OPENAI_MODEL']!.trim()
        : 'gpt-4.1-mini';
  }

  late final String _apiKey;
  late final String _model;

  Future<String> generateText(String prompt) async {
    final uri = Uri.parse('https://api.openai.com/v1/responses');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'model': _model,
        'input': prompt,
      }),
    );

    final Map<String, dynamic> data = json.decode(response.body);
    if (response.statusCode >= 400) {
      final message = data['error']?['message']?.toString() ??
          'OpenAI request failed (${response.statusCode}).';
      throw Exception(message);
    }

    final text = _extractText(data);
    return text.isNotEmpty ? text : 'No response text.';
  }

  String _extractText(Map<String, dynamic> data) {
    final direct = data['output_text'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final output = data['output'];
    if (output is List) {
      final buffer = StringBuffer();
      for (final item in output) {
        if (item is Map<String, dynamic>) {
          final content = item['content'];
          if (content is List) {
            for (final part in content) {
              if (part is Map<String, dynamic>) {
                final type = part['type']?.toString();
                final text = part['text']?.toString();
                if (type == 'output_text' && text != null && text.isNotEmpty) {
                  buffer.writeln(text);
                } else if (text != null && text.isNotEmpty) {
                  buffer.writeln(text);
                }
              }
            }
          }
        }
      }
      return buffer.toString().trim();
    }

    return '';
  }
}
