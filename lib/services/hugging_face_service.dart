import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class HuggingFaceService {
  HuggingFaceService() {
    _apiKey = (dotenv.env['HF_API_KEY']?.trim().isNotEmpty == true)
        ? dotenv.env['HF_API_KEY']!.trim()
        : (dotenv.env['HUGGINGFACE_API_KEY']?.trim() ?? '');

    final model = (dotenv.env['HF_MODEL']?.trim().isNotEmpty == true)
        ? dotenv.env['HF_MODEL']!.trim()
        : dotenv.env['HUGGINGFACE_MODEL']?.trim();
    _model = (model != null && model.isNotEmpty)
        ? model
        : 'Qwen/Qwen2.5-7B-Instruct';

    final configuredBaseUrl =
        (dotenv.env['HF_BASE_URL']?.trim().isNotEmpty == true)
            ? dotenv.env['HF_BASE_URL']!.trim()
            : dotenv.env['HUGGINGFACE_BASE_URL']?.trim();
    _baseUrl = (configuredBaseUrl != null && configuredBaseUrl.isNotEmpty)
        ? configuredBaseUrl.replaceAll(RegExp(r'/$'), '')
        : 'https://router.huggingface.co/v1';
  }

  late final String _apiKey;
  late final String _model;
  late final String _baseUrl;

  Future<String> generateText(
    String prompt, {
    String? systemPrompt,
    double temperature = 0.2,
    int maxTokens = 600,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('HF_API_KEY/HUGGINGFACE_API_KEY missing in .env');
    }
    final uri = Uri.parse('$_baseUrl/chat/completions');
    final messages = <Map<String, String>>[
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        {'role': 'system', 'content': systemPrompt.trim()},
      {'role': 'user', 'content': prompt},
    ];
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'model': _model,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
      }),
    );

    final dynamic data = _tryParseJson(response.body);
    if (response.statusCode >= 400) {
      throw Exception(_extractError(data, response.statusCode, response.body));
    }

    final text = _extractText(data);
    if (text.isEmpty) {
      throw Exception('No response text returned from Hugging Face.');
    }
    return text;
  }

  String _extractText(dynamic data) {
    if (data is Map<String, dynamic>) {
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

  dynamic _tryParseJson(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  String _extractError(dynamic data, int statusCode, String rawBody) {
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final msg = error['message']?.toString();
        if (msg != null && msg.isNotEmpty) {
          return 'Hugging Face request failed ($statusCode): $msg';
        }
      }
      if (error is String && error.isNotEmpty) {
        if (statusCode == 410 || error.toLowerCase().contains('deprecated')) {
          return 'Hugging Face request failed ($statusCode): $error';
        }
        return 'Hugging Face request failed ($statusCode): $error';
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return 'Hugging Face request failed ($statusCode): $message';
      }
    }

    if (rawBody.trim().isNotEmpty) {
      return 'Hugging Face request failed ($statusCode): ${rawBody.trim()}';
    }
    return 'Hugging Face request failed ($statusCode). Check HF_MODEL and API key.';
  }
}
