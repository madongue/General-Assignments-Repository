# Full Project Documentation: GradeCalculator (Flutter/Dart)

This document provides a detailed technical breakdown of the Student Grade Calculator application implemented using the Flutter framework.

## 1. Architectural Overview: Provider-based Modular Design
The application is built using a modular architecture, with the **Provider** package handling state management. This ensures a clean separation between the data logic and the UI widgets.

### A. The Model Layer (`lib/models/student.dart`)
The `Student` data class defines our core data structure.
```dart
class Student {
  final int? id;
  final String name;
  final double? score; // Nullable to handle "No score"
  final String grade;

  // Conversion methods for SQLite (sqflite)
  Map<String, dynamic> toMap() => { 'id': id, 'name': name, 'score': score, 'grade': grade };
}
```
- **Explanation**: By using a nullable `double?` for the score, we allow the application to accept student records that lack a mark, displaying them as "No score" instead of defaulting to 0, which would incorrectly affect the statistics.

### B. The State Management Layer (`lib/providers/student_provider.dart`)
The `StudentProvider` is the central "State Hub."
```dart
double get averageScore {
  final validScores = _students.map((s) => s.score).whereType<double>();
  if (validScores.isEmpty) return 0.0;
  return validScores.reduce((a, b) => a + b) / validScores.length;
}
```
- **Code Logic**: The `whereType<double>()` method is a key Dart feature. It filters out any `null` values from the student list, ensuring that the average, highest, and lowest score calculations are mathematically accurate and only include students with actual marks.

### C. The Service Layer (`lib/services`)
This layer handles all external integrations.
- **db_helper.dart**: Manages the local SQLite database. It includes logic to **Upgrade** the database schema from version 1 to 2 when the `score` field was made nullable, ensuring no data loss for existing users.
- **import_service.dart**: Uses the `excel` package to parse `.xlsx` files. It converts binary data into a list of `Student` objects, automatically calculating grades upon import.
- **export_service.dart**: A multi-format reporting engine.
```dart
await Share.shareXFiles([XFile(file.path)], text: 'Student Grades PDF');
```
- **Sharing Logic**: After generating an Excel or PDF file, the app uses the `share_plus` package to invoke the native sharing menu, allowing users to send the report directly via email or messaging apps.

### D. The View Layer (UI Screens)
- **ManualEntryScreen.dart**: A form-based input screen. It validates that a name is present but treats an empty score field as a valid `null` entry.
- **ResultsScreen.dart**: Displays student cards. It features a `PopupMenuButton` for **Selective Modification** and **Deletion**, providing full CRUD (Create, Read, Update, Delete) capability.

## 2. Core Logic: GradeUtils.dart
This utility class is a "Pure Function" source. It takes an optional score and returns the corresponding grade:
- **90.0 - 100.0**: A
- **80.0 - 89.9**: B
- **70.0 - 79.9**: C
- **60.0 - 69.9**: D
- **Below 60.0**: F
- **Null**: "No Grade"

## 3. Cross-Platform Strategy
While this app is running on an Android emulator, the Flutter implementation is **Platform Agnostic**. The use of `path_provider` ensures that files are saved in the correct system directories whether the app is running on Android or iOS.

## 4. Key Differences from Kotlin Implementation
- **UI**: Flutter uses a declarative "Widget Tree" instead of XML layouts.
- **Database**: Flutter uses raw SQL via `sqflite`, whereas Kotlin uses the `Room` abstraction layer.
- **Files**: Flutter uses Dart packages like `excel` and `pdf` for reporting, providing a unified cross-platform experience.
