// ═══════════════════════════════════════════════════════════════════════════
// INPUT METHOD 2 — PDF Scan
// University uploads an existing PDF document.
// Backend sends it to Google Cloud Vision OCR.
// Extracted fields are shown in an editable review form.
// Staff confirms/corrects, then submits for issuance.
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../../l10n/app_strings.dart';

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _blue = Color(0xFF185FA5);
const _blueLight = Color(0xFFE6F1FB);
const _amber = Color(0xFFBA7517);
const _amberLight = Color(0xFFFAEEDA);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);
const _textHint = Color(0xFFAAAAAA);

class PdfScanScreen extends ConsumerStatefulWidget {
  const PdfScanScreen({super.key});
  @override
  ConsumerState<PdfScanScreen> createState() => _PdfScanState();
}

enum _Phase { idle, uploading, reviewing, issuing, done }

class _PdfScanState extends ConsumerState<PdfScanScreen> {
  _Phase _phase = _Phase.idle;
  String? _fileName;
  int? _fileBytes;
  Map<String, dynamic> _extracted = {};
  String? _error;

  // Editable review controllers
  final _matCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _mentionCtrl = TextEditingController();
  final _univCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();
  final _fieldCtrl = TextEditingController();

  String? _issuedDocId;

  @override
  void dispose() {
    _matCtrl.dispose();
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _mentionCtrl.dispose();
    _univCtrl.dispose();
    _yearCtrl.dispose();
    _typeCtrl.dispose();
    _degreeCtrl.dispose();
    _fieldCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    // Pick PDF file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    setState(() {
      _phase = _Phase.uploading;
      _fileName = file.name;
      _fileBytes = file.size;
      _error = null;
    });

    try {
      // Send base64-encoded PDF to backend OCR endpoint
      final b64 = base64Encode(file.bytes!);
      final dio = Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('API_BASE_URL',
              defaultValue: 'https://diplomax-backend.onrender.com/v1')));

      final response = await dio.post('/ocr/extract', data: {
        'image_base64': b64,
        'mime_type': 'application/pdf',
      });

      final extracted =
          (response.data['extracted_fields'] as Map<String, dynamic>?) ?? {};

      // Pre-fill controllers with extracted values
      _matCtrl.text = extracted['matricule'] ?? '';
      _nameCtrl.text = extracted['student_name'] ?? '';
      _titleCtrl.text = extracted['title'] ?? '';
      _mentionCtrl.text = extracted['mention'] ?? '';
      _univCtrl.text = extracted['university'] ?? '';
      _yearCtrl.text = extracted['year'] ?? '';
      _typeCtrl.text = extracted['document_type'] ?? '';
      _degreeCtrl.text = extracted['degree'] ?? '';
      _fieldCtrl.text = extracted['field'] ?? '';

      setState(() {
        _extracted = extracted;
        _phase = _Phase.reviewing;
      });
    } on DioException catch (e) {
      setState(() {
        _error =
            '${AppStrings.of(context).tr('OCR echoue', 'OCR failed')}: ${(e.response?.data as Map?)?['detail'] ?? e.message}';
        _phase = _Phase.idle;
      });
    }
  }

  Future<void> _submitReviewed() async {
    setState(() {
      _phase = _Phase.issuing;
      _error = null;
    });
    try {
      final dio = Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('API_BASE_URL',
              defaultValue: 'https://diplomax-backend.onrender.com/v1')));

      final dateStr =
          _yearCtrl.text.isNotEmpty ? '${_yearCtrl.text}-06-30' : '2024-06-30';

      final r = await dio.post('/documents/issue', data: {
        'student_matricule': _matCtrl.text.trim().toUpperCase(),
        'document_type': _typeCtrl.text.trim().isEmpty
            ? 'certificate'
            : _typeCtrl.text.trim(),
        'title': _titleCtrl.text.trim(),
        'degree': _degreeCtrl.text.trim(),
        'field': _fieldCtrl.text.trim(),
        'mention': _mentionCtrl.text.trim().isEmpty
            ? 'Bien'
            : _mentionCtrl.text.trim(),
        'issue_date': dateStr,
        'courses': [],
      });

      setState(() {
        _issuedDocId = r.data['document_id'] as String?;
        _phase = _Phase.done;
      });
    } on DioException catch (e) {
      setState(() {
        _error = (e.response?.data as Map?)?['detail']?.toString() ??
            AppStrings.of(context).tr('Emission echouee', 'Issuance failed');
        _phase = _Phase.reviewing;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: BackButton(
              color: _textPri, onPressed: () => context.go('/issue')),
          title: Text(
              AppStrings.of(context)
                  .tr('Scanner un document PDF', 'Scan PDF document'),
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
      case _Phase.idle:
        return _buildIdle();
      case _Phase.uploading:
        return _buildUploading();
      case _Phase.reviewing:
        return _buildReview();
      case _Phase.issuing:
        return Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: _green),
          const SizedBox(height: 16),
          Text(AppStrings.of(context)
              .tr('Emission du document...', 'Issuing document...')),
        ]));
      case _Phase.done:
        return _buildDone();
    }
  }

  Widget _buildIdle() =>
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 100,
            height: 100,
            decoration:
                const BoxDecoration(color: _blueLight, shape: BoxShape.circle),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: _blue, size: 50)),
        const SizedBox(height: 24),
        Text(
            AppStrings.of(context)
                .tr('Televerser un document PDF', 'Upload a PDF document'),
            style: GoogleFonts.instrumentSerif(fontSize: 24, color: _textPri)),
        const SizedBox(height: 10),
        Text(
            AppStrings.of(context).tr(
                'Televersez n\'importe quel PDF universitaire existant : diplome, releve, certificat.\n'
                    'L\'OCR lit automatiquement le contenu et remplit tous les champs.',
                'Upload any existing university PDF - diploma, transcript, certificate.\n'
                    'OCR automatically reads the content and fills in all fields.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
                fontSize: 13,
                color: _textSec,
                height: 1.6,
                fontWeight: FontWeight.w300)),
        const SizedBox(height: 32),
        if (_error != null) ...[
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(_error!,
                  style: GoogleFonts.dmSans(color: Colors.red, fontSize: 12))),
          const SizedBox(height: 16),
        ],
        ElevatedButton.icon(
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(AppStrings.of(context)
                .tr('Selectionner le fichier PDF', 'Select PDF file')),
            style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed: _pickAndUpload),
        const SizedBox(height: 12),
        Text(
            AppStrings.of(context).tr('Format supporte : PDF jusqu\'a 20MB',
                'Supported format: PDF up to 20MB'),
            style: GoogleFonts.dmSans(fontSize: 11, color: _textHint)),
      ]);

  Widget _buildUploading() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(color: _blue, strokeWidth: 2),
        const SizedBox(height: 20),
        Text(
            '${AppStrings.of(context).tr('Analyse de', 'Scanning')} "$_fileName"...',
            style:
                GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(
            AppStrings.of(context).tr('L\'OCR lit le document sur le serveur.',
                'OCR is reading the document on the server.'),
            style: GoogleFonts.dmSans(fontSize: 12, color: _textSec)),
      ]));

  Widget _buildReview() => SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // File info banner
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _blueLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _blue.withOpacity(0.2))),
            child: Row(children: [
              const Icon(Icons.picture_as_pdf_rounded, color: _blue, size: 18),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_fileName ?? 'document.pdf',
                        style: GoogleFonts.dmSans(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    Text(
                        '${(_fileBytes ?? 0) ~/ 1024} KB · ${_extracted.length} ${AppStrings.of(context).tr('champs extraits', 'fields extracted')}',
                        style:
                            GoogleFonts.dmSans(fontSize: 11, color: _textSec)),
                  ])),
              TextButton(
                  onPressed: () => setState(() => _phase = _Phase.idle),
                  child: Text(
                      AppStrings.of(context).tr('Re-televerser', 'Re-upload'),
                      style: GoogleFonts.dmSans(color: _blue, fontSize: 12))),
            ])),
        const SizedBox(height: 16),
        _infoNote(AppStrings.of(context).tr(
            'Revisez les champs extraits ci-dessous. Corrigez les erreurs avant l\'emission.',
            'Review the extracted fields below. Correct any errors before issuing.')),
        const SizedBox(height: 16),
        _reviewField(
            AppStrings.of(context)
                .tr('Matricule etudiant *', 'Student matricule *'),
            _matCtrl,
            Icons.badge_rounded),
        _reviewField(
            AppStrings.of(context)
                .tr('Nom complet de l\'etudiant', 'Student full name'),
            _nameCtrl,
            Icons.person_rounded),
        _reviewField(
            AppStrings.of(context)
                .tr('Titre du document *', 'Document title *'),
            _titleCtrl,
            Icons.title_rounded),
        _reviewField(
            AppStrings.of(context).tr('Type de document', 'Document type'),
            _typeCtrl,
            Icons.category_rounded),
        _reviewField(AppStrings.of(context).tr('Diplome', 'Degree'),
            _degreeCtrl, Icons.school_rounded),
        _reviewField(AppStrings.of(context).tr('Filiere', 'Field of study'),
            _fieldCtrl, Icons.science_rounded),
        _reviewField(AppStrings.of(context).tr('Mention', 'Mention'),
            _mentionCtrl, Icons.stars_rounded),
        _reviewField(AppStrings.of(context).tr('Annee', 'Year'), _yearCtrl,
            Icons.calendar_today_rounded),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_error!,
                  style: GoogleFonts.dmSans(color: Colors.red, fontSize: 12))),
        ],
        const SizedBox(height: 20),
        ElevatedButton.icon(
            icon: const Icon(Icons.verified_rounded, size: 18),
            label: Text(AppStrings.of(context).tr(
                'Confirmer et emettre le document',
                'Confirm & issue document')),
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed: _submitReviewed),
      ]));

  Widget _buildDone() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 80,
            height: 80,
            decoration:
                const BoxDecoration(color: _greenLight, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: _green, size: 44)),
        const SizedBox(height: 20),
        Text(AppStrings.of(context).tr('Document emis !', 'Document issued!'),
            style: GoogleFonts.instrumentSerif(fontSize: 26, color: _textPri)),
        const SizedBox(height: 8),
        Text(
            AppStrings.of(context).tr(
                'Issu depuis un scan PDF. Disponible dans le coffre etudiant.',
                'From PDF scan. Available in student vault.'),
            style: GoogleFonts.dmSans(fontSize: 13, color: _textSec)),
        const SizedBox(height: 28),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0),
            onPressed: () => context.go('/issue'),
            child: Text(AppStrings.of(context)
                .tr('Emettre un autre document', 'Issue another document'))),
      ]));

  Widget _reviewField(
          String label, TextEditingController ctrl, IconData icon) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _textSec)),
            const SizedBox(height: 4),
            TextField(
                controller: ctrl,
                style: GoogleFonts.dmSans(fontSize: 13),
                decoration: InputDecoration(
                    prefixIcon: Icon(icon, size: 16, color: _textHint),
                    filled: true,
                    fillColor: _surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: _green, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true)),
          ]));

  Widget _infoNote(String text) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: _amberLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _amber.withOpacity(0.2))),
      child: Row(children: [
        const Icon(Icons.edit_rounded, color: _amber, size: 14),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: _amber, height: 1.4))),
      ]));
}
