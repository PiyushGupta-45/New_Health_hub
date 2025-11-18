// health_metrics_view.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const Color
kPrimaryAccent = Color(
  0xFF3B6CF0,
);
const Color
kBackgroundColor = Color(
  0xFFF2F4F7,
);
const Color
kCardColor = Color(
  0xFFF7F9FB,
);
const double
_cardRadius = 18.0;

// Workout intensity types
enum WorkoutIntensity {
  low,
  medium,
  high,
}

class HealthMetricsView
    extends
        StatefulWidget {
  const HealthMetricsView({
    super.key,
  });

  @override
  State<
    HealthMetricsView
  >
  createState() => _HealthMetricsViewState();
}

class _HealthMetricsViewState
    extends
        State<
          HealthMetricsView
        >
    with
        SingleTickerProviderStateMixin {
  double _weight = 70.0;
  int _height = 175;
  int _age = 25;
  String _gender = 'Male';
  int _workoutDuration = 30;
  WorkoutIntensity _workoutIntensity = WorkoutIntensity.medium;

  double _bmiResult = 0.0;
  String _bmiStatus = '';
  double _bmrResult = 0.0;
  double _caloriesBurned = 0.0;
  double _metValue = 6.0;

  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 250,
      ),
    );
    _recalculateAll();
  }

  void _recalculateAll() {
    _calculateBMI();
    _calculateBMR();
    _updateMET();
    _calculateCalories();
    setState(
      () {},
    );
  }

  void _calculateBMI() {
    double h =
        _height /
        100.0;
    _bmiResult =
        _weight /
        (h *
            h);

    if (_bmiResult <
        18.5) {
      _bmiStatus = 'Underweight';
    } else if (_bmiResult <
        25.0) {
      _bmiStatus = 'Healthy';
    } else if (_bmiResult <
        30.0) {
      _bmiStatus = 'Overweight';
    } else {
      _bmiStatus = 'Obese';
    }
  }

  void _calculateBMR() {
    if (_gender ==
        "Male") {
      _bmrResult =
          10 *
              _weight +
          6.25 *
              _height -
          5 *
              _age +
          5;
    } else {
      _bmrResult =
          10 *
              _weight +
          6.25 *
              _height -
          5 *
              _age -
          161;
    }
  }

  void _updateMET() {
    switch (_workoutIntensity) {
      case WorkoutIntensity.low:
        _metValue = 3.0;
        break;
      case WorkoutIntensity.medium:
        _metValue = 6.0;
        break;
      case WorkoutIntensity.high:
        _metValue = 9.0;
        break;
    }
  }

  void _calculateCalories() {
    _caloriesBurned =
        _metValue *
        _weight *
        (_workoutDuration /
            60.0);
  }

  BoxDecoration _neumorphic() {
    return BoxDecoration(
      color: kCardColor,
      borderRadius: BorderRadius.circular(
        _cardRadius,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withOpacity(
            0.85,
          ),
          offset: const Offset(
            -6,
            -6,
          ),
          blurRadius: 14,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(
            0.08,
          ),
          offset: const Offset(
            6,
            6,
          ),
          blurRadius: 14,
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        title: const Text(
          "Health Metrics",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(
            18,
          ),
          child: Column(
            children: [
              _genderCard(),
              const SizedBox(
                height: 18,
              ),

              /// FULL WIDTH INPUT CARDS
              _buildHeightCard(),
              const SizedBox(
                height: 18,
              ),

              _buildWeightCard(),
              const SizedBox(
                height: 18,
              ),

              _buildAgeCard(),
              const SizedBox(
                height: 18,
              ),

              _buildWorkoutCard(),
              const SizedBox(
                height: 20,
              ),

              _buildResultsCard(),
              const SizedBox(
                height: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- GENDER CARD ----------------
  Widget _genderCard() {
    return Container(
      padding: const EdgeInsets.all(
        16,
      ),
      decoration: _neumorphic(),
      child: Row(
        children: [
          Expanded(
            child: _buildGenderSegment(),
          ),
          const SizedBox(
            width: 12,
          ),
          _resetButton(),
        ],
      ),
    );
  }

  Widget _resetButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(
        12,
      ),
      onTap: () {
        setState(
          () {
            _weight = 70;
            _height = 175;
            _age = 25;
            _workoutDuration = 30;
            _workoutIntensity = WorkoutIntensity.medium;
            _recalculateAll();
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(
          12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            12,
          ),
        ),
        child: Icon(
          Icons.refresh_rounded,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildGenderSegment() {
    return Container(
      padding: const EdgeInsets.all(
        6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          14,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.05,
            ),
            blurRadius: 6,
            offset: const Offset(
              2,
              3,
            ),
          ),
        ],
      ),
      child:
          CupertinoSegmentedControl<
            String
          >(
            borderColor: kPrimaryAccent,
            selectedColor: kPrimaryAccent,
            unselectedColor: Colors.white,
            pressedColor: kPrimaryAccent.withOpacity(
              0.15,
            ),

            groupValue: _gender,

            children: {
              "Male": Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.male,
                      size: 28,
                      color:
                          _gender ==
                              "Male"
                          ? Colors.white
                          : Colors.black87,
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      "Male",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            _gender ==
                                "Male"
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color:
                            _gender ==
                                "Male"
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              "Female": Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.female,
                      size: 28,
                      color:
                          _gender ==
                              "Female"
                          ? Colors.white
                          : Colors.black87,
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      "Female",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            _gender ==
                                "Female"
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color:
                            _gender ==
                                "Female"
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            },

            onValueChanged:
                (
                  value,
                ) {
                  setState(
                    () {
                      _gender = value;
                      _recalculateAll();
                    },
                  );
                },
          ),
    );
  }

  // ---------------- FULL WIDTH INPUT CARDS ----------------

  Widget _buildHeightCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      decoration: _neumorphic(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            "HEIGHT",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(
            height: 4,
          ),

          // Value + Unit
          Row(
            children: [
              Text(
                "$_height",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                width: 6,
              ),
              Text(
                "cm",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          // -  slider  +
          Row(
            children: [
              // MINUS BUTTON
              _circleBtn(
                Icons.remove,
                () {
                  setState(
                    () {
                      if (_height >
                          100)
                        _height -= 5;
                      _recalculateAll();
                    },
                  );
                },
              ),

              const SizedBox(
                width: 10,
              ),

              // SMOOTH SLIDER (NO FIXED DIVISIONS)
              Expanded(
                child: SliderTheme(
                  data:
                      SliderTheme.of(
                        context,
                      ).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                      ),
                  child: Slider(
                    min: 100,
                    max: 220,
                    value: _height.toDouble(),
                    activeColor: kPrimaryAccent,
                    inactiveColor: Colors.grey.shade300,
                    onChanged:
                        (
                          v,
                        ) {
                          setState(
                            () {
                              _height = v.round(); // smooth height change
                              _recalculateAll();
                            },
                          );
                        },
                  ),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              // PLUS BUTTON
              _circleBtn(
                Icons.add,
                () {
                  setState(
                    () {
                      if (_height <
                          220)
                        _height += 5;
                      _recalculateAll();
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      decoration: _neumorphic(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "WEIGHT",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(
            height: 4,
          ),

          Row(
            children: [
              Text(
                _weight.toStringAsFixed(
                  1,
                ),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                width: 6,
              ),
              Text(
                "kg",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),

          Row(
            children: [
              _circleBtn(
                Icons.remove,
                () {
                  if (_weight >
                      20) {
                    _weight -= 0.5;
                    _recalculateAll();
                  }
                },
              ),

              Expanded(
                child: SliderTheme(
                  data:
                      SliderTheme.of(
                        context,
                      ).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                      ),
                  child: Slider(
                    min: 30,
                    max: 180,
                    value: _weight,
                    activeColor: kPrimaryAccent,
                    onChanged:
                        (
                          v,
                        ) {
                          setState(
                            () {
                              _weight = double.parse(
                                v.toStringAsFixed(
                                  1,
                                ),
                              );
                              _recalculateAll();
                            },
                          );
                        },
                  ),
                ),
              ),

              _circleBtn(
                Icons.add,
                () {
                  _weight += 0.5;
                  _recalculateAll();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      decoration: _neumorphic(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "AGE",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(
            height: 4,
          ),

          Row(
            children: [
              Text(
                "$_age",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                width: 6,
              ),
              Text(
                "yrs",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleBtn(
                Icons.remove,
                () {
                  if (_age >
                      1) {
                    _age--;
                    _recalculateAll();
                  }
                },
              ),
              _circleBtn(
                Icons.add,
                () {
                  _age++;
                  _recalculateAll();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- REUSABLE TEXT + SLIDER ----------
  Widget _label(
    String text,
  ) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _valueRow(
    String value,
    String unit,
  ) {
    return Row(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(
          width: 6,
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _bigSlider({
    required double value,
    required double min,
    required double max,
    required Function(
      double,
    )
    onChanged,
  }) {
    return SliderTheme(
      data:
          SliderTheme.of(
            context,
          ).copyWith(
            trackHeight: 6,
            activeTrackColor: kPrimaryAccent,
            inactiveTrackColor: Colors.grey.shade300,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 14,
            ),
          ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    );
  }

  Widget _circleBtn(
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(
        30,
      ),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(
          14,
        ),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Icon(
          icon,
          size: 22,
          color: Colors.black87,
        ),
      ),
    );
  }

  // ---------------- WORKOUT CARD ----------------
  Widget _buildWorkoutCard() {
    return Container(
      padding: const EdgeInsets.all(
        20,
      ),
      decoration: _neumorphic(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(
            "WORKOUT INTENSITY",
          ),
          const SizedBox(
            height: 12,
          ),
          _buildIntensitySegment(),
          const SizedBox(
            height: 20,
          ),

          _label(
            "DURATION",
          ),
          const SizedBox(
            height: 10,
          ),

          Row(
            children: [
              _circleBtn(
                Icons.remove,
                () {
                  if (_workoutDuration >
                      5) {
                    _workoutDuration -= 5;
                  }
                  _recalculateAll();
                },
              ),

              const SizedBox(
                width: 12,
              ),

              Text(
                "$_workoutDuration min",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              _circleBtn(
                Icons.add,
                () {
                  _workoutDuration += 5;
                  _recalculateAll();
                },
              ),
            ],
          ),

          _bigSlider(
            value: _workoutDuration.toDouble(),
            min: 5,
            max: 180,
            onChanged:
                (
                  v,
                ) {
                  _workoutDuration = v.round();
                  _recalculateAll();
                },
          ),
        ],
      ),
    );
  }

  // ---------------- WORKOUT INTENSITY SEGMENT ----------------
  Widget _buildIntensitySegment() {
    return Row(
      children: WorkoutIntensity.values.map(
        (
          e,
        ) {
          bool selected =
              _workoutIntensity ==
              e;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(
                  () {
                    _workoutIntensity = e;
                    _recalculateAll();
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                ),
                margin: const EdgeInsets.symmetric(
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white
                      : kCardColor,
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                  border: Border.all(
                    color: selected
                        ? kPrimaryAccent.withOpacity(
                            .3,
                          )
                        : Colors.transparent,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              0.06,
                            ),
                            blurRadius: 8,
                            offset: const Offset(
                              3,
                              4,
                            ),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    _intensityText(
                      e,
                    ),
                    style: TextStyle(
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  String _intensityText(
    WorkoutIntensity e,
  ) {
    switch (e) {
      case WorkoutIntensity.low:
        return "Low";
      case WorkoutIntensity.medium:
        return "Medium";
      case WorkoutIntensity.high:
        return "High";
    }
  }

  // ---------------- RESULTS CARD ----------------
  Widget _buildResultsCard() {
    return Container(
      padding: const EdgeInsets.all(
        20,
      ),
      decoration: _neumorphic(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "RESULTS",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            "Auto-calculated based on your inputs",
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          Row(
            children: [
              // BMI
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(
                    18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _bmiResult.toStringAsFixed(
                          1,
                        ),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      _bmiChip(
                        _bmiStatus,
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      Text(
                        "BMI",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(
                width: 14,
              ),

              // Calories
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(
                    18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _caloriesBurned.toStringAsFixed(
                          0,
                        ),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      Text(
                        "cal burned",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      _chip(
                        _intensityText(
                          _workoutIntensity,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          Text(
            "BMR: ${_bmrResult.toStringAsFixed(0)} cal/day",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bmiChip(
    String status,
  ) {
    Color bg = Colors.grey.shade300;
    Color txt = Colors.black87;

    if (status ==
        "Healthy") {
      bg = Colors.green.withOpacity(
        .2,
      );
      txt = Colors.green.shade800;
    } else if (status ==
            "Overweight" ||
        status ==
            "Underweight") {
      bg = Colors.orange.withOpacity(
        .2,
      );
      txt = Colors.orange.shade800;
    } else if (status ==
        "Obese") {
      bg = Colors.red.withOpacity(
        .2,
      );
      txt = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(
          12,
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: txt,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _chip(
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(
          10,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
