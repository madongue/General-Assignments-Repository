import 'utils/grade_utils.dart';

/// A simple console-based runner to demonstrate the grading logic.
/// You can run this file directly to test calculations without the Flutter framework.
/// 
/// To run: dart lib/console_runner.dart
void main() {
  print("==============================================");
  print("   STUDENT GRADE CALCULATOR - CONSOLE MODE    ");
  print("==============================================");

  final students = [
    {'name': 'Alice', 'score': 95.0},
    {'name': 'Bob', 'score': 82.5},
    {'name': 'Charlie', 'score': 74.0},
    {'name': 'Daisy', 'score': 61.0},
    {'name': 'Ethan', 'score': 45.0},
    {'name': 'Fiona', 'score': null}, // Testing null score
  ];

  for (var student in students) {
    final name = student['name'];
    final score = student['score'] as double?;
    final grade = GradeUtils.calculateGrade(score);
    final scoreDisplay = GradeUtils.formatScore(score);
    print("Student: $name | Score: $scoreDisplay | Grade: $grade");
  }

  print("==============================================");
}
