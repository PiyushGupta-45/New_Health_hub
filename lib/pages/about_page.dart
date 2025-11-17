// This file contains the complete widget for the about page.

import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(
          top: 40.0,
          bottom: 24.0,
          left: 24.0,
          right: 24.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About FitTrack',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'FitTrack is a smart fitness tracker app built to help users stay active and healthy. It combines goal setting, workout tracking, posture analysis, and data visualization in one intuitive platform. Our mission is to provide you with the tools and insights you need to achieve your health goals and maintain a balanced lifestyle.',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFFE5E7EB)),
            const SizedBox(height: 24),
            const Text(
              'Team Members',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 16),
            buildTeamMemberCard('Piyush', 'Project Lead & Architect'),
            const SizedBox(height: 12),
            buildTeamMemberCard('Bhupesh', 'Data Engineer & Backend Dev'),
            const SizedBox(height: 12),
            buildTeamMemberCard('Varun', 'UI/UX Designer'),
            const SizedBox(height: 12),
            buildTeamMemberCard('Sarovan', 'Analyst & Feature Implementer'),
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: const [
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '© 2025 FitTrack Inc.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTeamMemberCard(String name, String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: Colors.indigo, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                role,
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
