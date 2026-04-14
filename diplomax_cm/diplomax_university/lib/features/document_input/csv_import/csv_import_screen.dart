// ═══════════════════════════════════════════════════════════════════════════
// INPUT METHOD 3 — CSV Bulk Import
// University uploads a CSV/Excel file with multiple students.
// App parses the file, shows a preview table, then issues all at once.
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../../l10n/app_strings.dart';

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _amber = Color(0xFFBA7517);
const _amberLight = Color(0xFFFAEEDA);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);
const _textHint = Color(0xFFAAAAAA);
const _red = Color(0xFFA32D2D);
const _redLight = Color(0xFFFCEBEB);

class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key});
  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportState();
}

class _CsvRow {
  String matricule;
  String docType;
  String title;
  String degree;
  String field;
  String mention;
  String issueDate;
  bool selected;
  String status; // pending | issuing | done | error
  String? errorMsg;

  _CsvRow({
    required this.matricule,
    required this.docType,
    required this.title,
    required this.degree,
    required this.field,
    required this.mention,
    required this.issueDate,
  })  : selected = true,
        status = 'pending';
}

enum _CsvPhase { idle, preview, issuing, done }

class _CsvImportState extends ConsumerState<CsvImportScreen> {
  _CsvPhase _phase = _CsvPhase.idle;
  List<_CsvRow> _rows = [];
  String? _fileName;
  String? _parseError;
  int _doneCount = 0;
  int _errorCount = 0;

  // ── Expected CSV columns ───────────────────────────────────────────────────
  static const _expectedColumns = [
    'matricule',
    'doc_type',
    'title',
    'degree',
    'field',
    'mention',
    'issue_date',
  ];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null) return;

    final file = result.files.first;
    setState(() {
      _parseError = null;
      _rows = [];
    });

    try {
      final content = utf8.decode(file.bytes!);
      final rows = _parseCsv(content);
      setState(() {
        _rows = rows;
        _fileName = file.name;
        _phase = _CsvPhase.preview;
      });
    } catch (e) {
      setState(() => _parseError =
          '${AppStrings.of(context).tr('Impossible d\'analyser le CSV', 'Could not parse CSV')}: ${e.toString()}');
    }
  }

  List<_CsvRow> _parseCsv(String content) {
    final lines = content.split('\n').map((l) => l.trim()).toList();
    if (lines.isEmpty) {
      throw Exception(
          AppStrings.of(context).tr('Le fichier est vide', 'File is empty'));
    }

    // Header row
    final headers =
        lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();

    // Validate required columns
    for (final col in _expectedColumns) {
      if (!headers.contains(col)) {
        throw Exception(
            '${AppStrings.of(context).tr('Colonne manquante', 'Missing column')}: $col. ${AppStrings.of(context).tr('Requises', 'Required')}: ${_expectedColumns.join(', ')}');
      }
    }

    final idx = {for (final c in _expectedColumns) c: headers.indexOf(c)};

    final rows = <_CsvRow>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      // Handle quoted fields with commas
      final cells = _splitCsvLine(line);
      if (cells.length < headers.length) continue;

      rows.add(_CsvRow(
        matricule: cells[idx['matricule']!].trim().toUpperCase(),
        docType: cells[idx['doc_type']!].trim().toLowerCase(),
        title: cells[idx['title']!].trim(),
        degree: cells[idx['degree']!].trim(),
        field: cells[idx['field']!].trim(),
        mention: cells[idx['mention']!].trim(),
        issueDate: cells[idx['issue_date']!].trim(),
      ));
    }
    if (rows.isEmpty) {
      throw Exception(AppStrings.of(context).tr(
          'Aucune ligne de donnees trouvee dans le fichier',
          'No data rows found in file'));
    }
    return rows;
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (c == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
        continue;
      }
      current.write(c);
    }
    result.add(current.toString());
    return result;
  }

  Future<void> _issueAll() async {
    setState(() {
      _phase = _CsvPhase.issuing;
      _doneCount = 0;
      _errorCount = 0;
    });

    final dio = Dio(BaseOptions(
        baseUrl: const String.fromEnvironment('API_BASE_URL',
            defaultValue: 'https://diplomax-backend.onrender.com/v1')));

    final selected = _rows.where((r) => r.selected).toList();

    for (final row in selected) {
      if (!mounted) break;
      setState(() => row.status = 'issuing');

      try {
        await dio.post('/documents/issue', data: {
          'student_matricule': row.matricule,
          'document_type': row.docType,
          'title': row.title,
          'degree': row.degree,
          'field': row.field,
          'mention': row.mention,
          'issue_date': row.issueDate,
          'courses': [],
        });
        setState(() {
          row.status = 'done';
          _doneCount++;
        });
      } on DioException catch (e) {
        final msg = (e.response?.data as Map?)?['detail']?.toString() ??
            AppStrings.of(context).tr('Erreur', 'Error');
        setState(() {
          row.status = 'error';
          row.errorMsg = msg;
          _errorCount++;
        });
      }

      // Small delay to avoid overwhelming the API
      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() => _phase = _CsvPhase.done);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: BackButton(
              color: _textPri, onPressed: () => context.go('/issue')),
          title: Text(
              AppStrings.of(context).tr('Import CSV en lot', 'CSV bulk import'),
              style:
                  GoogleFonts.instrumentSerif(fontSize: 20, color: _textPri)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildBody(),
        ),
      );

  Widget _buildBody() {
    switch (_phase) {
      case _CsvPhase.idle:
        return _buildIdle();
      case _CsvPhase.preview:
        return _buildPreview();
      case _CsvPhase.issuing:
        return _buildProgress();
      case _CsvPhase.done:
        return _buildResults();
    }
  }

  Widget _buildIdle() => SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Icon + title
        Center(
            child: Column(children: [
          Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                  color: _amberLight, shape: BoxShape.circle),
              child: const Icon(Icons.table_chart_rounded,
                  color: _amber, size: 46)),
          const SizedBox(height: 16),
          Text(
              AppStrings.of(context).tr(
                  'Importer plusieurs etudiants', 'Import multiple students'),
              style:
                  GoogleFonts.instrumentSerif(fontSize: 22, color: _textPri)),
          const SizedBox(height: 8),
          Text(
              AppStrings.of(context).tr(
                  'Televersez un fichier CSV pour emettre plusieurs documents a la fois.',
                  'Upload a CSV file to issue documents to many students at once.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: _textSec,
                  fontWeight: FontWeight.w300,
                  height: 1.5)),
        ])),
        const SizedBox(height: 28),

        // CSV format specification
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _amberLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _amber.withOpacity(0.2))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  AppStrings.of(context)
                      .tr('Format CSV requis', 'Required CSV format'),
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _amber)),
              const SizedBox(height: 8),
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text(
                      'matricule,doc_type,title,degree,field,mention,issue_date\n'
                      'ICTU20223180,diploma,Licence en GL,Licence,Génie Logiciel,Bien,2024-07-15\n'
                      'ICTU20224001,transcript,Relevé S5-S6,Licence,Informatique,Très Bien,2024-07-15',
                      style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 9,
                          color: Color(0xFF7DFFB3),
                          height: 1.5))),
              const SizedBox(height: 8),
              Text(
                  AppStrings.of(context).tr(
                      'doc_type doit etre : diploma | transcript | certificate | attestation\n'
                          'mention doit etre : Tres Bien | Bien | Assez Bien | Passable\n'
                          'issue_date doit etre : YYYY-MM-DD',
                      'doc_type must be: diploma | transcript | certificate | attestation\n'
                          'mention must be: Very Good | Good | Fairly Good | Pass\n'
                          'issue_date must be: YYYY-MM-DD'),
                  style: GoogleFonts.dmSans(
                      fontSize: 10, color: _amber, height: 1.5)),
            ])),
        const SizedBox(height: 20),

        if (_parseError != null) ...[
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _redLight, borderRadius: BorderRadius.circular(8)),
              child: Text(_parseError!,
                  style: GoogleFonts.dmSans(color: _red, fontSize: 12))),
          const SizedBox(height: 12),
        ],

        ElevatedButton.icon(
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(AppStrings.of(context)
                .tr('Televerser le fichier CSV', 'Upload CSV file')),
            style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed: _pickFile),
        const SizedBox(height: 12),
        // Template download hint
        Center(
            child: Text(
                AppStrings.of(context).tr(
                    'Besoin d\'un modele ? Creez une feuille avec les colonnes ci-dessus.',
                    'Need a template? Create a spreadsheet with the columns above.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 11, color: _textHint))),
      ]));

  Widget _buildPreview() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary bar
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _greenLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _green.withOpacity(0.2))),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: _green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      '${_rows.length} ${AppStrings.of(context).tr('etudiants trouves dans', 'students found in')} "$_fileName"',
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: _green,
                          fontWeight: FontWeight.w500))),
              TextButton(
                  onPressed: () => setState(() => _phase = _CsvPhase.idle),
                  child: Text(
                      AppStrings.of(context).tr('Re-televerser', 'Re-upload'),
                      style: GoogleFonts.dmSans(color: _green, fontSize: 12))),
            ])),
        const SizedBox(height: 12),
        // Select all / deselect
        Row(children: [
          Text(
              AppStrings.of(context).tr('Selectionner les lignes a emettre :',
                  'Select rows to issue:'),
              style: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          TextButton(
              onPressed: () => setState(() {
                    for (final r in _rows) {
                      r.selected = true;
                    }
                  }),
              child: Text(AppStrings.of(context).tr('Toutes', 'All'),
                  style: GoogleFonts.dmSans(color: _green, fontSize: 12))),
          TextButton(
              onPressed: () => setState(() {
                    for (final r in _rows) {
                      r.selected = false;
                    }
                  }),
              child: Text(AppStrings.of(context).tr('Aucune', 'None'),
                  style: GoogleFonts.dmSans(color: _textSec, fontSize: 12))),
        ]),
        const SizedBox(height: 6),
        // Preview table
        Expanded(
            child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (_, i) {
                  final row = _rows[i];
                  return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: row.selected
                              ? _greenLight.withOpacity(0.5)
                              : _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: row.selected
                                  ? _green.withOpacity(0.3)
                                  : _border)),
                      child: Row(children: [
                        Checkbox(
                            value: row.selected,
                            activeColor: _green,
                            onChanged: (v) =>
                                setState(() => row.selected = v ?? false)),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(row.matricule,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              Text(
                                  '${row.title} · ${row.mention} · ${row.issueDate}',
                                  style: GoogleFonts.dmSans(
                                      fontSize: 11, color: _textSec),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ])),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: _greenLight,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(row.docType,
                                style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    color: _green,
                                    fontWeight: FontWeight.w500))),
                      ]));
                })),
        const SizedBox(height: 12),
        ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(
                '${AppStrings.of(context).tr('Emettre', 'Issue')} ${_rows.where((r) => r.selected).length} ${AppStrings.of(context).tr('documents', 'documents')}'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed: _rows.any((r) => r.selected) ? _issueAll : null),
      ]);

  Widget _buildProgress() {
    final total = _rows.where((r) => r.selected).length;
    final done = _doneCount + _errorCount;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(color: _green, strokeWidth: 2),
      const SizedBox(height: 20),
      Text(
          AppStrings.of(context)
              .tr('Emission des documents...', 'Issuing documents...'),
          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Text(
          '$done / $total ${AppStrings.of(context).tr('termines', 'completed')}',
          style: GoogleFonts.dmSans(fontSize: 12, color: _textSec)),
      const SizedBox(height: 16),
      LinearProgressIndicator(
          value: total > 0 ? done / total : 0,
          backgroundColor: _border,
          valueColor: const AlwaysStoppedAnimation<Color>(_green)),
    ]);
  }

  Widget _buildResults() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: _statBox(
                  '$_doneCount',
                  AppStrings.of(context).tr('Emis', 'Issued'),
                  _green,
                  _greenLight)),
          const SizedBox(width: 12),
          Expanded(
              child: _statBox(
                  '$_errorCount',
                  AppStrings.of(context).tr('Echoues', 'Failed'),
                  _errorCount > 0 ? _red : _textHint,
                  _errorCount > 0 ? _redLight : _bg)),
        ]),
        const SizedBox(height: 16),
        Expanded(
            child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (_, i) {
                  final r = _rows[i];
                  if (!r.selected) return const SizedBox.shrink();
                  return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: r.status == 'done'
                              ? _greenLight
                              : r.status == 'error'
                                  ? _redLight
                                  : _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: r.status == 'done'
                                  ? _green.withOpacity(0.3)
                                  : r.status == 'error'
                                      ? _red.withOpacity(0.3)
                                      : _border)),
                      child: Row(children: [
                        Icon(
                            r.status == 'done'
                                ? Icons.check_circle_rounded
                                : r.status == 'error'
                                    ? Icons.error_rounded
                                    : Icons.hourglass_empty_rounded,
                            color: r.status == 'done'
                                ? _green
                                : r.status == 'error'
                                    ? _red
                                    : _textHint,
                            size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(r.matricule,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              if (r.errorMsg != null)
                                Text(r.errorMsg!,
                                    style: GoogleFonts.dmSans(
                                        fontSize: 10, color: _red)),
                            ])),
                      ]));
                })),
        const SizedBox(height: 12),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0),
            onPressed: () => context.go('/documents'),
            child: Text(AppStrings.of(context)
                .tr('Aller aux documents', 'Go to documents'))),
      ]);

  Widget _statBox(String v, String l, Color c, Color bg) => Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withOpacity(0.3))),
      child: Column(children: [
        Text(v, style: GoogleFonts.instrumentSerif(fontSize: 28, color: c)),
        Text(l, style: GoogleFonts.dmSans(fontSize: 12, color: c)),
      ]));
}
