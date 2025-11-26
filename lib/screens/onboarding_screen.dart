// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/user.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  Set<String> selectedStyles = {'Street'};  // Changed to Set for multiple selection
  String selectedLevel = 'Beginner';
  double daysPerWeek = 5;
int numberOfWeeks = 4;

  final List<String> styles = ['Street', 'Portrait', 'Landscape', 'Wildlife', 'Architecture', 'Sports', 'Automotive', 'Event', 'Product'];
  final List<String> levels = ['Beginner', 'Intermediate', 'Advanced'];

  bool isLoading = false;

  Future<void> _createUser() async {
  if (selectedStyles.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select at least one style')),
    );
    return;
  }

  setState(() => isLoading = true);

  final db = await DatabaseHelper.instance.database;

  final totalDays = (daysPerWeek * numberOfWeeks).toInt();  // Calculate total

  final user = User(
    username: 'test_user',
    email: 'test@kapture.com',
    photographyStyles: selectedStyles.toList(),
    skillLevel: selectedLevel,
    daysPerWeek: totalDays,  // Store calculated total days
    createdAt: DateTime.now(),
  );

  await db.insert('users', user.toMap());

  if (mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Welcome to Kapture! 📸',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Let\'s personalize your learning journey',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Photography Style (Multiple selection)
              const Text(
                'Photography Styles',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select one or more styles',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: styles.map((style) {
                  final isSelected = selectedStyles.contains(style);
                  return FilterChip(
                    label: Text(style),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedStyles.add(style);
                        } else {
                          selectedStyles.remove(style);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // Skill Level
              const Text(
                'Skill Level',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: levels.map((level) {
                  return ChoiceChip(
                    label: Text(level),
                    selected: selectedLevel == level,
                    onSelected: (selected) {
                      setState(() => selectedLevel = level);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // Days per week
              const Text(
                'Training Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Days per week section
                    Expanded(
                    flex: 2,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        const Text(
                            'Days per week',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Row(
                            children: [
                            Expanded(
                                child: Slider(
                                value: daysPerWeek,
                                min: 3,
                                max: 7,
                                divisions: 4,
                                label: '${daysPerWeek.toInt()}',
                                onChanged: (value) {
                                    setState(() => daysPerWeek = value);
                                },
                                ),
                            ),
                            Text(
                                '${daysPerWeek.toInt()}',
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
                    const SizedBox(width: 24),
                    // Number of weeks section
                    Expanded(
                    flex: 1,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        const Text(
                            '# of weeks',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                            hintText: '4',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                            ),
                            ),
                            onChanged: (value) {
                            final weeks = int.tryParse(value);
                            if (weeks != null && weeks > 0) {
                                setState(() => numberOfWeeks = weeks);
                            }
                            },
                        ),
                        ],
                    ),
                    ),
                ],
                ),

              const Spacer(),

              // Generate Plan Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _createUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}