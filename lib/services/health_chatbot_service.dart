import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'hugging_face_service.dart';

class HealthChatbotService {
  static final HealthChatbotService _instance = HealthChatbotService._internal();
  factory HealthChatbotService() => _instance;
  HealthChatbotService._internal();

  final List<String> _history = [];

  Future<String> getResponse(String question) async {
    final apiKey = dotenv.env['HF_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return 'HF_API_KEY not configured.\n\n'
          'To use the AI chatbot:\n'
          '1. Get an API key from Hugging Face.\n'
          '2. Add HF_API_KEY=your_key_here to your .env file.\n'
          '3. Restart the app.';
    }

    final service = HuggingFaceService();
    final context = _history.isEmpty ? '' : '\nRecent chat:\n${_history.join('\n')}';

    final prompt = '''
You are a helpful health and wellness assistant.
Provide accurate and practical information about nutrition, fitness, posture, sleep, and recovery.
Use concise bullet points where useful.
If asked about diagnosis, medicine, or serious symptoms, advise consulting a qualified healthcare professional.
$context

User question: $question
''';

    try {
      final answer = await service.generateText(prompt);
      _history.add('User: $question');
      _history.add('Assistant: $answer');
      if (_history.length > 12) {
        _history.removeRange(0, _history.length - 12);
      }
      return answer;
    } catch (e) {
      final error = e.toString().toLowerCase();
      if (error.contains('unauthorized') || error.contains('401')) {
        return 'API key error. Check HF_API_KEY in .env and restart the app.';
      }
      if (error.contains('503') || error.contains('loading')) {
        return 'The selected Hugging Face model is warming up. Please retry in a few seconds.';
      }
      if (error.contains('network') || error.contains('connection') || error.contains('timeout')) {
        return 'Connection error. Check your internet and try again.';
      }
      return 'Unable to generate a response right now. Please try again.';
    }
  }

  String getGreeting() {
    return 'Hi! I am your Health Assistant.\n\n'
        'I can help with:\n'
        '- Nutrition and calories\n'
        '- Protein and macros\n'
        '- Diet and meal planning\n'
        '- Exercise and fitness\n'
        '- Sleep and recovery\n'
        '- Posture and wellness\n\n'
        'What would you like to know?';
  }

  void clearChat() {
    _history.clear();
  }
}
