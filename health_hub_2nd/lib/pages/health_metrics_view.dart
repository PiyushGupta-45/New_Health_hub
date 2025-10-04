// health_metrics_view.dart

import 'package:flutter/material.dart';

const Color kPrimaryColor = Color(0xFF4C5BF1);
const Color kBackgroundColor = Color(0xFFF7F8FC);

// --- Main Feature Screen Widget ---
class HealthMetricsView extends StatefulWidget {
  const HealthMetricsView({super.key});

  @override
  State<HealthMetricsView> createState() => _HealthMetricsViewState();
}

class _HealthMetricsViewState extends State<HealthMetricsView> {
  // --- State Variables for User Input ---
  double _weight = 70.0; // in kg
  int _height = 175; // in cm
  int _age = 25;
  String _gender = 'Male'; // 'Male' or 'Female'

  // --- State Variables for Results ---
  double _bmiResult = 0.0;
  double _bmrResult = 0.0;
  String _bmiStatus = '';

  @override
  void initState() {
    super.initState();
    _calculateMetrics();
  }

  // --- Calculation Logic ---
  void _calculateMetrics() {
    double heightInMeters = _height / 100.0;
    _bmiResult = _weight / (heightInMeters * heightInMeters);

    // Determine BMI Status
    if (_bmiResult < 18.5) {
      _bmiStatus = 'Underweight';
    } else if (_bmiResult >= 18.5 && _bmiResult < 24.9) {
      _bmiStatus = 'Healthy Weight';
    } else if (_bmiResult >= 25.0 && _bmiResult < 29.9) {
      _bmiStatus = 'Overweight';
    } else {
      _bmiStatus = 'Obese';
    }

    // Calculate BMR (Mifflin-St Jeor Equation)
    if (_gender == 'Male') {
      _bmrResult = (10 * _weight) + (6.25 * _height) - (5 * _age) + 5;
    } else {
      _bmrResult = (10 * _weight) + (6.25 * _height) - (5 * _age) - 161;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Health Metrics Calculator',
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
            _buildGenderSelector(),
            const SizedBox(height: 20),
            _buildHeightSlider(),
            const SizedBox(height: 20),
            _buildAgeInput(),
            const SizedBox(height: 20),
            _buildWeightInput(),
            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _calculateMetrics,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
              ),
              child: const Text(
                'Calculate Health Metrics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 40),

            _buildResultsCard(),
          ],
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildResultsCard() {
    return Container(
      padding: const EdgeInsets.all(25.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Text(
            'Your Results',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          const SizedBox(height: 20),

          // BMI Result
          _buildResultRow(
            label: 'Body Mass Index (BMI)',
            value: _bmiResult.toStringAsFixed(1),
            unit: 'kg/m²',
            status: _bmiStatus,
            statusColor: _getStatusColor(_bmiStatus),
          ),
          const Divider(height: 30),

          // BMR Result
          _buildResultRow(
            label: 'Basal Metabolic Rate (BMR)',
            value: _bmrResult.toStringAsFixed(0),
            unit: 'Calories/day',
            status: 'Resting Energy',
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow({
    required String label,
    required String value,
    required String unit,
    String? status,
    Color? statusColor,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (status != null)
          Text(
            status,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: statusColor ?? Colors.black87,
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Healthy Weight':
        return Colors.green;
      case 'Overweight':
      case 'Underweight':
        return Colors.orange;
      case 'Obese':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildGenderSelector() {
    return Row(
      children: [
        _buildGenderButton('Male', Icons.male),
        const SizedBox(width: 20),
        _buildGenderButton('Female', Icons.female),
      ],
    );
  }

  Widget _buildGenderButton(String gender, IconData icon) {
    bool isSelected = _gender == gender;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _gender = gender;
            _calculateMetrics();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? kPrimaryColor : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? kPrimaryColor : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: kPrimaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 40,
                color: isSelected ? Colors.white : kPrimaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                gender,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required String title,
    required String unit,
    required String value,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildHeightSlider() {
    return _buildInputCard(
      title: 'HEIGHT',
      unit: 'cm',
      value: _height.toString(),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          inactiveTrackColor: Colors.grey.shade300,
          activeTrackColor: kPrimaryColor,
          thumbColor: kPrimaryColor,
          overlayColor: kPrimaryColor.withOpacity(0.2),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0),
        ),
        child: Slider(
          value: _height.toDouble(),
          min: 100,
          max: 220,
          onChanged: (double newValue) {
            setState(() {
              _height = newValue.round();
              _calculateMetrics();
            });
          },
        ),
      ),
    );
  }

  Widget _buildAgeInput() {
    return _buildInputCard(
      title: 'AGE',
      unit: 'yrs',
      value: _age.toString(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRoundButton(Icons.remove, () {
            setState(() {
              if (_age > 1) _age--;
              _calculateMetrics();
            });
          }),
          const SizedBox(width: 20),
          _buildRoundButton(Icons.add, () {
            setState(() {
              _age++;
              _calculateMetrics();
            });
          }),
        ],
      ),
    );
  }

  Widget _buildWeightInput() {
    return _buildInputCard(
      title: 'WEIGHT',
      unit: 'kg',
      value: _weight.toStringAsFixed(1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRoundButton(Icons.remove, () {
            setState(() {
              if (_weight > 1.0) _weight -= 0.5;
              _calculateMetrics();
            });
          }),
          const SizedBox(width: 20),
          _buildRoundButton(Icons.add, () {
            setState(() {
              _weight += 0.5;
              _calculateMetrics();
            });
          }),
        ],
      ),
    );
  }

  Widget _buildRoundButton(IconData icon, VoidCallback onPressed) {
    return FloatingActionButton(
      heroTag: icon.toString(),
      onPressed: onPressed,
      backgroundColor: Colors.grey.shade200,
      foregroundColor: kPrimaryColor,
      mini: true,
      elevation: 0,
      child: Icon(icon),
    );
  }
}
