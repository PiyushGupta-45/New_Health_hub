import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/auth_controller.dart';
import '../services/steps_sync_service.dart';

class StepsHistoryView extends StatefulWidget {
  const StepsHistoryView({super.key, required this.authController});

  final AuthController authController;

  @override
  State<StepsHistoryView> createState() => _StepsHistoryViewState();
}

class _StepsHistoryViewState extends State<StepsHistoryView> {
  final StepsSyncService _stepsSyncService = StepsSyncService();

  List<Map<String, dynamic>> _stepsHistory = const [];
  bool _isLoading = true;
  String? _errorMessage;
  int _totalSteps = 0;
  int _averageSteps = 0;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChanged);
    _checkAuthAndLoad();
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (widget.authController.isAuthenticated) {
      _checkAuthAndLoad();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please sign in to view your daily step log.';
        _stepsHistory = const [];
      });
    }
  }

  void _checkAuthAndLoad() {
    if (widget.authController.isAuthenticated) {
      _loadStepsHistory();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please sign in to view your daily step log.';
      });
    }
  }

  Future<void> _loadStepsHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _stepsSyncService.getStepsHistory(limit: 30);

      if (result['success'] == true) {
        final history = (result['data'] as List)
            .map((item) => item as Map<String, dynamic>)
            .toList();

        var total = 0;
        for (final entry in history) {
          total += (entry['steps'] as int? ?? 0);
        }

        setState(() {
          _stepsHistory = history;
          _totalSteps = total;
          _averageSteps = history.isNotEmpty
              ? (total / history.length).round()
              : 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to load daily step log.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading daily step log: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == yesterday) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatDayOfWeek(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020617)
          : const Color(0xFFF1F5FF),
      appBar: AppBar(
        title: const Text('Daily Step Log'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, isDark),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    final isAuthError =
        (_errorMessage ?? '').toLowerCase().contains('sign in') ||
        (_errorMessage ?? '').toLowerCase().contains('authenticated') ||
        (_errorMessage ?? '').toLowerCase().contains('auth');

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAuthError
                    ? Icons.lock_outline_rounded
                    : Icons.error_outline_rounded,
                size: 62,
                color: isAuthError
                    ? Colors.blueGrey.shade300
                    : Colors.red.shade300,
              ),
              const SizedBox(height: 14),
              Text(
                isAuthError ? 'Sign In Required' : 'Unable to load log',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFF8FAFC)
                      : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: isAuthError
                    ? () => Navigator.of(context).pop()
                    : _loadStepsHistory,
                icon: Icon(
                  isAuthError
                      ? Icons.arrow_back_rounded
                      : Icons.refresh_rounded,
                ),
                label: Text(isAuthError ? 'Go Back' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_stepsHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_walk_rounded,
                size: 76,
                color: Colors.blueGrey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'No step entries yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFF8FAFC)
                      : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Walk a little and sync once. Your daily logs will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStepsHistory,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildHeroCard(isDark),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'Recent Days',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? const Color(0xFFF8FAFC)
                      : const Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.builder(
              itemCount: _stepsHistory.length,
              itemBuilder: (context, index) =>
                  _buildHistoryCard(_stepsHistory[index], isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '30-Day Snapshot',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${NumberFormat.compact().format(_totalSteps)} steps',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                '${NumberFormat.decimalPattern().format(_averageSteps)} avg/day',
              ),
              _summaryChip('${_stepsHistory.length} logged days'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry, bool isDark) {
    DateTime date;
    if (entry['date'] is String) {
      date = DateTime.parse(entry['date']).toLocal();
    } else if (entry['date'] is Map) {
      final dateMap = entry['date'] as Map;
      date = DateTime.parse(dateMap['\$date'] as String).toLocal();
    } else {
      date = DateTime.now();
    }

    final steps = entry['steps'] as int? ?? 0;
    final source = (entry['source'] as String? ?? 'Phone Sensor').trim();
    const goal = 10000;
    final progress = (steps / goal).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF263047) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.18)
                : const Color(0xFF334155).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFF8FAFC)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDayOfWeek(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      (progress >= 1.0 ? Colors.green : const Color(0xFF2563EB))
                          .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: progress >= 1.0
                        ? Colors.green.shade700
                        : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: NumberFormat.decimalPattern().format(steps),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: isDark
                        ? const Color(0xFFF8FAFC)
                        : const Color(0xFF0F172A),
                  ),
                ),
                TextSpan(
                  text: '  steps',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.green : const Color(0xFF2563EB),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.sensors_rounded,
                size: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
