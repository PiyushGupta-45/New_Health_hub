// posture_analysis_view.dart
// This file now directly shows the exercise selection page

import 'package:flutter/material.dart';
import './exercise_selection_page.dart';

class PostureAnalysisView
    extends
        StatefulWidget {
  const PostureAnalysisView({
    super.key,
  });

  @override
  State<
    PostureAnalysisView
  >
  createState() => _PostureAnalysisViewState();
}

class _PostureAnalysisViewState
    extends
        State<
          PostureAnalysisView
        > {
  @override
  Widget build(
    BuildContext context,
  ) {
    // Directly show the exercise selection page
    return const ExerciseSelectionPage();
  }
}
