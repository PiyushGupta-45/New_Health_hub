import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class HuggingFaceService {
  HuggingFaceService() {
    _apiKey = dotenv.env['HF_API_KEY']?.trim() ?? '';

    final model = dotenv.env['HF_MODEL']?.trim();
    _model = (model != null && model.isNotEmpty)
        ? model
        : 'HuggingFaceH4/zephyr-7b-beta';
  }

  late final String _apiKey;
  late final String _model;

  Future<String> generateText(String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception('HF_API_KEY missing in .env');
    }
    final uri = Uri.parse('https://api-inference.huggingface.co/models/$_model');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'inputs': prompt,
        'parameters': {
          'max_new_tokens': 600,
          'temperature': 0.7,
          'return_full_text': false,
        },
      }),
    );

    final dynamic data = json.decode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(_extractError(data, response.statusCode));
    }

    final text = _extractText(data);
    if (text.isEmpty) {
      throw Exception('No response text returned from Hugging Face.');
    }
    return text;
  }

  String _extractText(dynamic data) {
    if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
      final first = data.first as Map<String, dynamic>;
      final generated = first['generated_text'];
      if (generated is String && generated.trim().isNotEmpty) {
        return generated.trim();
      }
    }

    if (data is Map<String, dynamic>) {
      final generated = data['generated_text'];
      if (generated is String && generated.trim().isNotEmpty) {
        return generated.trim();
      }

      final choices = data['choices'];
      if (choices is List &&
          choices.isNotEmpty &&
          choices.first is Map<String, dynamic>) {
        final message = (choices.first as Map<String, dynamic>)['message'];
        if (message is Map<String, dynamic>) {
          final content = message['content'];
          if (content is String && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
      }
    }

    return '';
  }

  String _extractError(dynamic data, int statusCode) {
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        return 'Hugging Face request failed ($statusCode): $error';
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return 'Hugging Face request failed ($statusCode): $message';
      }
    }

    return 'Hugging Face request failed ($statusCode).';
  }
}
