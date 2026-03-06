import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../models/student.dart';
import '../utils/grade_utils.dart';

class ImportService {
  static Future<List<Student>> pickAndParseExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null) {
      var bytes = File(result.files.single.path!).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      List<Student> students = [];

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
      return students;
    }
    return [];
  }
}
