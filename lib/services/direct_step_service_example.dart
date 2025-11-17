// Example usage of DirectStepService
// This file demonstrates how to use the direct step sensor service
// without requiring Health Connect or Samsung Health.

import 'package:flutter/material.dart';
import 'direct_step_service.dart';

class DirectStepExample extends StatefulWidget {
  const DirectStepExample({super.key});

  @override
  State<DirectStepExample> createState() => _DirectStepExampleState();
}

class _DirectStepExampleState extends State<DirectStepExample> {
  final DirectStepService _stepService = DirectStepService();
  int _todaySteps = 0;
  int? _cumulativeSteps;
  bool _isAvailable = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      final available = await _stepService.isStepCounterAvailable();
      setState(() {
        _isAvailable = available;
        _isLoading = false;
      });

      if (available) {
        await _refreshSteps();
        // Optionally start listening for real-time updates
        _stepService.startListening().listen((cumulativeSteps) {
          setState(() {
            _cumulativeSteps = cumulativeSteps;
            // Recalculate today's steps if baseline is set
            if (_stepService.baselineStepCount != null) {
              _todaySteps = cumulativeSteps - _stepService.baselineStepCount!;
            }
          });
        });
      } else {
        setState(() {
          _errorMessage = 'Step counter sensor is not available on this device.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error initializing step service: $e';
      });
    }
  }

  Future<void> _refreshSteps() async {
    try {
      final steps = await _stepService.getTodaySteps();
      final cumulative = await _stepService.getCurrentStepCount();
      setState(() {
        _todaySteps = steps;
        _cumulativeSteps = cumulative;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting steps: $e';
      });
    }
  }

  @override
  void dispose() {
    _stepService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct Step Counter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSteps,
            tooltip: 'Refresh steps',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isAvailable
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Text(
                                'Today\'s Steps',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_todaySteps',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_cumulativeSteps != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cumulative Steps (since boot)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_cumulativeSteps',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_stepService.baselineStepCount != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Baseline Info',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Baseline: ${_stepService.baselineStepCount}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                if (_stepService.baselineDate != null)
                                  Text(
                                    'Date: ${_stepService.baselineDate}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (_errorMessage != null)
                        Card(
                          color: Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How it works:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '• Uses Android\'s hardware Step Counter sensor\n'
                                '• No Health Connect or Samsung Health required\n'
                                '• Provides cumulative steps since device boot\n'
                                '• Calculates daily steps using a baseline\n'
                                '• Automatically resets baseline at start of each day',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ??
                              'Step counter sensor is not available on this device.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

