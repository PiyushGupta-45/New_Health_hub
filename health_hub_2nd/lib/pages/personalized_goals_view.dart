// personalized_goals_view.dart

import 'package:flutter/material.dart';
// Note: Assuming main.dart has the notification setup if you want it to truly work

// Reuse constants (or redefine them if this file must be fully independent)
const Color kPrimaryColor = Color(0xFF4C5BF1);
const Color kBackgroundColor = Color(0xFFF7F8FC);
const Color kAccentColor = Color(
  0xFFFFA500,
); // Orange for Goals (from FeaturesView)

// --- GLOBAL Goal Model and Storage ---
class Goal {
  final String name;
  final String target;
  final String unit;
  final DateTime deadline;
  final DateTime reminderTime;
  final bool connectToTracker; // NEW: Flag to link to Workout Logs

  Goal({
    required this.name,
    required this.target,
    required this.unit,
    required this.deadline,
    required this.reminderTime,
    required this.connectToTracker,
  });
}

// Global storage list (simulating a database)
List<Goal> activeGoals = [];
// --- END GLOBAL ---

// Simulated list of activity categories for a fitness tracker
const List<String> _activityCategories = [
  'Steps',
  'Water Intake',
  'Cardio Minutes',
  'Calorie Burn',
  'Weight Loss',
  'Distance (km)', // Added a dedicated distance option for clarity
];

class PersonalizedGoalsView extends StatefulWidget {
  const PersonalizedGoalsView({super.key});

  @override
  State<PersonalizedGoalsView> createState() => _PersonalizedGoalsViewState();
}

class _PersonalizedGoalsViewState extends State<PersonalizedGoalsView> {
  String? _selectedActivity = _activityCategories.last; // Default to Distance
  TextEditingController _targetValueController = TextEditingController(
    text: '10',
  );
  TextEditingController _goalNameController = TextEditingController(
    text: 'Daily Run Goal',
  );

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0);

  bool _connectToTracker = true; // NEW: State for the connection toggle

  late DateTime _goalDeadline;

  @override
  void initState() {
    super.initState();
    _updateDeadline();
  }

  @override
  void dispose() {
    _targetValueController.dispose();
    _goalNameController.dispose();
    super.dispose();
  }

  void _updateDeadline() {
    _goalDeadline = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  // ... (Removed _selectDate and _selectTime methods for brevity, they remain unchanged)

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(DateTime.now())
          ? DateTime.now().add(const Duration(days: 1))
          : _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: kPrimaryColor),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _updateDeadline();
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: kPrimaryColor),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _updateDeadline();
      });
    }
  }

  void _setGoal() {
    if (_goalNameController.text.isEmpty ||
        _targetValueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in the Goal Name and Target Value.'),
        ),
      );
      return;
    }

    _updateDeadline();
    final DateTime notificationTime = _goalDeadline.subtract(
      const Duration(hours: 1),
    );

    // 1. Create the Goal object with the new connection flag
    final newGoal = Goal(
      name: _goalNameController.text,
      target: _targetValueController.text,
      unit: _getUnit(_selectedActivity),
      deadline: _goalDeadline,
      reminderTime: notificationTime,
      connectToTracker: _connectToTracker, // Store the connection status
    );

    // 2. Save the goal to the global list (simulating persistence)
    activeGoals.add(newGoal);

    // 3. Schedule Notification (omitted logic, just simulated confirmation)

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Goal Set Successfully!'),
        content: Text(
          'Goal: ${newGoal.name}\nTarget: ${newGoal.target} ${newGoal.unit}\n\n'
          'Status: ${_connectToTracker ? "Connected to Workout Tracker." : "Not connected."}',
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK', style: TextStyle(color: kPrimaryColor)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  String _getUnit(String? activity) {
    switch (activity) {
      case 'Steps':
        return 'steps';
      case 'Water Intake':
        return 'ml';
      case 'Cardio Minutes':
        return 'minutes';
      case 'Calorie Burn':
        return 'calories';
      case 'Weight Loss':
        return 'kg/lbs';
      case 'Distance (km)':
        return 'km'; // New unit handler
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Set New Goal',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ... (Goal Name, Activity Type, Target Value inputs remain the same)
            _buildGoalInputCard(
              title: 'Goal Name',
              child: TextField(
                controller: _goalNameController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Daily Step Goal, Morning Run',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            _buildGoalInputCard(
              title: 'Activity Type',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedActivity,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: kPrimaryColor),
                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                  items: _activityCategories.map<DropdownMenuItem<String>>((
                    String value,
                  ) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedActivity = newValue;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildGoalInputCard(
              title: 'Target Value (${_getUnit(_selectedActivity)})',
              child: TextField(
                controller: _targetValueController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter target value',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  suffixText: _getUnit(_selectedActivity),
                  suffixStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 18,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- Deadline Selector (Date & Time) ---
            const Text(
              'Goal Deadline & Reminder',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildDateSelector(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  value:
                      '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(width: 15),
                _buildDateSelector(
                  icon: Icons.access_time,
                  label: 'Time',
                  value: _selectedTime.format(context),
                  onTap: () => _selectTime(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildReminderInfo(),
            const SizedBox(height: 30),

            // --- NEW: Connect to Tracker Option ---
            _buildConnectTrackerOption(),
            const SizedBox(height: 40),

            // --- Set Goal Button ---
            ElevatedButton.icon(
              onPressed: _setGoal,
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text(
                'SET GOAL & NOTIFICATION',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectTrackerOption() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _connectToTracker ? kAccentColor : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SwitchListTile(
        title: const Text(
          'Connect to Workout Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'Display this goal directly in your workout tracking screen.',
        ),
        value: _connectToTracker,
        activeColor: kAccentColor,
        onChanged: (bool value) {
          setState(() {
            _connectToTracker = value;
          });
        },
      ),
    );
  }

  // ... (Helper widgets _buildGoalInputCard, _buildDateSelector, _buildReminderInfo remain the same)
  // Helper Widget for structured input cards
  Widget _buildGoalInputCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }

  // Helper Widget for date/time selector buttons
  Widget _buildDateSelector({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, color: kPrimaryColor),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget for the reminder info text
  Widget _buildReminderInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: kAccentColor, size: 20),
          const SizedBox(width: 8),
          Text(
            'You will be notified 1 hour before the deadline.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
