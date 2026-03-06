import 'models/student.dart';
import 'utils/grade_utils.dart';

/// Milestone 1: Functional Programming Concepts in Dart
/// This file demonstrates functions operating on data classes, higher-order functions,
/// anonymous functions (lambdas), and collection operations.

// 1. Two functions that operate on the Student class
String formatStudentDetails(Student student) {
  final scoreText = GradeUtils.formatScore(student.score);
  return "Student: ${student.name} | Score: $scoreText | Grade: ${student.grade}";
}

bool isStudentValid(Student student) {
  return student.name.trim().isNotEmpty && (student.score == null || (student.score! >= 0 && student.score! <= 100));
}

// 2. Custom higher-order function
void processStudentList(List<Student> students, void Function(Student) action) {
  for (var student in students) {
    action(student);
  }
}

void main() {
  print("--- Milestone 1: Dart Grade Calculator Demonstration ---");

  final studentList = [
    Student(name: "Alice", score: 95.0, grade: "A"),
    Student(name: "Bob", score: 82.0, grade: "B"),
    Student(name: "Charlie", score: 74.0, grade: "C"),
    Student(name: "Daisy", score: 68.0, grade: "D"),
    Student(name: "Ethan", score: 55.0, grade: "F"),
    Student(name: "Fiona", score: null, grade: "No Grade"),
    Student(name: "Invalid", score: 150.0, grade: "F"),
  ];

  // 3. Showcase: Collection operation (filter/where a list of items)
  print("\n1. Filtering valid students (score between 0 and 100 or null):");
  final validStudents = studentList.where((s) => isStudentValid(s)).toList();
  for (var s in validStudents) {
    print(formatStudentDetails(s));
  }

  // 4. Showcase: Lambda passed to a custom higher-order function
  print("\n2. Processing students with an anonymous function (printing only those with grades):");
  processStudentList(validStudents, (student) {
    if (student.grade != "No Grade") {
      print("Verified Result: ${student.name} -> ${student.grade}");
    }
  });

  // 5. Showcase: Using map (higher-order function) to get names
  final names = validStudents.map((s) => s.name).toList();
  print("\n3. Student Names List: $names");
}
