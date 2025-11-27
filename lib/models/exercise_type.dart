// Exercise Type Model
// Defines different exercises that can be analyzed for posture

import 'package:flutter/material.dart';

enum ExerciseType {
  generalPosture,
  squat,
  pushUp,
  plank,
  lunge,
  deadlift,
  overheadPress,
  pullUp,
  bridge,
  mountainClimber,
}

extension ExerciseTypeExtension
    on
        ExerciseType {
  String get name {
    switch (this) {
      case ExerciseType.generalPosture:
        return 'General Posture';
      case ExerciseType.squat:
        return 'Squat';
      case ExerciseType.pushUp:
        return 'Push-Up';
      case ExerciseType.plank:
        return 'Plank';
      case ExerciseType.lunge:
        return 'Lunge';
      case ExerciseType.deadlift:
        return 'Deadlift';
      case ExerciseType.overheadPress:
        return 'Overhead Press';
      case ExerciseType.pullUp:
        return 'Pull-Up';
      case ExerciseType.bridge:
        return 'Bridge';
      case ExerciseType.mountainClimber:
        return 'Mountain Climber';
    }
  }

  String get description {
    switch (this) {
      case ExerciseType.generalPosture:
        return 'Analyze your overall standing posture';
      case ExerciseType.squat:
        return 'Check your squat form and depth';
      case ExerciseType.pushUp:
        return 'Analyze push-up alignment and depth';
      case ExerciseType.plank:
        return 'Check plank form and body alignment';
      case ExerciseType.lunge:
        return 'Analyze lunge posture and balance';
      case ExerciseType.deadlift:
        return 'Check deadlift form and back alignment';
      case ExerciseType.overheadPress:
        return 'Analyze overhead press posture';
      case ExerciseType.pullUp:
        return 'Check pull-up form and grip';
      case ExerciseType.bridge:
        return 'Analyze bridge pose alignment';
      case ExerciseType.mountainClimber:
        return 'Check mountain climber form';
    }
  }

  String get instructions {
    switch (this) {
      case ExerciseType.generalPosture:
        return 'Stand straight, facing the camera. Keep your full body visible.';
      case ExerciseType.squat:
        return 'Stand facing the camera. Perform a squat. Keep your full body visible.';
      case ExerciseType.pushUp:
        return 'Position yourself in push-up position, facing the camera. Keep your full body visible.';
      case ExerciseType.plank:
        return 'Get into plank position, facing the camera. Keep your full body visible.';
      case ExerciseType.lunge:
        return 'Stand facing the camera. Perform a lunge. Keep your full body visible.';
      case ExerciseType.deadlift:
        return 'Stand facing the camera. Perform a deadlift. Keep your full body visible.';
      case ExerciseType.overheadPress:
        return 'Stand facing the camera. Hold weights overhead. Keep your full body visible.';
      case ExerciseType.pullUp:
        return 'Position yourself for pull-up, facing the camera. Keep your full body visible.';
      case ExerciseType.bridge:
        return 'Get into bridge position, facing the camera. Keep your full body visible.';
      case ExerciseType.mountainClimber:
        return 'Get into plank position, facing the camera. Keep your full body visible.';
    }
  }

  IconData get icon {
    switch (this) {
      case ExerciseType.generalPosture:
        return Icons.accessibility_new;
      case ExerciseType.squat:
        return Icons.fitness_center;
      case ExerciseType.pushUp:
        return Icons.sports_gymnastics;
      case ExerciseType.plank:
        return Icons.straighten;
      case ExerciseType.lunge:
        return Icons.directions_run;
      case ExerciseType.deadlift:
        return Icons.trending_up;
      case ExerciseType.overheadPress:
        return Icons.arrow_upward;
      case ExerciseType.pullUp:
        return Icons.trending_up;
      case ExerciseType.bridge:
        return Icons.architecture;
      case ExerciseType.mountainClimber:
        return Icons.speed;
    }
  }
}
