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

      // Use the standard gemini-pro model (most compatible)
      // Simplified version without systemInstruction to test
      _model = GenerativeModel(
        model: 'gemini-pro',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
      );

      _chatSession = _model?.startChat();
      print('Successfully initialized Gemini AI with model: gemini-pro');
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
      
      // Debug: Check if API key is loaded (first few chars only)
      print('API Key loaded: ${apiKey.substring(0, apiKey.length > 10 ? 10 : apiKey.length)}...');

      // Initialize model if not already done
      if (_model == null) {
        _initializeModel();
      }

      if (_model == null) {
        return 'Sorry, I\'m having trouble connecting. Please check your API key configuration.';
      }

      // Create a new chat session for each message to avoid session issues
      final chatSession = _model!.startChat();
      
      // Add context in the first message
      final prompt = 'You are a helpful health and wellness assistant. '
          'Provide accurate, evidence-based information about nutrition, fitness, exercise, '
          'weight management, sleep, posture, and wellness. '
          'Always be encouraging. If asked about medical conditions, recommend consulting a healthcare professional. '
          'Keep responses concise.\n\nUser question: $question';
      
      // Send message to Gemini
      final response = await chatSession.sendMessage(
        Content.text(prompt),
      );

      // Extract text from response - try multiple ways
      String? text = response.text;
      
      // If text is null, try to get from candidates
      if (text == null || text.isEmpty) {
        if (response.candidates.isNotEmpty) {
          final candidate = response.candidates.first;
          if (candidate.content.parts.isNotEmpty) {
            text = candidate.content.parts
                .whereType<TextPart>()
                .map((part) => part.text)
                .join(' ');
          }
        }
      }
      
      if (text == null || text.isEmpty) {
        print('Response structure: ${response.toString()}');
        print('Candidates: ${response.candidates.length}');
        return 'I apologize, but I couldn\'t generate a response. Please try rephrasing your question.';
      }

      return text;
    } catch (e) {
      // Log the actual error for debugging
      print('Gemini AI Error: $e');
      print('Error type: ${e.runtimeType}');
      
      // Handle specific error types
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('api_key') || errorString.contains('api key') || errorString.contains('invalid api key')) {
        return '❌ API Key Error\n\n'
            'Your API key may be invalid or not properly configured.\n\n'
            'Please check:\n'
            '1. The API key in your .env file is correct\n'
            '2. The API key has not expired\n'
            '3. Restart the app after adding the key';
      }
      
      if (errorString.contains('quota') || errorString.contains('limit')) {
        return '⚠️ API Quota Exceeded\n\n'
            'You have reached the API usage limit. Please try again later or check your Google Cloud Console for quota limits.';
      }
      
      if (errorString.contains('network') || errorString.contains('connection') || errorString.contains('timeout')) {
        return '🌐 Connection Error\n\n'
            'Unable to connect to Gemini AI. Please check your internet connection and try again.';
      }
      
      if (errorString.contains('permission') || errorString.contains('forbidden')) {
        return '🔒 Permission Error\n\n'
            'Your API key may not have the necessary permissions. Please check your Google Cloud Console settings.';
      }
      
      // Try to reinitialize on error
      try {
        _model = null;
        _chatSession = null;
        _initializeModel();
        if (_chatSession != null && _model != null) {
          final response = await _chatSession!.sendMessage(
            Content.text(question),
          );
          return response.text ?? 'Sorry, I couldn\'t generate a response.';
        }
      } catch (retryError) {
        print('Retry also failed: $retryError');
        // Show more detailed error for debugging
        return '⚠️ Error: ${e.toString().split(':').last.trim()}\n\n'
            'Please check:\n'
            '• Your internet connection\n'
            '• API key is correct in .env file\n'
            '• Gemini API is enabled in Google Cloud Console\n'
            '• Try restarting the app';
      }
      
      return '⚠️ Error: ${e.toString().split(':').last.trim()}\n\nPlease try again or check your API configuration.';
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
