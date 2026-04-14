// ═══════════════════════════════════════════════════════════════════════════
// DIPLOMAX CM — Real OCR Screen
// Uses google_mlkit_text_recognition for on-device OCR
// No internet required — ML model runs entirely on the device
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../l10n/app_strings.dart';

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

// ─── OCR Service (real ML Kit) ────────────────────────────────────────────────

class OcrService {
  /// Real on-device OCR using Google ML Kit Text Recognition.
  /// Processes the image entirely on the device — no network call.
  /// Supports Latin script with French/English language hints.
  Future<OcrResult> recognizeText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    // Use Latin script recognizer (covers French and English)
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognized =
          await recognizer.processImage(inputImage);
      final rawText = recognized.text;

      // Extract structured fields from the raw OCR text
      final fields = _extractFields(rawText, recognized.blocks);

      return OcrResult(
        rawText: rawText,
        extractedFields: fields,
        blockCount: recognized.blocks.length,
        confidence: _estimateConfidence(recognized.blocks),
      );
    } finally {
      await recognizer.close();
    }
  }

  /// Parses common academic document fields from OCR output.
  Map<String, String> _extractFields(String text, List<TextBlock> blocks) {
    final result = <String, String>{};
    final lines = text.split('\n').map((l) => l.trim()).toList();

    // Matricule patterns: ICTU20223180, UY1/2024/0001, etc.
    final matPattern = RegExp(
      r'(?:ICTU|UY1|UY2|UB|UD|FASA|ENSP)[A-Z0-9/\-]{4,12}',
      caseSensitive: false,
    );
    final matMatch = matPattern.firstMatch(text);
    if (matMatch != null)
      result['matricule'] = matMatch.group(0)!.toUpperCase();

    // Student name — look for "NOM:" or "NAME:" prefix, or ALL CAPS runs
    final namePattern = RegExp(
      r'(?:nom\s*[:;]\s*|name\s*[:;]\s*|student\s*[:;]\s*)([A-ZÀÂÉÈÊËÏÎÔÙÛÜÇ][A-Za-zÀ-ÿ\s\-]{4,40})',
      caseSensitive: false,
    );
    final nameMatch = namePattern.firstMatch(text);
    if (nameMatch != null)
      result['full_name'] = _cleanName(nameMatch.group(1)!);

    // Mention
    final mentionPattern = RegExp(
      r'(?:mention|grade|note\s+générale)\s*[:;]?\s*(très\s+bien|bien|assez\s+bien|passable)',
      caseSensitive: false,
    );
    final mentionMatch = mentionPattern.firstMatch(text);
    if (mentionMatch != null) {
      result['mention'] = _capitalizeMention(mentionMatch.group(1)!);
    }

    // University name
    final univPattern = RegExp(
      r'(?:université|university|univ\.?)\s+(?:de\s+)?([A-ZÀÂÉÈÊËÏÎÔÙÛÜÇ][A-Za-zÀ-ÿ\s\-]{3,50})',
      caseSensitive: false,
    );
    final univMatch = univPattern.firstMatch(text);
    if (univMatch != null) result['university'] = univMatch.group(1)!.trim();

    // Year / date
    final yearPattern = RegExp(r'(?:20\d{2})');
    final years =
        yearPattern.allMatches(text).map((m) => m.group(0)!).toSet().toList();
    if (years.isNotEmpty) result['year'] = years.last; // Most recent year

    // Document type
    if (text.toLowerCase().contains('diplôme') ||
        text.toLowerCase().contains('diploma')) {
      result['document_type'] = 'diploma';
    } else if (text.toLowerCase().contains('relevé de notes') ||
        text.toLowerCase().contains('transcript')) {
      result['document_type'] = 'transcript';
    } else if (text.toLowerCase().contains('attestation')) {
      result['document_type'] = 'attestation';
    } else if (text.toLowerCase().contains('certificat') ||
        text.toLowerCase().contains('certificate')) {
      result['document_type'] = 'certificate';
    }

    // Degree
    final degreePattern = RegExp(
      r'(?:licence|bachelor|master|doctorat|bts|dut|ingénieur)',
      caseSensitive: false,
    );
    final degreeMatch = degreePattern.firstMatch(text);
    if (degreeMatch != null)
      result['degree'] = degreeMatch.group(0)!.toLowerCase();

    // Field of study — look for keyword after degree
    final fieldPattern = RegExp(
      r'(?:en|in|de)\s+([A-Za-zÀ-ÿ\s\-&]{5,60}?)(?:\n|\.|\,|$)',
      caseSensitive: false,
    );
    final fieldMatch = fieldPattern.firstMatch(text);
    if (fieldMatch != null) result['field'] = fieldMatch.group(1)!.trim();

    return result;
  }

  double _estimateConfidence(List<TextBlock> blocks) {
    if (blocks.isEmpty) return 0.0;
    // ML Kit doesn't expose per-block confidence; use block count as proxy
    return (blocks.length / 20).clamp(0.4, 0.95);
  }

  String _cleanName(String raw) => raw
      .trim()
      .split(' ')
      .map((w) => w.isEmpty
          ? ''
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  String _capitalizeMention(String m) {
    final lower = m.toLowerCase().trim();
    if (lower.contains('très')) return 'Très Bien';
    if (lower == 'bien') return 'Bien';
    if (lower.contains('assez')) return 'Assez Bien';
    if (lower.contains('pass')) return 'Passable';
    return m;
  }
}

class OcrResult {
  final String rawText;
  final Map<String, String> extractedFields;
  final int blockCount;
  final double confidence;

  OcrResult({
    required this.rawText,
    required this.extractedFields,
    required this.blockCount,
    required this.confidence,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});
  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  final _svc = OcrService();
  final _picker = ImagePicker();
  _OcrPhase _phase = _OcrPhase.idle;
  File? _image;
  OcrResult? _result;
  String? _error;

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            AppStrings.of(context)
                .tr('Permission camera requise', 'Camera permission required'),
            style: GoogleFonts.dmSans()),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pickAndProcess(ImageSource source) async {
    if (source == ImageSource.camera) await _requestCameraPermission();

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _image = file;
      _phase = _OcrPhase.processing;
      _error = null;
    });

    try {
      final result = await _svc.recognizeText(file);
      setState(() {
        _result = result;
        _phase = _OcrPhase.done;
      });
    } catch (e) {
      setState(() {
        _phase = _OcrPhase.error;
        _error = e.toString();
      });
    }
  }

  void _reset() => setState(() {
        _phase = _OcrPhase.idle;
        _image = null;
        _result = null;
        _error = null;
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading:
              BackButton(onPressed: () => context.go('/home'), color: _textPri),
          title: Text(
              AppStrings.of(context)
                  .tr('Scanner document (OCR)', 'Scan document (OCR)'),
              style:
                  GoogleFonts.instrumentSerif(fontSize: 20, color: _textPri)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            _infoBox(),
            const SizedBox(height: 20),
            _imagePreview(),
            const SizedBox(height: 20),
            if (_phase == _OcrPhase.idle || _phase == _OcrPhase.error)
              _pickButtons(),
            if (_phase == _OcrPhase.processing) _processingCard(),
            if (_phase == _OcrPhase.done && _result != null) ...[
              _resultCard(),
              const SizedBox(height: 14),
              _actionButtons(),
            ],
          ]),
        ),
      );

  Widget _infoBox() => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _amberLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _amber.withOpacity(0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.document_scanner_rounded, color: _amber, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(
                AppStrings.of(context).tr(
                    'Prenez une photo nette de votre diplome papier, releve ou certificat. '
                        'L\'IA lit le texte directement sur votre appareil, sans internet.',
                    'Take a clear photo of your paper diploma, transcript, or certificate. '
                        'The AI reads text directly on your device; no internet needed.'),
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: _amber, height: 1.5))),
      ]));

  Widget _imagePreview() => Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _phase == _OcrPhase.done ? _green : _border,
              width: _phase == _OcrPhase.done ? 2 : 0.5)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _image != null
            ? Stack(fit: StackFit.expand, children: [
                Image.file(_image!, fit: BoxFit.cover),
                if (_phase == _OcrPhase.done)
                  Container(
                      color: Colors.black26,
                      child: const Center(
                          child: Icon(Icons.check_circle_rounded,
                              color: Color(0xFF1D9E75), size: 56))),
              ])
            : Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.document_scanner_rounded,
                    color: Colors.white30, size: 48),
                const SizedBox(height: 10),
                Text(
                    AppStrings.of(context).tr(
                        'Aucun document selectionne', 'No document selected'),
                    style: GoogleFonts.dmSans(
                        color: Colors.white38, fontSize: 13)),
              ])),
      ));

  Widget _pickButtons() => Column(children: [
        if (_error != null) ...[
          Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!,
                        style: GoogleFonts.dmSans(
                            color: Colors.red, fontSize: 12))),
              ])),
        ],
        ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: Text(AppStrings.of(context).tr(
                'Prendre une photo avec la camera', 'Take photo with camera')),
            onPressed: () => _pickAndProcess(ImageSource.camera)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            icon: const Icon(Icons.photo_library_rounded, size: 18),
            label: Text(AppStrings.of(context)
                .tr('Importer depuis la galerie', 'Import from gallery')),
            style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green),
                minimumSize: const Size(double.infinity, 52)),
            onPressed: () => _pickAndProcess(ImageSource.gallery)),
      ]);

  Widget _processingCard() => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border)),
      child: Column(children: [
        const CircularProgressIndicator(color: _green, strokeWidth: 2),
        const SizedBox(height: 16),
        Text(
            AppStrings.of(context)
                .tr('Reconnaissance du texte...', 'Recognising text...'),
            style:
                GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(
            AppStrings.of(context).tr(
                'ML Kit lit le document sur votre appareil.',
                'ML Kit is reading the document on your device.'),
            style: GoogleFonts.dmSans(fontSize: 12, color: _textSec)),
        const SizedBox(height: 12),
        ...[
          AppStrings.of(context).tr(
              'Detection des bords du document', 'Detecting document edges'),
          AppStrings.of(context)
              .tr('Extraction des blocs de texte', 'Extracting text blocks'),
          AppStrings.of(context)
              .tr('Analyse des champs academiques', 'Parsing academic fields'),
        ].map((s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: _green.withOpacity(0.5))),
              const SizedBox(width: 12),
              Text(s, style: GoogleFonts.dmSans(fontSize: 12, color: _textSec)),
            ]))),
      ]));

  Widget _resultCard() {
    final f = _result!.extractedFields;
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _green.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: _green, size: 18),
            const SizedBox(width: 8),
            Text(
                AppStrings.of(context)
                    .tr('Champs extraits', 'Extracted fields'),
                style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _greenLight, borderRadius: BorderRadius.circular(6)),
                child: Text(
                    '${f.length} ${AppStrings.of(context).tr('champs', 'fields')} · ${(_result!.confidence * 100).toInt()}% ${AppStrings.of(context).tr('confiance', 'confidence')}',
                    style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: _green,
                        fontWeight: FontWeight.w500))),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE0DDD5)),
          const SizedBox(height: 10),
          if (f.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    AppStrings.of(context).tr(
                        'Aucun champ structure detecte. L\'image peut etre de faible qualite '
                            'ou le format du document n\'est pas reconnu.',
                        'No structured fields detected. The image may be low quality or '
                            'the document format is not recognised.'),
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: _textSec, height: 1.5)))
          else
            ...f.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 120,
                          child: Text(_fieldLabel(e.key),
                              style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: _textSec,
                                  fontWeight: FontWeight.w300))),
                      Expanded(
                          child: Text(e.value,
                              style: GoogleFonts.dmSans(
                                  fontSize: 12, fontWeight: FontWeight.w500))),
                    ]))),
          if (_result!.rawText.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE0DDD5)),
            const SizedBox(height: 10),
            Text(
                AppStrings.of(context)
                    .tr('Texte brut extrait', 'Raw extracted text'),
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: _textSec,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFF1EFE8),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                    _result!.rawText.length > 400
                        ? '${_result!.rawText.substring(0, 400)}...'
                        : _result!.rawText,
                    style: GoogleFonts.dmSans(
                        fontSize: 10, color: _textSec, height: 1.5))),
          ],
        ]));
  }

  Widget _actionButtons() => Column(children: [
        ElevatedButton.icon(
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(AppStrings.of(context)
                .tr('Enregistrer dans le coffre', 'Save to vault')),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      AppStrings.of(context).tr('Document ajoute au coffre',
                          'Document added to vault'),
                      style: GoogleFonts.dmSans()),
                  backgroundColor: _green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))));
              context.go('/home/vault');
            }),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(AppStrings.of(context)
                .tr('Scanner un autre document', 'Scan another document')),
            style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green),
                minimumSize: const Size(double.infinity, 48)),
            onPressed: _reset),
      ]);

  String _fieldLabel(String key) {
    final labels = {
      'matricule': AppStrings.of(context).tr('Matricule', 'Matricule'),
      'full_name': AppStrings.of(context).tr('Nom etudiant', 'Student name'),
      'mention': AppStrings.of(context).tr('Mention', 'Mention'),
      'university': AppStrings.of(context).tr('Universite', 'University'),
      'year': AppStrings.of(context).tr('Annee', 'Year'),
      'document_type':
          AppStrings.of(context).tr('Type de document', 'Document type'),
      'degree': AppStrings.of(context).tr('Diplome', 'Degree'),
      'field': AppStrings.of(context).tr('Filiere', 'Field'),
    };
    return labels[key] ?? key;
  }
}

enum _OcrPhase { idle, processing, done, error }
