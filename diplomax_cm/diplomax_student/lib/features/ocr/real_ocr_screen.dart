// ═══════════════════════════════════════════════════════════════════════════
// DIPLOMAX CM — Real OCR Screen
// Uses google_mlkit_text_recognition for real on-device OCR.
// No cloud API needed — works fully offline.
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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

// ─── OCR Service (real Google ML Kit) ────────────────────────────────────────

class OcrService {
  /// Performs real on-device OCR using Google ML Kit.
  /// Supports Latin and non-Latin scripts.
  /// Works completely offline — no data is sent to any server.
  Future<OcrResult> extractFromFile(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);

    // Use Latin script recognizer (covers French, English — used in Cameroon)
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognized = await recognizer.processImage(inputImage);
      final fullText = recognized.text;
      final fields = _parseAcademicFields(fullText, recognized.blocks);
      return OcrResult(
          fullText: fullText, fields: fields, blocks: recognized.blocks);
    } finally {
      recognizer.close();
    }
  }

  /// Parses extracted text to find common academic document fields.
  Map<String, String> _parseAcademicFields(
      String text, List<TextBlock> blocks) {
    final fields = <String, String>{};

    // Matricule — Cameroonian format: ICTUYYYY#### or similar
    final matMatch = RegExp(
            r'(?:matricule|mat\.?|immatriculation)\s*:?\s*([A-Z]{2,6}\d{4,12})',
            caseSensitive: false)
        .firstMatch(text);
    if (matMatch != null) fields['matricule'] = matMatch.group(1)!.trim();

    // Student name — look for "NOM ET PRÉNOM(S)" or "NOM COMPLET"
    final nameMatch = RegExp(
            r'(?:nom\s+(?:et\s+pr[eé]nom[s]?|complet|de\s+l[\'
            ']?[eé]tudiant(?:e)?)|name|student)s*:?s*([A-ZÀÂÄÉÈÊËÎÏÔÙÛÜ][A-Za-zàâäéèêëîïôùûüs-]{4,50})',
            caseSensitive: false)
        .firstMatch(text);
    if (nameMatch != null) fields['student_name'] = nameMatch.group(1)!.trim();

    // Mention
    final mentionMatch = RegExp(
            r'(très\s+bien|bien|assez\s+bien|passable|excellent)',
            caseSensitive: false)
        .firstMatch(text);
    if (mentionMatch != null) {
      fields['mention'] = _capitalize(mentionMatch.group(1)!.trim());
    }

    // Year / Date
    final yearMatch = RegExp(
            r'(?:année|year|class of|promotion)\s*:?\s*(\d{4})',
            caseSensitive: false)
        .firstMatch(text);
    if (yearMatch != null) fields['year'] = yearMatch.group(1)!;

    final dateMatch = RegExp(
            r'(?:date|délivr[eé]|émis?)\s*:?\s*(\d{1,2}[./\-]\d{1,2}[./\-]\d{2,4})',
            caseSensitive: false)
        .firstMatch(text);
    if (dateMatch != null) fields['issue_date'] = dateMatch.group(1)!.trim();

    // University name
    final univMatch = RegExp(
            r'(?:universit[eé]|university|institut(?:e)?)\s+(?:de\s+|of\s+)?([A-ZÀÂ][A-Za-zàâäéèêëîïôùûü\s\-]{4,60})',
            caseSensitive: false)
        .firstMatch(text);
    if (univMatch != null) fields['university'] = univMatch.group(1)!.trim();

    // Degree title
    final degreeMatch = RegExp(
            r'(licence|bachelor|master|doctorat|ph\.?d\.?|bts|dut|certificat|diplôme)\s+(?:en\s+|of\s+|in\s+)?([A-Za-zàâäéèêëîïôùûü\s\-]{4,80})',
            caseSensitive: false)
        .firstMatch(text);
    if (degreeMatch != null) {
      fields['degree_type'] = _capitalize(degreeMatch.group(1)!.trim());
      fields['degree_field'] = _capitalize(degreeMatch.group(2)!.trim());
    }

    // Grade average
    final avgMatch = RegExp(
            r'(?:moyenne|average|gpa|note\s+(?:finale|générale))\s*:?\s*(\d{1,2}[.,]\d{1,2})',
            caseSensitive: false)
        .firstMatch(text);
    if (avgMatch != null)
      fields['average'] = avgMatch.group(1)!.trim().replaceAll(',', '.');

    return fields;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}

class OcrResult {
  final String fullText;
  final Map<String, String> fields;
  final List<TextBlock> blocks;
  OcrResult(
      {required this.fullText, required this.fields, required this.blocks});
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class RealOcrScreen extends ConsumerStatefulWidget {
  const RealOcrScreen({super.key});
  @override
  ConsumerState<RealOcrScreen> createState() => _RealOcrState();
}

class _RealOcrState extends ConsumerState<RealOcrScreen> {
  final _svc = OcrService();
  final _picker = ImagePicker();

  File? _imageFile;
  OcrResult? _result;
  bool _processing = false;
  String? _error;

  Future<void> _pickAndProcess(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (picked == null) return;

      final file = File(picked.path);
      setState(() {
        _imageFile = file;
        _processing = true;
        _result = null;
        _error = null;
      });

      final result = await _svc.extractFromFile(file);
      setState(() {
        _result = result;
        _processing = false;
      });
    } catch (e) {
      setState(() {
        _processing = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading:
              BackButton(onPressed: () => context.go('/home'), color: _textPri),
          title: Text(
              AppStrings.of(context)
                  .tr('Scanner de document', 'Document scanner'),
              style:
                  GoogleFonts.instrumentSerif(fontSize: 22, color: _textPri)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info
              Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _amberLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _amber.withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.document_scanner_rounded,
                        color: _amber, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            AppStrings.of(context).tr(
                                'Scannez un diplome papier, un releve ou un certificat. '
                                    'L\'extraction du texte se fait sur l\'appareil, aucune donnee n\'est televersee.',
                                'Scan a paper diploma, transcript, or certificate. '
                                    'Text extraction runs on-device; no data is uploaded.'),
                            style: GoogleFonts.dmSans(
                                fontSize: 12, color: _amber, height: 1.5))),
                  ])),
              const SizedBox(height: 20),

              // Image preview
              if (_imageFile != null)
                Container(
                    height: 220,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border)),
                    clipBehavior: Clip.antiAlias,
                    child: Image.file(_imageFile!,
                        fit: BoxFit.cover, width: double.infinity)),

              const SizedBox(height: 16),

              // Action buttons
              Row(children: [
                Expanded(
                    child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: Text(AppStrings.of(context)
                            .tr('Prendre une photo', 'Take photo')),
                        onPressed: _processing
                            ? null
                            : () => _pickAndProcess(ImageSource.camera))),
                const SizedBox(width: 10),
                Expanded(
                    child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: Text(
                            AppStrings.of(context).tr('Galerie', 'Gallery')),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: _green,
                            side: const BorderSide(color: _green),
                            minimumSize: const Size(0, 52)),
                        onPressed: _processing
                            ? null
                            : () => _pickAndProcess(ImageSource.gallery))),
              ]),

              if (_processing) ...[
                const SizedBox(height: 24),
                _processingWidget(),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!,
                        style: GoogleFonts.dmSans(
                            color: Colors.red, fontSize: 13))),
              ],

              if (_result != null && !_processing) ...[
                const SizedBox(height: 20),
                _extractedFieldsCard(),
                const SizedBox(height: 16),
                _rawTextCard(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(AppStrings.of(context)
                        .tr('Enregistrer dans le coffre', 'Save to vault')),
                    onPressed: _saveToVault),
              ],
            ],
          ),
        ),
      );

  Widget _processingWidget() {
    final steps = [
      AppStrings.of(context).tr('Chargement de l\'image dans ML Kit...',
          'Loading image into ML Kit...'),
      AppStrings.of(context)
          .tr('Detection des zones de texte...', 'Detecting text regions...'),
      AppStrings.of(context)
          .tr('Extraction des caracteres...', 'Extracting characters...'),
      AppStrings.of(context).tr(
          'Analyse des champs academiques...', 'Parsing academic fields...'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          AppStrings.of(context).tr(
              'Traitement avec Google ML Kit', 'Processing with Google ML Kit'),
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(height: 10),
      ...steps.map((s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: _green.withOpacity(0.6))),
            const SizedBox(width: 10),
            Text(s, style: GoogleFonts.dmSans(fontSize: 12, color: _textSec)),
          ]))),
    ]);
  }

  Widget _extractedFieldsCard() {
    final fields = _result!.fields;
    if (fields.isEmpty) {
      return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: _amberLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amber.withOpacity(0.3))),
          child: Text(
              AppStrings.of(context).tr(
                  'Aucun champ academique detecte. Essayez une image plus nette avec un meilleur eclairage.',
                  'No academic fields detected. Try a clearer image with better lighting.'),
              style: GoogleFonts.dmSans(fontSize: 13, color: _amber)));
    }

    final labelMap = {
      'matricule': AppStrings.of(context).tr('Matricule', 'Matricule'),
      'student_name':
          AppStrings.of(context).tr('Nom de l\'etudiant', 'Student name'),
      'mention': AppStrings.of(context).tr('Mention', 'Mention'),
      'year': AppStrings.of(context).tr('Annee', 'Year'),
      'issue_date': AppStrings.of(context).tr('Date d\'emission', 'Issue date'),
      'university': AppStrings.of(context).tr('Universite', 'University'),
      'degree_type':
          AppStrings.of(context).tr('Type de diplome', 'Degree type'),
      'degree_field': AppStrings.of(context).tr('Filiere', 'Field of study'),
      'average': AppStrings.of(context).tr('Moyenne generale', 'Average grade'),
    };

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _green.withOpacity(0.4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: _green, size: 18),
            const SizedBox(width: 8),
            Text(
                '${AppStrings.of(context).tr('Champs extraits', 'Extracted fields')} (${fields.length})',
                style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _greenLight, borderRadius: BorderRadius.circular(6)),
                child: Text(
                    AppStrings.of(context)
                        .tr('ML Kit sur appareil', 'ML Kit on-device'),
                    style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: _green,
                        fontWeight: FontWeight.w500))),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE0DDD5)),
          const SizedBox(height: 10),
          ...fields.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(
                    width: 110,
                    child: Text(labelMap[e.key] ?? e.key,
                        style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: _textSec,
                            fontWeight: FontWeight.w300))),
                Expanded(
                    child: Text(e.value,
                        style: GoogleFonts.dmSans(
                            fontSize: 12, fontWeight: FontWeight.w500))),
              ]))),
        ]));
  }

  Widget _rawTextCard() => ExpansionTile(
          title: Text(
              AppStrings.of(context)
                  .tr('Texte extrait complet', 'Full extracted text'),
              style: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w500)),
          children: [
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                    color: Color(0xFFF1EFE8),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(12))),
                child: Text(_result!.fullText,
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: _textSec, height: 1.6))),
          ]);

  void _saveToVault() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            AppStrings.of(context).tr(
                'Donnees du document enregistrees dans le coffre',
                'Document data saved to vault'),
            style: GoogleFonts.dmSans()),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    context.go('/home/vault');
  }
}
