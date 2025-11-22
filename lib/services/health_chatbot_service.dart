// Health-focused AI Chatbot Service using Google Gemini AI
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HealthChatbotService {
  static final HealthChatbotService _instance = HealthChatbotService._internal();
  factory HealthChatbotService() => _instance;
  HealthChatbotService._internal();

  GenerativeModel? _model;
  ChatSession? _chatSession;

  // Initialize Gemini AI model
  void _initializeModel() {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return; // Don't throw, just return - will be handled in getResponse
      }

      _model = GenerativeModel(
        model: 'gemini-pro',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
        systemInstruction: Content.system(
          'You are a helpful and friendly health and wellness assistant. '
          'You provide accurate, evidence-based information about nutrition, fitness, exercise, '
          'weight management, sleep, posture, and general wellness. '
          'Always be encouraging and supportive. If asked about medical conditions or symptoms, '
          'recommend consulting a healthcare professional. Keep responses concise but informative.',
        ),
      );

      _chatSession = _model?.startChat();
    } catch (e) {
      // Silently handle initialization errors - will show error message when user tries to chat
      print('Error initializing Gemini AI: $e');
    }
  }

  // Get response from Gemini AI
  Future<String> getResponse(String question) async {
    try {
      // Check if API key exists
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return '⚠️ Gemini API key not configured.\n\n'
            'To use the AI chatbot, please:\n'
            '1. Get your API key from https://makersuite.google.com/app/apikey\n'
            '2. Add GEMINI_API_KEY=your_key_here to your .env file\n'
            '3. Restart the app';
      }

      // Initialize model if not already done
      if (_model == null || _chatSession == null) {
        _initializeModel();
      }

      if (_chatSession == null || _model == null) {
        return 'Sorry, I\'m having trouble connecting. Please check your API key configuration.';
      }

      // Send message to Gemini
      final response = await _chatSession!.sendMessage(
        Content.text(question),
      );

      // Extract text from response
      final text = response.text;
      if (text == null || text.isEmpty) {
        return 'I apologize, but I couldn\'t generate a response. Please try rephrasing your question.';
      }

      return text;
    } catch (e) {
      // Handle errors gracefully
      if (e.toString().contains('API_KEY') || e.toString().contains('api key')) {
        return 'API key error: Please make sure GEMINI_API_KEY is set in your .env file.';
      }
      
      // Try to reinitialize on error
      try {
        _initializeModel();
        if (_chatSession != null) {
          final response = await _chatSession!.sendMessage(
            Content.text(question),
          );
          return response.text ?? 'Sorry, I couldn\'t generate a response.';
        }
      } catch (_) {
        // Fallback response
        return 'I apologize, but I\'m experiencing technical difficulties. '
            'Please try again in a moment. If the problem persists, check your internet connection and API configuration.';
      }
      
      return 'I apologize, but I\'m experiencing technical difficulties. Please try again.';
    }
  }

  // Get greeting message
  String getGreeting() {
    return 'Hi! I\'m your Health Assistant powered by AI 🤖\n\n'
        'I can help you with:\n'
        '• Nutrition & calories\n'
        '• Protein & macronutrients\n'
        '• Diet & meal plans\n'
        '• Exercise & fitness\n'
        '• Weight management\n'
        '• Steps & activity\n'
        '• Sleep & recovery\n'
        '• Posture & wellness\n\n'
        'What would you like to know? 😊';
  }

  // Clear chat history
  void clearChat() {
    _chatSession = null;
    if (_model != null) {
      _chatSession = _model!.startChat();
    }
  }
}
