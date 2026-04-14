// ═══════════════════════════════════════════════════════════════════════════
// INPUT METHOD 4 — Camera / Photo Scan
// University takes a live photo of a paper document.
// google_mlkit_text_recognition runs on-device OCR.
// Extracted fields shown in editable review form.
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:dio/dio.dart';
import '../../../l10n/app_strings.dart';

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _purple = Color(0xFF534AB7);
const _purpleLight = Color(0xFFEEEDFE);
const _amber = Color(0xFFBA7517);
const _amberLight = Color(0xFFFAEEDA);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);
const _textHint = Color(0xFFAAAAAA);
const _red = Color(0xFFA32D2D);

enum _PhotoPhase { idle, processing, reviewing, issuing, done }

class PhotoScanScreen extends ConsumerStatefulWidget {
  const PhotoScanScreen({super.key});
  @override
  ConsumerState<PhotoScanScreen> createState() => _PhotoScanState();
}

class _PhotoScanState extends ConsumerState<PhotoScanScreen> {
  _PhotoPhase _phase = _PhotoPhase.idle;
  File? _image;
  String _rawText = '';
  String? _error;

  final _matCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();
  final _fieldCtrl = TextEditingController();
  final _mentionCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  String? _issuedDocId;

  final _picker = ImagePicker();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void dispose() {
    _recognizer.close();
    _matCtrl.dispose();
    _titleCtrl.dispose();
    _typeCtrl.dispose();
    _degreeCtrl.dispose();
    _fieldCtrl.dispose();
    _mentionCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
        source: source, imageQuality: 90, maxWidth: 2000, maxHeight: 2000);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _image = file;
      _phase = _PhotoPhase.processing;
      _error = null;
    });

    try {
      // Real on-device OCR — no internet required
      final inputImage = InputImage.fromFile(file);
      final recognized = await _recognizer.processImage(inputImage);
      _rawText = recognized.text;

      // Parse fields
      final fields = _parseFields(_rawText);
      _matCtrl.text = fields['matricule'] ?? '';
      _titleCtrl.text = fields['title'] ?? '';
      _typeCtrl.text = fields['document_type'] ?? '';
      _degreeCtrl.text = fields['degree'] ?? '';
      _fieldCtrl.text = fields['field'] ?? '';
      _mentionCtrl.text = fields['mention'] ?? '';
      _dateCtrl.text = fields['year'] != null ? '${fields['year']}-06-30' : '';

      setState(() => _phase = _PhotoPhase.reviewing);
    } catch (e) {
      setState(() {
        _phase = _PhotoPhase.idle;
        _error =
            '${AppStrings.of(context).tr('Echec OCR', 'OCR failed')}: ${e.toString()}';
      });
    }
  }

  Map<String, String> _parseFields(String text) {
    final result = <String, String>{};
    // Matricule
    final mat =
        RegExp(r'(?:ICTU|UY1|UY2|UB)[A-Z0-9]{4,10}', caseSensitive: false)
            .firstMatch(text);
    if (mat != null) result['matricule'] = mat.group(0)!.toUpperCase();
    // Mention
    final mention = RegExp(r'(très\s+bien|bien|assez\s+bien|passable)',
            caseSensitive: false)
        .firstMatch(text);
    if (mention != null) result['mention'] = _capMention(mention.group(0)!);
    // Document type
    if (text.toLowerCase().contains('diplôme') ||
        text.toLowerCase().contains('diploma')) {
      result['document_type'] = 'diploma';
    } else if (text.toLowerCase().contains('relevé') ||
        text.toLowerCase().contains('transcript'))
      result['document_type'] = 'transcript';
    else if (text.toLowerCase().contains('attestation'))
      result['document_type'] = 'attestation';
    else if (text.toLowerCase().contains('certificat'))
      result['document_type'] = 'certificate';
    // Year
    final year = RegExp(r'20\d{2}').firstMatch(text);
    if (year != null) result['year'] = year.group(0)!;
    // Degree
    final deg = RegExp(r'(licence|bachelor|master|doctorat|bts|ingénieur)',
            caseSensitive: false)
        .firstMatch(text);
    if (deg != null) result['degree'] = deg.group(0)!;
    return result;
  }

  String _capMention(String m) {
    final l = m.toLowerCase().trim();
    if (l.contains('très')) return 'Très Bien';
    if (l == 'bien') return 'Bien';
    if (l.contains('assez')) return 'Assez Bien';
    return 'Passable';
  }

  Future<void> _issue() async {
    setState(() {
      _phase = _PhotoPhase.issuing;
      _error = null;
    });
    try {
      final dio = Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('API_BASE_URL',
              defaultValue: 'https://diplomax-backend.onrender.com/v1')));
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
        'issue_date': _dateCtrl.text.trim().isEmpty
            ? '2024-06-30'
            : _dateCtrl.text.trim(),
        'courses': [],
      });
      setState(() {
        _issuedDocId = r.data['document_id'] as String?;
        _phase = _PhotoPhase.done;
      });
    } on DioException catch (e) {
      setState(() {
        _error = (e.response?.data as Map?)?['detail']?.toString() ??
            AppStrings.of(context)
                .tr('Echec de l\'emission', 'Issuance failed');
        _phase = _PhotoPhase.reviewing;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading:
            BackButton(color: _textPri, onPressed: () => context.go('/issue')),
        title: Text(
            AppStrings.of(context)
                .tr('Scan camera / photo', 'Camera / photo scan'),
            style: GoogleFonts.instrumentSerif(fontSize: 20, color: _textPri)),
      ),
      body: Padding(padding: const EdgeInsets.all(20), child: _buildBody()));

  Widget _buildBody() {
    switch (_phase) {
      case _PhotoPhase.idle:
        return _idle();
      case _PhotoPhase.processing:
        return _processing();
      case _PhotoPhase.reviewing:
        return _reviewing();
      case _PhotoPhase.issuing:
        return const Center(child: CircularProgressIndicator(color: _green));
      case _PhotoPhase.done:
        return _done();
    }
  }

  Widget _idle() =>
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Image preview area
        Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border)),
            child: _image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(_image!, fit: BoxFit.cover))
                : Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.camera_alt_rounded,
                        color: Colors.white30, size: 48),
                    const SizedBox(height: 8),
                    Text(
                        AppStrings.of(context).tr('La photo apparaitra ici',
                            'Photo will appear here'),
                        style: GoogleFonts.dmSans(
                            color: Colors.white38, fontSize: 12)),
                  ]))),
        const SizedBox(height: 20),
        if (_error != null) ...[
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_error!,
                  style: GoogleFonts.dmSans(color: Colors.red, fontSize: 12))),
          const SizedBox(height: 12),
        ],
        ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: Text(AppStrings.of(context).tr(
                'Prendre une photo avec la camera', 'Take photo with camera')),
            style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed: () => _takePhoto(ImageSource.camera)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            icon: const Icon(Icons.photo_library_rounded, size: 18),
            label: Text(AppStrings.of(context)
                .tr('Importer depuis la galerie', 'Import from gallery')),
            style: OutlinedButton.styleFrom(
                foregroundColor: _purple,
                side: const BorderSide(color: _purple),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            onPressed: () => _takePhoto(ImageSource.gallery)),
        const SizedBox(height: 12),
        Text(
            AppStrings.of(context).tr(
                'L\'OCR fonctionne entierement sur cet appareil - pas d\'internet requis.',
                'OCR runs entirely on this device - no internet needed.'),
            style: GoogleFonts.dmSans(fontSize: 11, color: _textHint)),
      ]);

  Widget _processing() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(color: _purple, strokeWidth: 2),
        const SizedBox(height: 16),
        Text(
            AppStrings.of(context)
                .tr('Lecture du document...', 'Reading document...'),
            style:
                GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(
            AppStrings.of(context).tr('ML Kit OCR traite l\'image.',
                'ML Kit OCR is processing the image.'),
            style: GoogleFonts.dmSans(fontSize: 12, color: _textSec)),
      ]));

  Widget _reviewing() => SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Thumbnail
        if (_image != null)
          Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border)),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_image!, fit: BoxFit.cover))),
        const SizedBox(height: 12),
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _amberLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _amber.withOpacity(0.2))),
            child: Text(
                AppStrings.of(context).tr(
                    'Verifiez les champs extraits. Corrigez les erreurs avant emission.',
                    'Review extracted fields. Correct any errors before issuing.'),
                style: GoogleFonts.dmSans(fontSize: 11, color: _amber))),
        const SizedBox(height: 14),
        _rf(
            AppStrings.of(context)
                .tr('Matricule etudiant *', 'Student matricule *'),
            _matCtrl),
        _rf(
            AppStrings.of(context)
                .tr('Titre du document *', 'Document title *'),
            _titleCtrl),
        _rf(AppStrings.of(context).tr('Type de document', 'Document type'),
            _typeCtrl),
        _rf(AppStrings.of(context).tr('Diplome', 'Degree'), _degreeCtrl),
        _rf(AppStrings.of(context).tr('Domaine d\'etude', 'Field of study'),
            _fieldCtrl),
        _rf(AppStrings.of(context).tr('Mention', 'Mention'), _mentionCtrl),
        _rf(
            AppStrings.of(context)
                .tr('Date d\'emission (AAAA-MM-JJ)', 'Issue date (YYYY-MM-DD)'),
            _dateCtrl),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFCEBEB),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_error!,
                  style: GoogleFonts.dmSans(color: _red, fontSize: 12))),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _textSec,
                      side: const BorderSide(color: Color(0xFFE0DDD5)),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () => setState(() => _phase = _PhotoPhase.idle),
                  child:
                      Text(AppStrings.of(context).tr('Reprendre', 'Retake')))),
          const SizedBox(width: 10),
          Expanded(
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0),
                  onPressed: _issue,
                  child: Text(AppStrings.of(context).tr('Emettre', 'Issue')))),
        ]),
      ]));

  Widget _done() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 80,
            height: 80,
            decoration:
                const BoxDecoration(color: _greenLight, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: _green, size: 44)),
        const SizedBox(height: 20),
        Text(AppStrings.of(context).tr('Document emis!', 'Document issued!'),
            style: GoogleFonts.instrumentSerif(fontSize: 26, color: _textPri)),
        const SizedBox(height: 8),
        Text(
            AppStrings.of(context).tr(
                'Depuis un scan photo. Ancrage blockchain en cours.',
                'From photo scan. Blockchain anchoring in progress.'),
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
                .tr('Emettre un autre', 'Issue another'))),
      ]));

  Widget _rf(String label, TextEditingController ctrl) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 11, fontWeight: FontWeight.w500, color: _textSec)),
        const SizedBox(height: 4),
        TextField(
            controller: ctrl,
            style: GoogleFonts.dmSans(fontSize: 13),
            decoration: InputDecoration(
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
                    borderSide: const BorderSide(color: _green, width: 1.5)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true)),
      ]));
}
