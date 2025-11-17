// posture_analysis_view.dart

import 'package:flutter/material.dart';

const Color kPrimaryColor = Color(0xFF4C5BF1);
const Color kBackgroundColor = Color(0xFFF7F8FC);
const Color kAccentColor = Color(0xFF20B2AA); // Light Sea Green for Posture

class PostureAnalysisView extends StatefulWidget {
  const PostureAnalysisView({super.key});

  @override
  State<PostureAnalysisView> createState() => _PostureAnalysisViewState();
}

class _PostureAnalysisViewState extends State<PostureAnalysisView> {
  // State to simulate the analysis process
  bool _isAnalyzing = false;
  bool _analysisComplete = false;
  double _postureScore = 0.0; // Simulated score
  String _feedback = "";

  // Simulated analysis logic
  void _startAnalysis() async {
    setState(() {
      _isAnalyzing = true;
      _analysisComplete = false;
    });

    // Simulate API/AI processing time
    await Future.delayed(const Duration(seconds: 3));

    // Simulate results
    setState(() {
      _postureScore = 78.5;
      _feedback =
          "Good overall alignment! Focus on slightly straightening your neck.";
      _isAnalyzing = false;
      _analysisComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Posture Analysis',
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
            // --- 1. Instructions Card ---
            _buildInstructionsCard(),
            const SizedBox(height: 30),

            // --- 2. Action Button ---
            _buildActionButton(),
            const SizedBox(height: 40),

            // --- 3. Analysis Result Display (FIXED SYNTAX) ---
            _isAnalyzing
                ? _buildLoadingIndicator() // Show loading if analyzing
                : _analysisComplete
                ? _buildResultsDisplay() // Show results if complete
                : _buildInitialPrompt(), // Show prompt otherwise
          ],
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: kAccentColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: kAccentColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to get an accurate analysis:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 10),
          _InstructionStep(
            icon: Icons.person_outline,
            text: 'Stand sideways to the camera, wearing fitted clothing.',
          ),
          _InstructionStep(
            icon: Icons.straighten,
            text: 'Ensure full body is visible from head to toe.',
          ),
          _InstructionStep(
            icon: Icons.lightbulb_outline,
            text: 'Use good lighting and stand against a solid-colored wall.',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return ElevatedButton.icon(
      onPressed: _isAnalyzing ? null : _startAnalysis,
      icon: _isAnalyzing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : const Icon(Icons.camera_alt),
      label: Text(
        _isAnalyzing ? 'ANALYZING POSTURE...' : 'CAPTURE FOR ANALYSIS',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isAnalyzing
            ? kPrimaryColor.withOpacity(0.7)
            : kPrimaryColor,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircularProgressIndicator(color: kPrimaryColor),
            SizedBox(height: 15),
            Text(
              'Processing image, please wait...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialPrompt() {
    return const Center(
      child: Column(
        children: [
          Icon(Icons.camera_alt_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            'Tap "Capture for Analysis" to begin.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsDisplay() {
    return Container(
      padding: const EdgeInsets.all(25.0),
      decoration: BoxDecoration(
        color: kAccentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAccentColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Text(
            'Analysis Complete!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: kAccentColor,
            ),
          ),
          const SizedBox(height: 20),

          // Posture Score Display
          Column(
            children: [
              Text(
                _postureScore.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.w900,
                  color: kPrimaryColor,
                ),
              ),
              const Text(
                'Overall Posture Score / 100',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 40),

          // Feedback Section
          const Text(
            'Personalized Feedback:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _feedback,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Button for detailed tips/history
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Navigate to posture history or exercises
            },
            icon: const Icon(Icons.history, color: kAccentColor),
            label: const Text(
              'View Analysis History',
              style: TextStyle(color: kAccentColor),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper Widget for Instructions
class _InstructionStep extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InstructionStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kAccentColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
