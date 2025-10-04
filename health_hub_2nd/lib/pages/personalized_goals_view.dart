// personalized_goals_view.dart

import 'package:flutter/material.dart';

// Reuse constants (or redefine them if this file must be fully independent)
const Color kPrimaryColor = Color(0xFF4C5BF1);
const Color kBackgroundColor = Color(0xFFF7F8FC);
const Color kAccentColor = Color(
  0xFFFFA500,
); // Orange for Goals (from FeaturesView)

// Simulated list of activity categories for a fitness tracker
const List<String> _activityCategories = [
  'Steps',
  'Water Intake',
  'Cardio Minutes',
  'Calorie Burn',
  'Weight Loss',
];

class PersonalizedGoalsView extends StatefulWidget {
  const PersonalizedGoalsView({super.key});

  @override
  State<PersonalizedGoalsView> createState() => _PersonalizedGoalsViewState();
}

class _PersonalizedGoalsViewState extends State<PersonalizedGoalsView> {
  // State variables for the goal inputs
  String? _selectedActivity = _activityCategories.first;
  TextEditingController _targetValueController = TextEditingController(
    text: '10000',
  );
  TextEditingController _goalNameController = TextEditingController(
    text: 'Daily Step Goal',
  );

  DateTime _selectedDate = DateTime.now().add(
    const Duration(days: 1),
  ); // Default to tomorrow
  TimeOfDay _selectedTime = const TimeOfDay(
    hour: 20,
    minute: 0,
  ); // Default to 8:00 PM

  // Final DateTime for the deadline
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

  // Combines date and time into a single DateTime object
  void _updateDeadline() {
    _goalDeadline = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  // --- Date Picker Function ---
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

  // --- Time Picker Function ---
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

  // --- Goal Setting Logic ---
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

    _updateDeadline(); // Final check

    // Calculate the notification time (1 hour before deadline)
    final DateTime notificationTime = _goalDeadline.subtract(
      const Duration(hours: 1),
    );

    String formattedDeadline =
        '${_selectedDate.month}/${_selectedDate.day} at ${_selectedTime.format(context)}';
    String formattedNotification =
        '${notificationTime.month}/${notificationTime.day} at ${TimeOfDay.fromDateTime(notificationTime).format(context)}';

    // Show confirmation dialog (simulating goal and notification setup)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Goal Set Successfully!'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Goal: ${_goalNameController.text}'),
              Text(
                'Target: ${_targetValueController.text} ${_getUnit(_selectedActivity)}',
              ),
              const Divider(),
              Text('Deadline: $formattedDeadline'),
              Text(
                'Reminder set for: $formattedNotification (1 hour before deadline)',
              ),
              const Text(
                '\n(In a real app, this would schedule a local notification.)',
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK', style: TextStyle(color: kPrimaryColor)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // Helper to get unit based on activity
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
            // --- 1. Goal Name Input ---
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

            // --- 2. Activity Category Dropdown ---
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
                      // Update hint text when activity changes
                      if (newValue == 'Steps')
                        _targetValueController.text = '10000';
                      if (newValue == 'Water Intake')
                        _targetValueController.text = '3000';
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- 3. Target Value Input ---
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

            // --- 4. Deadline Selector (Date & Time) ---
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
            const SizedBox(height: 40),

            // --- 5. Set Goal Button ---
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
