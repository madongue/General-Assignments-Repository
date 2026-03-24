import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../models/student.dart';
import '../utils/grade_utils.dart';

class ImportService {
  static Future<List<Student>> pickAndParseExcel() async {
    // Updated to allow .csv files as well
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result != null) {
      String filePath = result.files.single.path!;
      List<Student> students = [];

      if (filePath.endsWith('.csv')) {
        // Handle CSV parsing
        final file = File(filePath);
        final lines = await file.readAsLines();
        
        // Skip header if it exists
        int startIndex = 0;
        if (lines.isNotEmpty && lines[0].toLowerCase().contains('name')) {
          startIndex = 1;
        }

        for (var i = startIndex; i < lines.length; i++) {
          final parts = lines[i].split(',');
          if (parts.length >= 2) {
            String name = parts[0].trim();
            double? score = double.tryParse(parts[1].trim());
            
            if (name.isNotEmpty) {
              students.add(Student(
                name: name,
                score: score,
                grade: GradeUtils.calculateGrade(score),
              ));
            }
          }
        }
      } else {
        // Handle Excel parsing
        var bytes = File(filePath).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table]!;
          for (var i = 1; i < sheet.maxRows; i++) {
            var row = sheet.rows[i];
            if (row.isNotEmpty) {
              String name = row[0]?.value?.toString() ?? "";
              String? scoreStr = row.length > 1 ? row[1]?.value?.toString() : null;
              double? score = double.tryParse(scoreStr ?? "");

              if (name.isNotEmpty) {
                students.add(Student(
                  name: name,
                  score: score,
                  grade: GradeUtils.calculateGrade(score),
                ));
              }
            }
          }
        }
      }
      return students;
    }
    return [];
  }
}
