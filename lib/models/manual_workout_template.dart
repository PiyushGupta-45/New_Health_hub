import 'package:flutter/material.dart';

class ManualWorkoutTemplate {
  const ManualWorkoutTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.met,
    this.difficulty = 'Moderate',
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final double met;
  final String difficulty;

  Color get accentColor =>
      gradientColors.isNotEmpty ? gradientColors.first : const Color(0xFF4C5BF1);
}

const List<ManualWorkoutTemplate> defaultManualWorkouts = [
  ManualWorkoutTemplate(
    id: 'run',
    title: 'Running',
    description: 'Steady pace outdoor or treadmill run',
    icon: Icons.directions_run_rounded,
    gradientColors: [Color(0xFFFF512F), Color(0xFFDD2476)],
    met: 9.8,
    difficulty: 'High',
  ),
  ManualWorkoutTemplate(
    id: 'walk',
    title: 'Walking',
    description: 'Brisk walk to increase your heart rate',
    icon: Icons.directions_walk_rounded,
    gradientColors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
    met: 3.5,
    difficulty: 'Light',
  ),
  ManualWorkoutTemplate(
    id: 'cycle',
    title: 'Cycling',
    description: 'Outdoor ride or stationary bike session',
    icon: Icons.pedal_bike_rounded,
    gradientColors: [Color(0xFF0BAB64), Color(0xFF3BB78F)],
    met: 7.5,
    difficulty: 'Medium',
  ),
  ManualWorkoutTemplate(
    id: 'yoga',
    title: 'Yoga',
    description: 'Flow focused on mobility and breath work',
    icon: Icons.self_improvement_rounded,
    gradientColors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
    met: 3.0,
    difficulty: 'Light',
  ),
  ManualWorkoutTemplate(
    id: 'strength',
    title: 'Strength Training',
    description: 'Bodyweight or weight room routine',
    icon: Icons.fitness_center_rounded,
    gradientColors: [Color(0xFFFFA751), Color(0xFFFFC3A0)],
    met: 6.0,
    difficulty: 'Medium',
  ),
  ManualWorkoutTemplate(
    id: 'hiit',
    title: 'HIIT Session',
    description: 'Short bursts of high intensity intervals',
    icon: Icons.bolt_rounded,
    gradientColors: [Color(0xFFF7971E), Color(0xFFFFD200)],
    met: 10.0,
    difficulty: 'Very High',
  ),
  ManualWorkoutTemplate(
    id: 'swim',
    title: 'Swimming',
    description: 'Laps or open water endurance work',
    icon: Icons.pool_rounded,
    gradientColors: [Color(0xFF56CCF2), Color(0xFF2C3E50)],
    met: 8.0,
    difficulty: 'High',
  ),
  ManualWorkoutTemplate(
    id: 'pilates',
    title: 'Pilates',
    description: 'Core-focused strength and mobility routine',
    icon: Icons.accessibility_new_rounded,
    gradientColors: [Color(0xFFB24592), Color(0xFFF15F79)],
    met: 3.5,
    difficulty: 'Light',
  ),
  ManualWorkoutTemplate(
    id: 'boxing',
    title: 'Boxing',
    description: 'Shadow boxing, bag work, or mitt drills',
    icon: Icons.sports_mma_rounded,
    gradientColors: [Color(0xFF42275A), Color(0xFF734B6D)],
    met: 9.0,
    difficulty: 'High',
  ),
  ManualWorkoutTemplate(
    id: 'dance',
    title: 'Dance Cardio',
    description: 'High-energy choreography for cardio fun',
    icon: Icons.music_note_rounded,
    gradientColors: [Color(0xFFFF5F6D), Color(0xFFFFC371)],
    met: 6.5,
    difficulty: 'Medium',
  ),
];