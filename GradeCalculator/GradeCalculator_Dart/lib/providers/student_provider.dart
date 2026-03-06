import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/db_helper.dart';
import '../utils/grade_utils.dart';

class StudentProvider with ChangeNotifier {
  List<Student> _students = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Student> get students => _students;

  Future<void> fetchStudents() async {
    _students = await _dbHelper.getStudents();
    notifyListeners();
  }

  Future<void> addStudent(String name, double? score) async {
    String grade = GradeUtils.calculateGrade(score);
    Student student = Student(name: name, score: score, grade: grade);
    await _dbHelper.insertStudent(student);
    await fetchStudents();
  }

  Future<void> addAllStudents(List<Student> students) async {
    for (var student in students) {
      await _dbHelper.insertStudent(student);
    }
    await fetchStudents();
  }

  Future<void> updateStudent(Student student, String newName, double? newScore) async {
    String newGrade = GradeUtils.calculateGrade(newScore);
    Student updatedStudent = Student(
      id: student.id,
      name: newName,
      score: newScore,
      grade: newGrade,
    );
    await _dbHelper.updateStudent(updatedStudent);
    await fetchStudents();
  }

  Future<void> deleteStudent(int id) async {
    await _dbHelper.deleteStudent(id);
    await fetchStudents();
  }

  // Alias for backward compatibility if needed
  Future<void> addAll(List<Student> students) async {
    await addAllStudents(students);
  }

  Future<void> clearAll() async {
    await _dbHelper.clearAll();
    _students = [];
    notifyListeners();
  }

  double get averageScore {
    final validScores = _students.where((s) => s.score != null).map((s) => s.score!);
    if (validScores.isEmpty) return 0.0;
    return validScores.reduce((a, b) => a + b) / validScores.length;
  }

  double get highestScore {
    final validScores = _students.where((s) => s.score != null).map((s) => s.score!);
    if (validScores.isEmpty) return 0.0;
    return validScores.reduce((a, b) => a > b ? a : b);
  }

  double get lowestScore {
    final validScores = _students.where((s) => s.score != null).map((s) => s.score!);
    if (validScores.isEmpty) return 0.0;
    return validScores.reduce((a, b) => a < b ? a : b);
  }
}
