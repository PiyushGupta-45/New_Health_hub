import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../services/challenge_service.dart';
import '../services/auth_service.dart';
import '../controllers/health_sync_controller.dart';

class GamesAndChallengesPage extends StatefulWidget {
  final HealthSyncController? healthSyncController;
  
  const GamesAndChallengesPage({super.key, this.healthSyncController});

  @override
  State<GamesAndChallengesPage> createState() => _GamesAndChallengesPageState();
}

class _GamesAndChallengesPageState extends State<GamesAndChallengesPage> {
  final ChallengeService _challengeService = ChallengeService();
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final user = await _authService.getStoredUser();
    setState(() {
      _isAuthenticated = user != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          const Text(
            'Games & Challenges',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Challenges Section
          if (_isAuthenticated) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Challenges',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChallengesListPage(
                        healthSyncController: widget.healthSyncController,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showCreateChallengeDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Challenge'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
          ],
          // Games Section
          const Text(
            'Games',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildGameCard(
            context,
            title: 'Step Challenge',
            description: 'Track your daily steps progress',
            icon: Icons.directions_walk,
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StepChallengeGame(
                  healthSyncController: widget.healthSyncController,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildGameCard(
            context,
            title: 'Fitness Quiz',
            description: 'Test your knowledge about health and fitness',
            icon: Icons.quiz,
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FitnessQuizGame()),
            ),
          ),
          const SizedBox(height: 16),
          _buildGameCard(
            context,
            title: 'Reaction Time Test',
            description: 'Test your reflexes and reaction speed',
            icon: Icons.timer,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReactionTimeGame()),
            ),
          ),
          const SizedBox(height: 16),
          _buildGameCard(
            context,
            title: 'Memory Card Game',
            description: 'Match pairs and improve your memory',
            icon: Icons.memory,
            color: Colors.purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MemoryCardGame()),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildGameCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateChallengeDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final targetStepsController = TextEditingController(text: '10000');
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Challenge'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Challenge Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetStepsController,
                  decoration: const InputDecoration(
                    labelText: 'Target Steps',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text('${startDate.toLocal().toString().split('.')[0]}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        startDate = picked;
                        if (endDate.isBefore(startDate)) {
                          endDate = startDate.add(const Duration(days: 7));
                        }
                      });
                    }
                  },
                ),
                ListTile(
                  title: const Text('End Date'),
                  subtitle: Text('${endDate.toLocal().toString().split('.')[0]}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        endDate = picked;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final targetSteps = int.tryParse(targetStepsController.text);
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a title')),
                  );
                  return;
                }
                if (targetSteps == null || targetSteps <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid target steps')),
                  );
                  return;
                }
                Navigator.pop(context);
                // Normalize dates to start of day (midnight) to ensure proper status calculation
                final normalizedStartDate = DateTime(startDate.year, startDate.month, startDate.day);
                final normalizedEndDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59); // End of day
                await _createChallenge(
                  title,
                  descriptionController.text.trim(),
                  targetSteps,
                  normalizedStartDate,
                  normalizedEndDate,
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createChallenge(
    String title,
    String description,
    int targetSteps,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = await _challengeService.createChallenge(
      title: title,
      description: description.isEmpty ? null : description,
      targetSteps: targetSteps,
      startDate: startDate,
      endDate: endDate,
    );

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge created successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to create challenge')),
        );
      }
    }
  }
}

// Step Challenge Game
class StepChallengeGame extends StatefulWidget {
  final HealthSyncController? healthSyncController;
  
  const StepChallengeGame({super.key, this.healthSyncController});

  @override
  State<StepChallengeGame> createState() => _StepChallengeGameState();
}

class _StepChallengeGameState extends State<StepChallengeGame> {
  int _targetSteps = 10000;
  int _currentSteps = 0;
  Timer? _refreshTimer;
  bool _hasShownCompletion = false;

  @override
  void initState() {
    super.initState();
    if (widget.healthSyncController != null) {
      widget.healthSyncController!.addListener(_updateSteps);
      _updateSteps();
      // Refresh every 5 seconds
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        widget.healthSyncController!.sync(force: false);
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    widget.healthSyncController?.removeListener(_updateSteps);
    super.dispose();
  }

  void _updateSteps() {
    if (mounted && widget.healthSyncController != null) {
      setState(() {
        _currentSteps = widget.healthSyncController!.todaySteps;
        if (_currentSteps >= _targetSteps && !_hasShownCompletion) {
          _hasShownCompletion = true;
          _showCompletionDialog();
        } else if (_currentSteps < _targetSteps) {
          _hasShownCompletion = false;
        }
      });
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Challenge Complete!'),
        content: Text('Congratulations! You reached $_targetSteps steps!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentSteps / _targetSteps;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step Challenge'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Daily Step Goal',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 40),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 20,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '$_currentSteps',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '/ $_targetSteps',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 60),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Target Steps',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final steps = int.tryParse(value);
                if (steps != null && steps > 0) {
                  setState(() {
                    _targetSteps = steps;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.healthSyncController != null
                  ? () => widget.healthSyncController!.sync(force: true)
                  : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Steps'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Fitness Quiz Game
class FitnessQuizGame extends StatefulWidget {
  const FitnessQuizGame({super.key});

  @override
  State<FitnessQuizGame> createState() => _FitnessQuizGameState();
}

class _FitnessQuizGameState extends State<FitnessQuizGame> {
  int _currentQuestion = 0;
  int _score = 0;
  int? _selectedAnswer;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'How many minutes of exercise per day is recommended?',
      'answers': ['15 minutes', '30 minutes', '60 minutes', '90 minutes'],
      'correct': 1,
    },
    {
      'question': 'What is the recommended daily water intake?',
      'answers': ['4 glasses', '6 glasses', '8 glasses', '10 glasses'],
      'correct': 2,
    },
    {
      'question': 'Which exercise is best for cardiovascular health?',
      'answers': ['Weight lifting', 'Running', 'Yoga', 'Stretching'],
      'correct': 1,
    },
    {
      'question': 'How many hours of sleep should adults get per night?',
      'answers': ['5-6 hours', '6-7 hours', '7-9 hours', '9-10 hours'],
      'correct': 2,
    },
    {
      'question': 'What percentage of your body should be protein?',
      'answers': ['10-15%', '15-20%', '20-25%', '25-30%'],
      'correct': 1,
    },
  ];

  void _selectAnswer(int index) {
    setState(() {
      _selectedAnswer = index;
    });
  }

  void _nextQuestion() {
    if (_selectedAnswer == null) return;

    if (_selectedAnswer == _questions[_currentQuestion]['correct']) {
      setState(() {
        _score++;
      });
    }

    if (_currentQuestion < _questions.length - 1) {
      setState(() {
        _currentQuestion++;
        _selectedAnswer = null;
      });
    } else {
      _showResults();
    }
  }

  void _showResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Quiz Complete!'),
        content: Text('Your score: $_score / ${_questions.length}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetQuiz();
            },
            child: const Text('Play Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _resetQuiz() {
    setState(() {
      _currentQuestion = 0;
      _score = 0;
      _selectedAnswer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentQuestion >= _questions.length) {
      return const SizedBox.shrink();
    }

    final question = _questions[_currentQuestion];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness Quiz'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_currentQuestion + 1) / _questions.length,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 24),
            Text(
              'Question ${_currentQuestion + 1} of ${_questions.length}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              question['question'],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            ...(question['answers'] as List<String>).asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _selectAnswer(entry.key),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _selectedAnswer == entry.key
                              ? Colors.green.shade100
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedAnswer == entry.key
                                ? Colors.green
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedAnswer == entry.key
                                ? Colors.green.shade900
                                : Colors.black87,
                            fontWeight: _selectedAnswer == entry.key
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            const Spacer(),
            ElevatedButton(
              onPressed: _selectedAnswer != null ? _nextQuestion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _currentQuestion < _questions.length - 1
                    ? 'Next Question'
                    : 'Finish Quiz',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reaction Time Game
class ReactionTimeGame extends StatefulWidget {
  const ReactionTimeGame({super.key});

  @override
  State<ReactionTimeGame> createState() => _ReactionTimeGameState();
}

class _ReactionTimeGameState extends State<ReactionTimeGame> {
  bool _isWaiting = false;
  bool _isReady = false;
  DateTime? _startTime;
  int _reactionTime = 0;
  List<int> _reactionTimes = [];
  Timer? _waitTimer;

  @override
  void dispose() {
    _waitTimer?.cancel();
    super.dispose();
  }

  void _startRound() {
    setState(() {
      _isReady = false;
      _isWaiting = true;
      _reactionTime = 0;
    });

    // Wait random time between 1-5 seconds
    final waitDuration = Duration(milliseconds: 1000 + Random().nextInt(4000));
    _waitTimer = Timer(waitDuration, () {
      if (mounted) {
        setState(() {
          _isWaiting = false;
          _isReady = true;
          _startTime = DateTime.now();
        });
      }
    });
  }

  void _react() {
    if (!_isReady) {
      // Too early!
      setState(() {
        _isWaiting = false;
        _isReady = false;
      });
      _waitTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Too early! Wait for the green screen.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final endTime = DateTime.now();
    final reactionTime = endTime.difference(_startTime!).inMilliseconds;
    setState(() {
      _reactionTime = reactionTime;
      _reactionTimes.add(reactionTime);
      _isReady = false;
    });
  }

  void _reset() {
    _waitTimer?.cancel();
    setState(() {
      _isWaiting = false;
      _isReady = false;
      _reactionTime = 0;
    });
  }

  double _getAverage() {
    if (_reactionTimes.isEmpty) return 0;
    return _reactionTimes.reduce((a, b) => a + b) / _reactionTimes.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reaction Time Test'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _isWaiting || _isReady ? _react : null,
              child: Container(
                width: double.infinity,
                color: _isReady
                    ? Colors.green
                    : _isWaiting
                        ? Colors.red
                        : Colors.grey.shade300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_reactionTime > 0)
                        Text(
                          '$_reactionTime ms',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      else if (_isReady)
                        const Text(
                          'TAP NOW!',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      else if (_isWaiting)
                        const Text(
                          'Wait for green...',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Text(
                          'Tap to start',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              children: [
                if (_reactionTimes.isNotEmpty) ...[
                  Text(
                    'Average: ${_getAverage().toStringAsFixed(0)} ms',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Best: ${_reactionTimes.reduce((a, b) => a < b ? a : b)} ms',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _startRound,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Memory Card Game
class MemoryCardGame extends StatefulWidget {
  const MemoryCardGame({super.key});

  @override
  State<MemoryCardGame> createState() => _MemoryCardGameState();
}

class _MemoryCardGameState extends State<MemoryCardGame> {
  List<int> _cards = [];
  List<bool> _flipped = [];
  List<bool> _matched = [];
  int? _firstCardIndex;
  int _moves = 0;
  int _pairsFound = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    // Create pairs of numbers (0-7, so 8 pairs = 16 cards)
    _cards = List.generate(8, (index) => index)..addAll(List.generate(8, (index) => index));
    _cards.shuffle();
    _flipped = List.filled(16, false);
    _matched = List.filled(16, false);
    _firstCardIndex = null;
    _moves = 0;
    _pairsFound = 0;
  }

  void _flipCard(int index) {
    if (_isProcessing || _flipped[index] || _matched[index]) return;

    setState(() {
      _flipped[index] = true;
    });

    if (_firstCardIndex == null) {
      _firstCardIndex = index;
    } else {
      _moves++;
      _isProcessing = true;
      final firstCard = _cards[_firstCardIndex!];
      final secondCard = _cards[index];

      if (firstCard == secondCard) {
        // Match found!
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _matched[_firstCardIndex!] = true;
              _matched[index] = true;
              _pairsFound++;
              _firstCardIndex = null;
              _isProcessing = false;
            });

            if (_pairsFound == 8) {
              _showWinDialog();
            }
          }
        });
      } else {
        // No match
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _flipped[_firstCardIndex!] = false;
              _flipped[index] = false;
              _firstCardIndex = null;
              _isProcessing = false;
            });
          }
        });
      }
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Congratulations!'),
        content: Text('You completed the game in $_moves moves!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeGame();
            },
            child: const Text('Play Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Card Game'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeGame,
            tooltip: 'New Game',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Moves', '$_moves'),
                _buildStatCard('Pairs Found', '$_pairsFound / 8'),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 16,
                itemBuilder: (context, index) {
                  final isFlipped = _flipped[index];
                  final isMatched = _matched[index];

                  return GestureDetector(
                    onTap: () => _flipCard(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isMatched
                            ? Colors.green.shade300
                            : isFlipped
                                ? Colors.purple.shade100
                                : Colors.purple.shade300,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.purple.shade600,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isFlipped || isMatched
                            ? Text(
                                '${_cards[index]}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade900,
                                ),
                              )
                            : Icon(
                                Icons.help_outline,
                                size: 40,
                                color: Colors.purple.shade700,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Challenges List Page
class ChallengesListPage extends StatefulWidget {
  final HealthSyncController? healthSyncController;
  
  const ChallengesListPage({super.key, this.healthSyncController});

  @override
  State<ChallengesListPage> createState() => _ChallengesListPageState();
}

class _ChallengesListPageState extends State<ChallengesListPage> with SingleTickerProviderStateMixin {
  final ChallengeService _challengeService = ChallengeService();
  late TabController _tabController;
  List<Map<String, dynamic>> _publicChallenges = [];
  List<Map<String, dynamic>> _myChallenges = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadChallenges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);
    final publicResult = await _challengeService.getPublicChallenges();
    final myResult = await _challengeService.getMyChallenges();
    
    if (mounted) {
      setState(() {
        if (publicResult['success'] == true) {
          _publicChallenges = List<Map<String, dynamic>>.from(publicResult['data'] ?? []);
        }
        if (myResult['success'] == true) {
          _myChallenges = List<Map<String, dynamic>>.from(myResult['data'] ?? []);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteChallenge(String challengeId, bool isPublic) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Challenge'),
        content: const Text('Are you sure you want to delete this challenge? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await _challengeService.deleteChallenge(challengeId);
    
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge deleted successfully')),
        );
        // Reload challenges
        _loadChallenges();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to delete challenge')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Public Challenges'),
            Tab(text: 'My Challenges'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPublicChallengesList(),
                _buildMyChallengesList(),
              ],
            ),
    );
  }

  Widget _buildPublicChallengesList() {
    if (_publicChallenges.isEmpty) {
      return const Center(
        child: Text('No public challenges available'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChallenges,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _publicChallenges.length,
        itemBuilder: (context, index) {
          final challenge = _publicChallenges[index];
          return _buildChallengeCard(challenge, isPublic: true);
        },
      ),
    );
  }

  Widget _buildMyChallengesList() {
    if (_myChallenges.isEmpty) {
      return const Center(
        child: Text('You are not participating in any challenges'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChallenges,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myChallenges.length,
        itemBuilder: (context, index) {
          final challenge = _myChallenges[index];
          return _buildChallengeCard(challenge, isPublic: false);
        },
      ),
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge, {required bool isPublic}) {
    // Use backend status as primary source, with frontend recalculation as fallback
    final startDate = DateTime.parse(challenge['startDate']);
    final endDate = DateTime.parse(challenge['endDate']);
    final now = DateTime.now();
    
    // Normalize to start of day for date comparison (ignore time)
    final startOfStart = DateTime(startDate.year, startDate.month, startDate.day);
    final startOfEnd = DateTime(endDate.year, endDate.month, endDate.day);
    final startOfNow = DateTime(now.year, now.month, now.day);
    
    // Calculate status based on dates (same logic as backend)
    String calculatedStatus;
    if (startOfEnd.isBefore(startOfNow)) {
      calculatedStatus = 'completed';
    } else if (startOfStart.isBefore(startOfNow) || startOfStart.isAtSameMomentAs(startOfNow)) {
      calculatedStatus = 'active';
    } else {
      calculatedStatus = 'upcoming';
    }
    
    // Use backend status if available, otherwise use calculated
    // Normalize status to lowercase for comparison
    final status = (challenge['status'] ?? calculatedStatus).toString().toLowerCase();
    
    Color statusColor = Colors.grey;
    String statusText = 'Upcoming';
    
    // Use calculated status if backend status seems wrong and calculated is active
    final finalStatus = (status == 'upcoming' && calculatedStatus == 'active') ? calculatedStatus : status;
    
    if (finalStatus == 'active') {
      statusColor = Colors.green;
      statusText = 'Active';
    } else if (finalStatus == 'completed') {
      statusColor = Colors.blue;
      statusText = 'Completed';
    } else {
      statusColor = Colors.orange;
      statusText = 'Upcoming';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChallengeDetailsPage(
              challengeId: challenge['_id'],
              healthSyncController: widget.healthSyncController,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      challenge['title'] ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Chip(
                        label: Text(statusText),
                        backgroundColor: statusColor.withOpacity(0.2),
                        labelStyle: TextStyle(color: statusColor),
                      ),
                      // Delete button - only show if user is creator
                      // Check both boolean true and string 'true'
                      if (challenge['isCreator'] == true || challenge['isCreator'] == 'true' || challenge['isCreator'] == 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteChallenge(challenge['_id'], isPublic),
                            tooltip: 'Delete challenge',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (challenge['description'] != null && challenge['description'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    challenge['description'],
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.directions_walk, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Target: ${challenge['targetSteps']} steps',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${challenge['participantCount'] ?? 0} participants',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Created by ${challenge['creatorName'] ?? 'Unknown'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              if (isPublic && challenge['isParticipant'] != true)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ElevatedButton(
                    onPressed: () => _joinChallenge(challenge['_id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Join Challenge'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinChallenge(String challengeId) async {
    final result = await _challengeService.joinChallenge(challengeId);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined challenge!')),
        );
        _loadChallenges();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to join challenge')),
        );
      }
    }
  }
}

// Challenge Details Page
class ChallengeDetailsPage extends StatefulWidget {
  final String challengeId;
  final HealthSyncController? healthSyncController;
  
  const ChallengeDetailsPage({
    super.key,
    required this.challengeId,
    this.healthSyncController,
  });

  @override
  State<ChallengeDetailsPage> createState() => _ChallengeDetailsPageState();
}

class _ChallengeDetailsPageState extends State<ChallengeDetailsPage> {
  final ChallengeService _challengeService = ChallengeService();
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _challenge;
  bool _isLoading = false;
  Timer? _refreshTimer;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _getUserId();
    _loadChallenge();
    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadChallenge();
      if (widget.healthSyncController != null) {
        widget.healthSyncController!.sync(force: false);
      }
    });
  }

  Future<void> _getUserId() async {
    final user = await _authService.getStoredUser();
    if (mounted) {
      setState(() {
        _userId = user?['id']?.toString();
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChallenge() async {
    setState(() => _isLoading = true);
    final result = await _challengeService.getChallengeDetails(widget.challengeId);
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _challenge = result['data'];
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _updateMySteps() async {
    if (widget.healthSyncController == null || _challenge == null) return;
    
    final mySteps = widget.healthSyncController!.todaySteps;
    final result = await _challengeService.updateChallengeSteps(
      widget.challengeId,
      mySteps,
    );
    
    if (mounted) {
      if (result['success'] == true) {
        _loadChallenge();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _challenge == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Challenge Details'),
          backgroundColor: Colors.indigo.shade600,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_challenge == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Challenge Details'),
          backgroundColor: Colors.indigo.shade600,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Challenge not found')),
      );
    }

    final participants = List<Map<String, dynamic>>.from(_challenge!['participants'] ?? []);
    final mySteps = _challenge!['mySteps'] ?? 0;
    final targetSteps = _challenge!['targetSteps'] ?? 10000;
    final progress = (mySteps / targetSteps).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(_challenge!['title'] ?? 'Challenge'),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _updateMySteps();
              _loadChallenge();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _updateMySteps();
          await _loadChallenge();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Challenge Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _challenge!['title'] ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_challenge!['description'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _challenge!['description'],
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Progress
                    if (_challenge!['isParticipant'] == true) ...[
                      Text(
                        'Your Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$mySteps / $targetSteps steps'),
                          Text(
                            '${(progress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Icon(Icons.directions_walk, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Target: $targetSteps steps',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${participants.length} participants',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Leaderboard
            const Text(
              'Leaderboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...participants.map((participant) {
              final rank = participant['rank'] ?? 0;
              final pSteps = participant['steps'] ?? 0;
              final pProgress = (pSteps / targetSteps).clamp(0.0, 1.0);
              final isMe = _userId != null && participant['userId']?.toString() == _userId;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isMe ? Colors.indigo.shade50 : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: rank == 1
                        ? Colors.amber
                        : rank == 2
                            ? Colors.grey.shade400
                            : rank == 3
                                ? Colors.brown.shade300
                                : Colors.grey.shade300,
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: rank <= 3 ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  title: Text(
                    participant['userName'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$pSteps steps'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: pProgress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          rank == 1 ? Colors.amber : Colors.indigo,
                        ),
                        minHeight: 4,
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${(pProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

