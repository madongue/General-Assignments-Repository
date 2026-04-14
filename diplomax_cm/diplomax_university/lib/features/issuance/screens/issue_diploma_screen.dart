import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../../core/api/api_client.dart';
import '../../../l10n/app_strings.dart';

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);
const _textHint = Color(0xFFAAAAAA);

// ── Issuance Form Model ───────────────────────────────────────────────────────

class IssuanceFormData {
  String studentMatricule = '';
  String documentType = 'diploma';
  String title = '';
  String degree = '';
  String field = '';
  String mention = 'Bien';
  String issueDate = '';
  List<CourseEntry> courses = [];
}

class CourseEntry {
  String code = '';
  String name = '';
  double grade = 0.0;
  int credits = 3;
  String semester = 'S1';
}

// ── API call ──────────────────────────────────────────────────────────────────

class IssuanceService {
  final _client = ApiClient();

  Future<IssuanceResult> issue(IssuanceFormData form) async {
    try {
      final response = await _client.dio.post(
        '/documents/issue',
        data: {
          'student_matricule': form.studentMatricule,
          'document_type': form.documentType,
          'title': form.title,
          'degree': form.degree,
          'field': form.field,
          'mention': form.mention,
          'issue_date': form.issueDate,
          'courses': form.courses
              .map((c) => {
                    'code': c.code,
                    'name': c.name,
                    'grade': c.grade,
                    'credits': c.credits,
                    'semester': c.semester,
                  })
              .toList(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      return IssuanceResult(
        success: true,
        documentId: data['document_id'] as String,
        hash: data['hash_sha256'] as String,
        blockchainTx: data['blockchain_tx'] as String?,
      );
    } on DioException catch (e) {
      return IssuanceResult(
        success: false,
        errorMessage: (e.response?.data as Map?)?['detail']?.toString() ??
            'Issuance failed',
      );
    }
  }
}

class IssuanceResult {
  final bool success;
  final String? documentId;
  final String? hash;
  final String? blockchainTx;
  final String? errorMessage;
  IssuanceResult(
      {required this.success,
      this.documentId,
      this.hash,
      this.blockchainTx,
      this.errorMessage});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class IssueDiplomaScreen extends ConsumerStatefulWidget {
  const IssueDiplomaScreen({super.key});
  @override
  ConsumerState<IssueDiplomaScreen> createState() => _IssueState();
}

class _IssueState extends ConsumerState<IssueDiplomaScreen> {
  final _form = GlobalKey<FormState>();
  final _data = IssuanceFormData();
  bool _loading = false;
  IssuanceResult? _result;

  final _svc = IssuanceService();

  final _types = ['diploma', 'transcript', 'certificate', 'attestation'];
  final _mentions = ['Très Bien', 'Bien', 'Assez Bien', 'Passable'];

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    setState(() {
      _loading = true;
      _result = null;
    });

    final result = await _svc.issue(_data);
    setState(() {
      _loading = false;
      _result = result;
    });

    if (result.success && mounted) {
      final strings = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.tr('Document emis et ancre sur la blockchain',
              'Document issued & anchored on blockchain')),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/issue/sign/${result.documentId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(strings.tr('Emettre un document', 'Issue a document'),
            style: GoogleFonts.instrumentSerif(fontSize: 20, color: _textPri)),
      ),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(
                  strings.tr('Informations etudiant', 'Student information')),
              _field(
                label: strings.tr('Matricule', 'Matricule'),
                hint: 'ICTU20223180',
                validator: (v) =>
                    v!.isEmpty ? strings.tr('Requis', 'Required') : null,
                onSaved: (v) => _data.studentMatricule = v!.trim(),
              ),
              const SizedBox(height: 20),

              _section(strings.tr('Details du document', 'Document details')),
              _label(strings.tr('Type de document', 'Document type')),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _data.documentType,
                decoration: const InputDecoration(),
                items: _types
                    .map((t) => DropdownMenuItem(
                        value: t, child: Text(_docTypeLabel(t, strings))))
                    .toList(),
                onChanged: (v) => setState(() => _data.documentType = v!),
              ),
              const SizedBox(height: 14),
              _field(
                label: strings.tr('Titre', 'Title'),
                hint: strings.tr('ex: Licence en Genie Logiciel',
                    'e.g. Bachelor of Software Engineering'),
                validator: (v) =>
                    v!.isEmpty ? strings.tr('Requis', 'Required') : null,
                onSaved: (v) => _data.title = v!.trim(),
              ),
              const SizedBox(height: 14),
              _field(
                label: strings.tr('Diplome', 'Degree'),
                hint:
                    strings.tr('ex: Licence, Master', 'e.g. Bachelor, Master'),
                onSaved: (v) => _data.degree = v!.trim(),
              ),
              const SizedBox(height: 14),
              _field(
                label: strings.tr('Domaine d\'etude', 'Field of study'),
                hint: strings.tr('ex: Genie Logiciel et Cybersecurite',
                    'e.g. Software Engineering & Cybersecurity'),
                onSaved: (v) => _data.field = v!.trim(),
              ),
              const SizedBox(height: 14),
              _label(strings.tr('Mention', 'Mention')),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _data.mention,
                decoration: const InputDecoration(),
                items: _mentions
                    .map((m) => DropdownMenuItem(
                        value: m, child: Text(_mentionLabel(m, strings))))
                    .toList(),
                onChanged: (v) => setState(() => _data.mention = v!),
              ),
              const SizedBox(height: 14),
              _field(
                label: strings.tr(
                    'Date d\'emission (AAAA-MM-JJ)', 'Issue date (YYYY-MM-DD)'),
                hint: '2024-07-15',
                validator: (v) =>
                    v!.isEmpty ? strings.tr('Requis', 'Required') : null,
                onSaved: (v) => _data.issueDate = v!.trim(),
              ),
              const SizedBox(height: 24),

              // Courses section (for transcripts/diplomas)
              if (_data.documentType == 'diploma' ||
                  _data.documentType == 'transcript') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(strings.tr('Cours / notes', 'Courses / grades'),
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _textPri,
                        )),
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(strings.tr('Ajouter un cours', 'Add course')),
                      onPressed: () =>
                          setState(() => _data.courses.add(CourseEntry())),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._data.courses.asMap().entries.map((e) => _CourseRow(
                      entry: e.value,
                      index: e.key,
                      onRemove: () =>
                          setState(() => _data.courses.removeAt(e.key)),
                    )),
                const SizedBox(height: 24),
              ],

              // Blockchain notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _greenLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, color: _green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.tr(
                          'Le hash SHA-256 de ce document sera automatiquement ancre sur la blockchain Hyperledger Fabric lors de l\'emission. Cela le rend verifiable en permanence et infalsifiable.',
                          'The SHA-256 hash of this document will be automatically anchored on the Hyperledger Fabric blockchain upon issuance. This makes it permanently verifiable and tamper-proof.',
                        ),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: _green,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ))
                    : const Icon(Icons.verified_rounded, size: 18),
                label: Text(_loading
                    ? strings.tr('Emission en cours...', 'Issuing...')
                    : strings.tr('Emettre et ancrer sur la blockchain',
                        'Issue & anchor on blockchain')),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: _loading ? null : _submit,
              ),

              if (_result != null && !_result!.success) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _result!.errorMessage ??
                        strings.tr('Erreur inconnue', 'Unknown error'),
                    style: GoogleFonts.dmSans(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          title,
          style: GoogleFonts.instrumentSerif(
            fontSize: 18,
            color: _textPri,
          ),
        ),
      );

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _textPri,
        ),
      );

  Widget _field({
    required String label,
    String? hint,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          TextFormField(
            decoration: InputDecoration(hintText: hint),
            validator: validator,
            onSaved: onSaved,
          ),
        ],
      );

  String _docTypeLabel(String t, AppStrings strings) {
    switch (t) {
      case 'diploma':
        return strings.tr('Diplome', 'Diploma');
      case 'transcript':
        return strings.tr('Releve', 'Transcript');
      case 'certificate':
        return strings.tr('Certificat', 'Certificate');
      case 'attestation':
        return strings.tr('Attestation', 'Attestation');
      default:
        return t;
    }
  }

  String _mentionLabel(String m, AppStrings strings) {
    switch (m) {
      case 'Très Bien':
        return strings.tr('Tres Bien', 'Very Good');
      case 'Bien':
        return strings.tr('Bien', 'Good');
      case 'Assez Bien':
        return strings.tr('Assez Bien', 'Fairly Good');
      case 'Passable':
        return strings.tr('Passable', 'Pass');
      default:
        return m;
    }
  }
}

class _CourseRow extends StatelessWidget {
  final CourseEntry entry;
  final int index;
  final VoidCallback onRemove;
  const _CourseRow(
      {required this.entry, required this.index, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(strings.tr('Cours ${index + 1}', 'Course ${index + 1}'),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSec,
                  )),
              const Spacer(),
              IconButton(
                icon:
                    const Icon(Icons.close_rounded, size: 16, color: _textHint),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextFormField(
                  decoration: InputDecoration(
                    hintText: strings.tr('Code', 'Code'),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                  onChanged: (v) => entry.code = v,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  decoration: InputDecoration(
                    hintText: strings.tr('Nom du cours', 'Course name'),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                  onChanged: (v) => entry.name = v,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: TextFormField(
                  decoration: InputDecoration(
                    hintText: strings.tr('Note', 'Grade'),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => entry.grade = double.tryParse(v) ?? 0.0,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
