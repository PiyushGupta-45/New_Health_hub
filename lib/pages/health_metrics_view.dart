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
_cardRadius = 16.0;

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

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
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
    _updateMetValue();
    _calculateCaloriesBurned();
    setState(
      () {},
    );
  }

  void _calculateBMI() {
    final h =
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
        'Male') {
      _bmrResult =
          (10 *
              _weight) +
          (6.25 *
              _height) -
          (5 *
              _age) +
          5;
    } else {
      _bmrResult =
          (10 *
              _weight) +
          (6.25 *
              _height) -
          (5 *
              _age) -
          161;
    }
  }

  void _updateMetValue() {
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

  void _calculateCaloriesBurned() {
    final hours =
        _workoutDuration /
        60.0;
    _caloriesBurned =
        (_metValue *
        _weight *
        hours);
  }

  BoxDecoration _neumorphicDecoration({
    double radius = _cardRadius,
  }) {
    return BoxDecoration(
      color: kCardColor,
      borderRadius: BorderRadius.circular(
        radius,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withOpacity(
            0.85,
          ),
          offset: const Offset(
            -8,
            -8,
          ),
          blurRadius: 18,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(
            0.06,
          ),
          offset: const Offset(
            8,
            8,
          ),
          blurRadius: 18,
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
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
        title: const Text(
          'Health Metrics',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 20,
          ),
          child: Column(
            children: [
              /// ================= GENDER CARD =================
              AnimatedContainer(
                duration: const Duration(
                  milliseconds: 250,
                ),
                padding: const EdgeInsets.all(
                  12,
                ),
                decoration: _neumorphicDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildGenderSegment(),
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    _buildResetButton(),
                  ],
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              /// ================= HEIGHT / WEIGHT / AGE CARDS =================
              Row(
                children: [
                  Flexible(
                    child: _buildHeightCard(),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Flexible(
                    child: _buildWeightCard(),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Flexible(
                    child: _buildAgeCard(),
                  ),
                ],
              ),

              const SizedBox(
                height: 18,
              ),

              /// ================= WORKOUT CARD =================
              _buildWorkoutCard(),

              const SizedBox(
                height: 18,
              ),

              /// ================= RESULTS CARD =================
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

  // ------------------------------- HEIGHT CARD -------------------------------
  Widget _buildHeightCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
      decoration: _neumorphicDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Height',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$_height cm',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 6,
          ),

          SliderTheme(
            data:
                SliderTheme.of(
                  context,
                ).copyWith(
                  activeTrackColor: kPrimaryAccent,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
            child: Slider(
              min: 100,
              max: 220,
              value: _height.toDouble(),
              onChanged:
                  (
                    v,
                  ) {
                    setState(
                      () {
                        _height = v.round();
                        _recalculateAll();
                      },
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------- WEIGHT CARD -------------------------------
  Widget _buildWeightCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
      decoration: _neumorphicDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Weight',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${_weight.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 6,
          ),

          Row(
            children: [
              _roundBtn(
                Icons.remove,
                () {
                  setState(
                    () {
                      _weight -= 0.5;
                      _recalculateAll();
                    },
                  );
                },
              ),
              Expanded(
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
              _roundBtn(
                Icons.add,
                () {
                  setState(
                    () {
                      _weight += 0.5;
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

  // ------------------------------- AGE CARD -------------------------------
  Widget _buildAgeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
      decoration: _neumorphicDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Age',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$_age yrs',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 6,
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _roundBtn(
                Icons.remove,
                () {
                  setState(
                    () {
                      if (_age >
                          1)
                        _age--;
                      _recalculateAll();
                    },
                  );
                },
              ),
              const SizedBox(
                width: 16,
              ),
              _roundBtn(
                Icons.add,
                () {
                  setState(
                    () {
                      _age++;
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

  Widget _roundBtn(
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(
            8,
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  // ------------------------------- WORKOUT CARD -------------------------------
  Widget _buildWorkoutCard() {
    return Container(
      padding: const EdgeInsets.all(
        16,
      ),
      decoration: _neumorphicDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workout',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(
            height: 12,
          ),

          _buildIntensitySegment(),
          const SizedBox(
            height: 14,
          ),

          Row(
            children: [
              const Text(
                'Duration',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),

              _roundBtn(
                Icons.remove,
                () {
                  setState(
                    () {
                      if (_workoutDuration >
                          5)
                        _workoutDuration -= 5;
                      _recalculateAll();
                    },
                  );
                },
              ),

              const SizedBox(
                width: 10,
              ),

              Text(
                '$_workoutDuration min',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              _roundBtn(
                Icons.add,
                () {
                  setState(
                    () {
                      _workoutDuration += 5;
                      _recalculateAll();
                    },
                  );
                },
              ),
            ],
          ),

          Slider(
            min: 5,
            max: 180,
            value: _workoutDuration.toDouble(),
            activeColor: kPrimaryAccent,
            onChanged:
                (
                  v,
                ) {
                  setState(
                    () {
                      _workoutDuration = v.round();
                      _recalculateAll();
                    },
                  );
                },
          ),

          Row(
            children: [
              _chip(
                "MET ${_metValue.toStringAsFixed(1)}",
              ),
              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Text(
                  'Formula: MET × weight(kg) × duration(hr)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  // ------------------------------- INTENSITY SELECTOR -------------------------------
  Widget _buildIntensitySegment() {
    return Row(
      children: WorkoutIntensity.values.map(
        (
          type,
        ) {
          final bool selected =
              _workoutIntensity ==
              type;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(
                  () {
                    _workoutIntensity = type;
                    _recalculateAll();
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                margin: const EdgeInsets.symmetric(
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white
                      : kCardColor,
                  borderRadius: BorderRadius.circular(
                    10,
                  ),
                  border: Border.all(
                    color: selected
                        ? kPrimaryAccent.withOpacity(
                            0.25,
                          )
                        : Colors.transparent,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: kPrimaryAccent.withOpacity(
                              0.06,
                            ),
                            blurRadius: 10,
                            offset: const Offset(
                              4,
                              6,
                            ),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    _intensityLabel(
                      type,
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

  String _intensityLabel(
    WorkoutIntensity type,
  ) {
    switch (type) {
      case WorkoutIntensity.low:
        return 'Low';
      case WorkoutIntensity.medium:
        return 'Medium';
      case WorkoutIntensity.high:
        return 'High';
    }
  }

  // ------------------------------- RESULTS CARD -------------------------------
  Widget _buildResultsCard() {
    return Container(
      padding: const EdgeInsets.all(
        18,
      ),
      decoration: _neumorphicDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Row(
            children: [
              const Text(
                'Results',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_bmrResult.toStringAsFixed(0)} cal/day',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'BMR',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),
          Text(
            'Instant metrics based on inputs',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
          const SizedBox(
            height: 18,
          ),

          /// BMI + Calories
          Row(
            children: [
              /// BMI CARD
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(
                    14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        offset: const Offset(
                          4,
                          4,
                        ),
                        color: Colors.black.withOpacity(
                          0.05,
                        ),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _bmiResult.toStringAsFixed(
                          1,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      _bmiChip(
                        _bmiStatus,
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      Text(
                        'BMI',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              /// CALORIES CARD
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _caloriesBurned.toStringAsFixed(
                            0,
                          ),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Text(
                          'cal',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    _chip(
                      _intensityLabel(
                        _workoutIntensity,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bmiChip(
    String status,
  ) {
    Color bg = Colors.grey.shade200;
    Color txt = Colors.grey.shade800;

    if (status ==
        'Healthy') {
      bg = Colors.green.withOpacity(
        0.15,
      );
      txt = Colors.green.shade700;
    } else if (status ==
            'Overweight' ||
        status ==
            'Underweight') {
      bg = Colors.orange.withOpacity(
        0.15,
      );
      txt = Colors.orange.shade700;
    } else if (status ==
        'Obese') {
      bg = Colors.red.withOpacity(
        0.15,
      );
      txt = Colors.red.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          12,
        ),
        color: bg,
      ),
      child: Text(
        status,
        style: TextStyle(
          color: txt,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  // ------------------------------- GENDER SEGMENT -------------------------------
  Widget _buildGenderSegment() {
    return Container(
      padding: const EdgeInsets.all(
        6,
      ),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(
          10,
        ),
      ),
      child:
          CupertinoSegmentedControl<
            String
          >(
            borderColor: Colors.grey.shade300,
            selectedColor: kPrimaryAccent.withOpacity(
              0.18,
            ),
            unselectedColor: kCardColor,
            pressedColor: kPrimaryAccent.withOpacity(
              0.09,
            ),
            groupValue: _gender,
            children: {
              'Male': Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                child: Column(
                  children: const [
                    Icon(
                      Icons.male,
                    ),
                    SizedBox(
                      height: 4,
                    ),
                    Text(
                      "Male",
                    ),
                  ],
                ),
              ),
              'Female': Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                child: Column(
                  children: const [
                    Icon(
                      Icons.female,
                    ),
                    SizedBox(
                      height: 4,
                    ),
                    Text(
                      "Female",
                    ),
                  ],
                ),
              ),
            },
            onValueChanged:
                (
                  v,
                ) {
                  setState(
                    () {
                      _gender = v;
                      _recalculateAll();
                    },
                  );
                },
          ),
    );
  }

  Widget _buildResetButton() {
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            12,
          ),
        ),
        padding: const EdgeInsets.all(
          10,
        ),
        child: Icon(
          Icons.refresh_rounded,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}
