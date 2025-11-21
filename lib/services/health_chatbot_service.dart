// Health-focused AI Chatbot Service
// Trained specifically for health, fitness, nutrition, and wellness topics

class HealthChatbotService {
  static final HealthChatbotService _instance = HealthChatbotService._internal();
  factory HealthChatbotService() => _instance;
  HealthChatbotService._internal();

  // Health-related keywords to detect if question is health-related
  final List<String> _healthKeywords = [
    'calorie', 'calories', 'protein', 'carb', 'carbohydrate', 'fat', 'diet', 'nutrition',
    'exercise', 'workout', 'fitness', 'weight', 'muscle', 'strength', 'cardio', 'yoga',
    'steps', 'walking', 'running', 'jogging', 'health', 'wellness', 'vitamin', 'mineral',
    'meal', 'food', 'eating', 'breakfast', 'lunch', 'dinner', 'snack', 'hydration', 'water',
    'sleep', 'rest', 'recovery', 'stretch', 'posture', 'back pain', 'joint', 'bone',
    'metabolism', 'burn', 'lose weight', 'gain weight', 'muscle mass', 'body fat',
    'bmi', 'heart rate', 'blood pressure', 'cholesterol', 'sugar', 'diabetes',
    'vegetarian', 'vegan', 'keto', 'paleo', 'mediterranean', 'intermittent fasting',
    'supplement', 'pre-workout', 'post-workout', 'protein shake', 'smoothie',
    'healthy', 'unhealthy', 'nutrient', 'fiber', 'antioxidant', 'omega', 'calcium',
    'iron', 'zinc', 'magnesium', 'potassium', 'sodium', 'vitamin a', 'vitamin b',
    'vitamin c', 'vitamin d', 'vitamin e', 'vitamin k', 'b12', 'folate', 'biotin'
  ];

  // Knowledge base for health-related questions
  final Map<String, List<String>> _knowledgeBase = {
    'calories': [
      'The average adult needs about 2000-2500 calories per day for women and 2500-3000 for men, depending on activity level.',
      'To lose weight, create a calorie deficit of 500-1000 calories per day, which can lead to 1-2 pounds of weight loss per week.',
      'To gain weight, consume 300-500 calories more than your maintenance level.',
      'Calorie needs vary based on age, gender, activity level, muscle mass, and metabolism.',
      '1 pound of body weight equals approximately 3500 calories.',
    ],
    'protein': [
      'The recommended daily protein intake is 0.8-1.2 grams per kilogram of body weight (0.36-0.54 grams per pound).',
      'Athletes and active individuals may need 1.2-2.0 grams per kilogram of body weight.',
      'Good protein sources include: lean meats, fish, eggs, dairy, legumes, nuts, seeds, and tofu.',
      'Protein helps build and repair muscles, supports immune function, and keeps you feeling full.',
      'Aim to include protein in every meal for optimal muscle recovery and satiety.',
    ],
    'diet': [
      'A balanced diet includes: fruits, vegetables, whole grains, lean proteins, and healthy fats.',
      'The Mediterranean diet emphasizes fish, olive oil, vegetables, and whole grains.',
      'The DASH diet focuses on reducing sodium and includes fruits, vegetables, and low-fat dairy.',
      'Intermittent fasting can help with weight loss but should be done carefully and may not suit everyone.',
      'Avoid extreme diets. Focus on sustainable, long-term healthy eating habits.',
    ],
    'exercise': [
      'Aim for at least 150 minutes of moderate-intensity exercise or 75 minutes of vigorous exercise per week.',
      'Include both cardio (running, cycling, swimming) and strength training (weights, resistance bands) in your routine.',
      'Start slowly and gradually increase intensity to prevent injury.',
      'Rest days are important for muscle recovery and preventing overtraining.',
      'Warm up before exercise and cool down afterward to reduce injury risk.',
    ],
    'weight': [
      'Healthy weight loss is 1-2 pounds per week. Rapid weight loss can be unhealthy and unsustainable.',
      'Focus on body composition (muscle vs. fat) rather than just the number on the scale.',
      'Weight fluctuates daily due to water retention, food intake, and other factors.',
      'A combination of diet and exercise is most effective for weight management.',
      'Consult a healthcare provider before starting any weight loss program.',
    ],
    'steps': [
      'The general recommendation is 10,000 steps per day, but any increase in daily steps is beneficial.',
      '10,000 steps roughly equals 5 miles or 8 kilometers of walking.',
      'Walking is a low-impact exercise suitable for most people.',
      'You can break up steps throughout the day - every bit counts!',
      'Increasing daily steps can improve cardiovascular health, mood, and energy levels.',
    ],
    'nutrition': [
      'Eat a variety of colorful fruits and vegetables to get different nutrients.',
      'Choose whole grains over refined grains for better fiber and nutrient content.',
      'Limit processed foods, added sugars, and saturated fats.',
      'Stay hydrated - aim for 8-10 glasses of water per day, more if you\'re active.',
      'Read nutrition labels to make informed food choices.',
    ],
    'muscle': [
      'Muscle building requires progressive overload - gradually increasing weight or reps.',
      'Protein intake is crucial for muscle repair and growth after workouts.',
      'Allow 48 hours of rest between training the same muscle groups.',
      'Compound exercises (squats, deadlifts, bench press) are effective for building muscle.',
      'Consistency and proper form are more important than lifting heavy weights.',
    ],
    'hydration': [
      'Drink water throughout the day, not just when you\'re thirsty.',
      'Active individuals need more water - drink before, during, and after exercise.',
      'Signs of dehydration include: dark urine, fatigue, dizziness, and dry mouth.',
      'Water needs vary but generally 8-10 glasses (2-2.5 liters) per day is recommended.',
      'Foods like fruits and vegetables also contribute to your daily hydration needs.',
    ],
    'sleep': [
      'Adults need 7-9 hours of quality sleep per night for optimal health.',
      'Poor sleep can affect metabolism, immune function, and exercise recovery.',
      'Establish a consistent sleep schedule, even on weekends.',
      'Avoid screens and heavy meals before bedtime for better sleep quality.',
      'Sleep is crucial for muscle recovery and growth after workouts.',
    ],
    'posture': [
      'Good posture reduces strain on muscles and joints, preventing pain and injury.',
      'When sitting, keep feet flat on the floor, back straight, and shoulders relaxed.',
      'Take breaks every 30 minutes if sitting for long periods.',
      'Strengthen core muscles to support better posture.',
      'Ergonomic workspace setup can help maintain good posture throughout the day.',
    ],
  };

  // Check if question is health-related
  bool isHealthRelated(String question) {
    final lowerQuestion = question.toLowerCase();
    return _healthKeywords.any((keyword) => lowerQuestion.contains(keyword));
  }

  // Get response based on question
  Future<String> getResponse(String question) async {
    // Simulate thinking delay for more natural conversation
    await Future.delayed(const Duration(milliseconds: 500));

    final lowerQuestion = question.toLowerCase();

    // Check if question is health-related
    if (!isHealthRelated(question)) {
      return 'I\'m a health and wellness assistant. I can help you with questions about:\n'
          '• Nutrition and calories\n'
          '• Protein and macronutrients\n'
          '• Diet plans and meal planning\n'
          '• Exercise and fitness\n'
          '• Weight management\n'
          '• Steps and activity tracking\n'
          '• Sleep and recovery\n'
          '• Posture and wellness\n\n'
          'Please ask me something health-related! 😊';
    }

    // Search for relevant topic in knowledge base
    for (final entry in _knowledgeBase.entries) {
      if (lowerQuestion.contains(entry.key)) {
        final responses = entry.value;
        // Return a random response from the topic
        return responses[DateTime.now().millisecond % responses.length];
      }
    }

    // Check for specific patterns
    if (lowerQuestion.contains('how many calories') || lowerQuestion.contains('calorie intake')) {
      return _knowledgeBase['calories']![0];
    }

    if (lowerQuestion.contains('how much protein') || lowerQuestion.contains('protein intake')) {
      return _knowledgeBase['protein']![0];
    }

    if (lowerQuestion.contains('diet plan') || lowerQuestion.contains('meal plan')) {
      return 'Here\'s a balanced daily meal plan:\n\n'
          '🌅 Breakfast: Whole grain cereal with fruits and nuts, or eggs with whole grain toast\n'
          '🍎 Mid-morning: A piece of fruit or a handful of nuts\n'
          '🍽️ Lunch: Grilled chicken/fish with vegetables and quinoa/brown rice\n'
          '🥤 Afternoon: Greek yogurt or a protein smoothie\n'
          '🌙 Dinner: Lean protein with steamed vegetables and a small portion of whole grains\n\n'
          'Remember to adjust portions based on your calorie needs and activity level!';
    }

    if (lowerQuestion.contains('lose weight') || lowerQuestion.contains('weight loss')) {
      return 'For healthy weight loss:\n\n'
          '✅ Create a calorie deficit of 500-1000 calories per day\n'
          '✅ Combine cardio and strength training\n'
          '✅ Eat whole, nutrient-dense foods\n'
          '✅ Stay hydrated (8-10 glasses of water daily)\n'
          '✅ Get 7-9 hours of sleep\n'
          '✅ Be patient - aim for 1-2 pounds per week\n\n'
          'Remember: Sustainable changes work better than quick fixes!';
    }

    if (lowerQuestion.contains('gain weight') || lowerQuestion.contains('build muscle')) {
      return 'To gain healthy weight and build muscle:\n\n'
          '💪 Eat 300-500 calories above maintenance\n'
          '💪 Consume 1.2-2.0g protein per kg body weight\n'
          '💪 Focus on strength training 3-4 times per week\n'
          '💪 Include compound exercises (squats, deadlifts, bench press)\n'
          '💪 Allow proper rest and recovery between workouts\n'
          '💪 Stay consistent with your routine\n\n'
          'Patience and consistency are key!';
    }

    if (lowerQuestion.contains('workout') || lowerQuestion.contains('exercise routine')) {
      return 'A balanced weekly workout routine:\n\n'
          '🏃 Cardio: 3-4 times per week (30-45 min)\n'
          '💪 Strength Training: 2-3 times per week (45-60 min)\n'
          '🧘 Flexibility: 2-3 times per week (yoga/stretching)\n'
          '😴 Rest Days: 1-2 days per week\n\n'
          'Start with what you can do and gradually increase intensity!';
    }

    if (lowerQuestion.contains('protein sources') || lowerQuestion.contains('high protein')) {
      return 'Excellent protein sources:\n\n'
          '🥩 Lean meats: Chicken breast, turkey, lean beef\n'
          '🐟 Fish: Salmon, tuna, cod\n'
          '🥚 Eggs: Whole eggs or egg whites\n'
          '🥛 Dairy: Greek yogurt, cottage cheese, milk\n'
          '🌱 Plant-based: Lentils, chickpeas, tofu, tempeh\n'
          '🥜 Nuts & Seeds: Almonds, chia seeds, hemp seeds\n'
          '🌾 Grains: Quinoa, amaranth\n\n'
          'Aim to include protein in every meal!';
    }

    if (lowerQuestion.contains('healthy snack') || lowerQuestion.contains('snack ideas')) {
      return 'Healthy snack options:\n\n'
          '🍎 Apple with almond butter\n'
          '🥜 Mixed nuts (handful)\n'
          '🥛 Greek yogurt with berries\n'
          '🥕 Carrot sticks with hummus\n'
          '🥚 Hard-boiled eggs\n'
          '🍌 Banana with peanut butter\n'
          '🥑 Avocado on whole grain toast\n'
          '🥤 Protein smoothie\n\n'
          'Choose snacks that combine protein and fiber for sustained energy!';
    }

    // Default health response
    return 'Great health question! Here are some general wellness tips:\n\n'
        '✅ Eat a balanced diet with plenty of fruits and vegetables\n'
        '✅ Stay active - aim for 10,000 steps daily\n'
        '✅ Get 7-9 hours of quality sleep\n'
        '✅ Stay hydrated throughout the day\n'
        '✅ Include both cardio and strength training\n'
        '✅ Listen to your body and rest when needed\n'
        '✅ Practice good posture, especially when sitting\n\n'
        'Feel free to ask me more specific questions about nutrition, exercise, or wellness! 💪';
  }

  // Get greeting message
  String getGreeting() {
    return 'Hi! I\'m your Health Assistant 🤖\n\n'
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
}

