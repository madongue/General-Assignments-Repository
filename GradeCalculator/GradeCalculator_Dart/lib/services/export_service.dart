import 'dart:io';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/student.dart';
import '../utils/grade_utils.dart';

class ExportService {
  static Future<void> exportToExcel(List<Student> students) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    sheetObject.appendRow([
      TextCellValue('Name'),
      TextCellValue('Score'),
      TextCellValue('Grade'),
    ]);

    for (var student in students) {
      sheetObject.appendRow([
        TextCellValue(student.name),
        TextCellValue(GradeUtils.formatScore(student.score)),
        TextCellValue(student.grade),
      ]);
    }

    var fileBytes = excel.save();
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/student_grades.xlsx');
    await file.writeAsBytes(fileBytes!);

    await Share.shareXFiles([XFile(file.path)], text: 'Student Grades Excel');
  }

  static Future<void> exportToPdf(List<Student> students) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Name', 'Score', 'Grade'],
            data: students
                .map((s) => [s.name, GradeUtils.formatScore(s.score), s.grade])
                .toList(),
          );
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/student_grades.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Student Grades PDF');
  }
}
