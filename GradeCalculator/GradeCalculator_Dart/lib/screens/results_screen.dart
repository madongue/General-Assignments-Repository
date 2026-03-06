import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/student_provider.dart';
import '../services/export_service.dart';
import '../utils/grade_utils.dart';
import '../models/student.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  void _showEditDialog(BuildContext context, Student student) {
    final nameController = TextEditingController(text: student.name);
    final scoreController = TextEditingController(text: student.score?.toString() ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: scoreController,
              decoration: const InputDecoration(labelText: 'Score (0-100)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = nameController.text;
              final scoreStr = scoreController.text;
              final newScore = scoreStr.isNotEmpty ? double.tryParse(scoreStr) : null;
              
              if (newName.isNotEmpty) {
                Provider.of<StudentProvider>(context, listen: false)
                    .updateStudent(student, newName, newScore);
                Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentProvider>(
      builder: (context, provider, child) {
        final students = provider.students;

        return Scaffold(
          body: students.isEmpty
              ? const Center(child: Text('No student records found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ListTile(
                        title: Text(
                          student.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Score: ${GradeUtils.formatScore(student.score)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                student.grade,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditDialog(context, student);
                                } else if (value == 'delete') {
                                  provider.deleteStudent(student.id!);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: 'excel',
                tooltip: 'Export to Excel',
                onPressed: () async {
                  if (students.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No records to export')),
                    );
                  } else {
                    await ExportService.exportToExcel(students);
                  }
                },
                child: const Icon(Icons.table_chart),
              ),
              const SizedBox(height: 16),
              FloatingActionButton(
                heroTag: 'pdf',
                tooltip: 'Export to PDF',
                onPressed: () async {
                  if (students.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No records to export')),
                    );
                  } else {
                    await ExportService.exportToPdf(students);
                  }
                },
                child: const Icon(Icons.picture_as_pdf),
              ),
            ],
          ),
        );
      },
    );
  }
}
