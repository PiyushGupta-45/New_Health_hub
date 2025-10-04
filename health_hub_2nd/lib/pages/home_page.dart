// This file contains the main home page widget, including the UI for
// the progress card and quick actions.

import 'package:flutter/material.dart';
import 'package:health/health.dart'; // Using the correct 'health' package
import 'package:intl/intl.dart';    // For formatting the number with a comma

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // State variables to hold our data and loading status
  int? _totalSteps;
  bool _isLoading = true;
  String _errorMessage = '';
  final int _stepGoal = 8000; // Example step goal

  // CORRECTED: Use Health() instead of the old HealthFactory()
  Health health = Health();

  @override
  void initState() {
    super.initState();
    _fetchHealthData();
  }
  
  Future<void> _fetchHealthData() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    // Define the data types we want to read
    final types = [HealthDataType.STEPS];
    
    // On Android, we need to request permissions for Health Connect
    final permissions = [HealthDataAccess.READ];

    try {
      // Request authorization. For Android, this will prompt to install Health Connect if not installed.
      bool requested = await health.requestAuthorization(types, permissions: permissions);
      if (!requested) {
        throw Exception('Permissions not granted.');
      }

      // Fetch today's step data
      final now = DateTime.now();
      final startTime = DateTime(now.year, now.month, now.day);
      
      // The health package returns steps as an int, or null if no data
      int? steps = await health.getTotalStepsInInterval(startTime, now);

      setState(() {
        _totalSteps = steps;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper widget to display the step count or loading/error states
  Widget _buildStepCountDisplay() {
    if (_isLoading) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
      );
    }

    if (_errorMessage.isNotEmpty) {
      // You could show the full error for debugging, or a user-friendly message
      return Tooltip(
        message: _errorMessage,
        child: const Icon(Icons.error_outline, color: Colors.white70, size: 36),
      );
    }

    if (_totalSteps == null) {
      return const Text(
        '--',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

    // Format the number with commas (e.g., 1,500)
    final formattedSteps = NumberFormat.decimalPattern().format(_totalSteps);
    return Text(
      formattedSteps,
      style: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress percentage safely
    double progress = 0.0;
    if (_totalSteps != null && _totalSteps! > 0) {
      progress = (_totalSteps! / _stepGoal).clamp(0.0, 1.0);
    }
    String progressPercentage = '${(progress * 100).toStringAsFixed(0)}% of goal';

    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Section: Welcome and Profile
              Padding(
                padding: const EdgeInsets.only(top: 48.0, bottom: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Welcome back!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Ready for a new workout?',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24.0),
                        color: const Color(0xFFD1D5DB),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'P',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Daily Progress Card - DYNAMIC
              Container(
                padding: const EdgeInsets.all(24.0),
                margin: const EdgeInsets.only(bottom: 24.0),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade600,
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.shade600.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Progress",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _isLoading ? 'Loading...' : progressPercentage,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _isLoading ? null : progress,
                        backgroundColor: Colors.indigo.shade500,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStepCountDisplay(),
                            const SizedBox(height: 4),
                            const Text(
                              'Steps Today',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.indigo.shade600,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'View Details',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quick Actions Section
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      print('Personalized Goals Card Tapped!');
                    },
                    child: buildActionCard(
                      icon: Icons.flag_outlined,
                      iconColor: Colors.blue.shade600,
                      iconBgColor: Colors.blue.shade100,
                      title: 'Personalized Goals',
                      subtitle: 'Set and manage your health goals.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      print('Posture Analysis Card Tapped!');
                    },
                    child: buildActionCard(
                      icon: Icons.sports_gymnastics,
                      iconColor: Colors.green.shade600,
                      iconBgColor: Colors.green.shade100,
                      title: 'Posture Analysis',
                      subtitle: 'AI-powered posture correction.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      print('Track Workout Card Tapped!');
                    },
                    child: buildActionCard(
                      icon: Icons.track_changes,
                      iconColor: Colors.orange.shade600,
                      iconBgColor: Colors.orange.shade100,
                      title: 'Track Workout',
                      subtitle: 'Log and analyze your workouts.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  static Widget buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 24),
        ],
      ),
    );
  }
}