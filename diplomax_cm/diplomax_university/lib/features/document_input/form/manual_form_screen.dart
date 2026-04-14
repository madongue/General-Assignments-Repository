// ═══════════════════════════════════════════════════════════════════════════
// INPUT METHOD 1 — Manual Form
// Full field-by-field entry for any document type.
// Adapts visible fields based on document type selected.
// ═══════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../l10n/app_strings.dart';

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);
const _textHint = Color(0xFFAAAAAA);
const _red = Color(0xFFA32D2D);

// ─── Grade row ────────────────────────────────────────────────────────────────
class _GradeRow {
  String code = '';
  String name = '';
  double grade = 0.0;
  int credits = 3;
  String semester = 'S1';
  final key = GlobalKey();
}

// ─── Manual Form Screen ───────────────────────────────────────────────────────
class ManualDocumentFormScreen extends ConsumerStatefulWidget {
  const ManualDocumentFormScreen({super.key});
  @override
  ConsumerState<ManualDocumentFormScreen> createState() => _ManualFormState();
}

class _ManualFormState extends ConsumerState<ManualDocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _success = false;
  String? _issuedDocId;
  String? _errorMsg;

  // ── Form values ─────────────────────────────────────────────────────────────
  String _docType = 'diploma';
  final String _matricule = '';
  final String _title = '';
  final String _degree = '';
  String _mention = 'Bien';
  DateTime? _issueDate;
  final List<_GradeRow> _grades = [];

  // ── Controllers ─────────────────────────────────────────────────────────────
  final _matCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();
  final _fieldCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  // ── Document type options ────────────────────────────────────────────────────
  static const _docTypes = [
    ('diploma', 'Diploma', Icons.school_rounded),
    ('transcript', 'Transcript', Icons.description_rounded),
    ('certificate', 'Certificate', Icons.verified_rounded),
    ('attestation', 'Attestation', Icons.assignment_rounded),
  ];

  static const _mentions = [
    'Très Bien',
    'Bien',
    'Assez Bien',
    'Passable',
  ];

  static const _degrees = [
    'Licence (Bachelor)',
    'Master',
    'Doctorat (PhD)',
    'BTS',
    'DUT',
    'Ingénieur',
    'DES',
    'DESS',
    'Certificat',
    'Diplôme Professionnel',
  ];

  static const _semesters = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8'];

  bool get _showGrades => _docType == 'diploma' || _docType == 'transcript';

  @override
  void dispose() {
    _matCtrl.dispose();
    _titleCtrl.dispose();
    _degreeCtrl.dispose();
    _fieldCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  // ── Pre-fill title based on doc type + degree ─────────────────────────────
  void _autoTitle() {
    if (_degreeCtrl.text.isNotEmpty && _fieldCtrl.text.isNotEmpty) {
      final deg = _degreeCtrl.text.split(' ').first; // e.g. "Licence"
      _titleCtrl.text = '$deg en ${_fieldCtrl.text}';
    }
  }

  // ── Date picker ─────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: const ColorScheme.light(primary: _green)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _issueDate = picked;
        _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final dio = Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('API_BASE_URL',
              defaultValue: 'https://diplomax-backend.onrender.com/v1')));

      final response = await dio.post('/documents/issue', data: {
        'student_matricule': _matCtrl.text.trim().toUpperCase(),
        'document_type': _docType,
        'title': _titleCtrl.text.trim(),
        'degree': _degreeCtrl.text.trim(),
        'field': _fieldCtrl.text.trim(),
        'mention': _mention,
        'issue_date': _dateCtrl.text.trim(),
        'courses': _grades
            .map((g) => {
                  'code': g.code,
                  'name': g.name,
                  'grade': g.grade,
                  'credits': g.credits,
                  'semester': g.semester,
                })
            .toList(),
      });

      setState(() {
        _loading = false;
        _success = true;
        _issuedDocId = response.data['document_id'] as String?;
      });
    } on DioException catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = (e.response?.data as Map?)?['detail']?.toString() ??
            AppStrings.of(context).tr(
                'Emission echouee. Verifiez le matricule.',
                'Issuance failed. Please check the matricule.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) return _buildSuccessScreen();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading:
            BackButton(color: _textPri, onPressed: () => context.go('/issue')),
        title: Text(
            AppStrings.of(context).tr('Formulaire manuel', 'Manual form'),
            style: GoogleFonts.instrumentSerif(fontSize: 20, color: _textPri)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Step 1: Document type ─────────────────────────────────────
            _stepHeader('1',
                AppStrings.of(context).tr('Type de document', 'Document type')),
            const SizedBox(height: 10),
            _docTypeSelector(),
            const SizedBox(height: 24),

            // ── Step 2: Student ──────────────────────────────────────────
            _stepHeader('2', AppStrings.of(context).tr('Etudiant', 'Student')),
            const SizedBox(height: 10),
            _field(
              ctrl: _matCtrl,
              label: AppStrings.of(context).tr('Matricule *', 'Matricule *'),
              hint: 'ICTU20223180',
              icon: Icons.badge_rounded,
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppStrings.of(context)
                      .tr('Le matricule est requis', 'Matricule is required')
                  : null,
            ),
            const SizedBox(height: 24),

            // ── Step 3: Document details ─────────────────────────────────
            _stepHeader(
                '3',
                AppStrings.of(context)
                    .tr('Details du document', 'Document details')),
            const SizedBox(height: 10),
            _dropdownRow(
                AppStrings.of(context).tr('Diplome / niveau', 'Degree / level'),
                _degrees,
                _degreeCtrl.text, (v) {
              setState(() => _degreeCtrl.text = v);
              _autoTitle();
            }),
            const SizedBox(height: 12),
            _field(
              ctrl: _fieldCtrl,
              label: AppStrings.of(context).tr('Filiere *', 'Field of study *'),
              hint: 'Software Engineering & Cybersecurity',
              icon: Icons.school_rounded,
              onChanged: (_) => _autoTitle(),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppStrings.of(context)
                      .tr('La filiere est requise', 'Field is required')
                  : null,
            ),
            const SizedBox(height: 12),
            _field(
              ctrl: _titleCtrl,
              label: AppStrings.of(context)
                  .tr('Titre complet du document *', 'Full document title *'),
              hint: 'e.g. Licence en Génie Logiciel',
              icon: Icons.title_rounded,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppStrings.of(context)
                      .tr('Le titre est requis', 'Title is required')
                  : null,
            ),
            const SizedBox(height: 12),
            _dropdownRow(
                AppStrings.of(context).tr('Mention', 'Mention / honour'),
                _mentions,
                _mention,
                (v) => setState(() => _mention = v)),
            const SizedBox(height: 12),
            _field(
              ctrl: _dateCtrl,
              label: AppStrings.of(context)
                  .tr('Date d\'emission *', 'Issue date *'),
              hint: AppStrings.of(context)
                  .tr('Touchez pour choisir une date', 'Tap to pick date'),
              icon: Icons.calendar_today_rounded,
              readOnly: true,
              onTap: _pickDate,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppStrings.of(context).tr('La date d\'emission est requise',
                      'Issue date is required')
                  : null,
            ),
            const SizedBox(height: 24),

            // ── Step 4: Courses (only for diploma/transcript) ─────────────
            if (_showGrades) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _stepHeader(
                    '4',
                    AppStrings.of(context)
                        .tr('Notes des cours', 'Course grades')),
                TextButton.icon(
                    icon:
                        const Icon(Icons.add_rounded, size: 16, color: _green),
                    label: Text(
                        AppStrings.of(context)
                            .tr('Ajouter un cours', 'Add course'),
                        style: GoogleFonts.dmSans(color: _green, fontSize: 13)),
                    onPressed: () => setState(() => _grades.add(_GradeRow()))),
              ]),
              const SizedBox(height: 8),
              if (_grades.isEmpty)
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border)),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          color: _textHint, size: 16),
                      const SizedBox(width: 8),
                      Text(
                          AppStrings.of(context).tr(
                              'Aucun cours ajoute. Touchez "Ajouter un cours" pour commencer.',
                              'No courses added. Tap "Add course" to begin.'),
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: _textHint)),
                    ]))
              else
                ..._grades.asMap().entries.map((e) => _GradeRowWidget(
                      index: e.key,
                      row: e.value,
                      semesters: _semesters,
                      onRemove: () => setState(() => _grades.removeAt(e.key)),
                      onChanged: () => setState(() {}),
                    )),
              if (_grades.isNotEmpty) ...[
                const SizedBox(height: 8),
                _averageCard(),
              ],
              const SizedBox(height: 24),
            ],

            // ── Error ────────────────────────────────────────────────────
            if (_errorMsg != null) ...[
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFCEBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _red.withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: _red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_errorMsg!,
                            style:
                                GoogleFonts.dmSans(fontSize: 12, color: _red))),
                  ])),
              const SizedBox(height: 16),
            ],

            // ── Blockchain info ──────────────────────────────────────────
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _greenLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _green.withOpacity(0.2))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.security_rounded,
                          color: _green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              AppStrings.of(context).tr(
                                  'Lors de la soumission, une empreinte SHA-256 est calculee et ancree '
                                      'sur la blockchain Hyperledger. Ce document restera verifiable de facon permanente.',
                                  'On submission, a SHA-256 fingerprint is computed and anchored '
                                      'on the Hyperledger blockchain. This document will be permanently verifiable.'),
                              style: GoogleFonts.dmSans(
                                  fontSize: 11, color: _green, height: 1.5))),
                    ])),
            const SizedBox(height: 20),

            // ── Submit ───────────────────────────────────────────────────
            ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.verified_rounded, size: 18),
                label: Text(_loading
                    ? AppStrings.of(context).tr('Emission...', 'Issuing...')
                    : AppStrings.of(context).tr(
                        'Emettre et ancrer sur blockchain',
                        'Issue & anchor on blockchain')),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
                onPressed: _loading ? null : _submit),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() => Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
            child: Center(
                child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                    color: _greenLight, shape: BoxShape.circle),
                child:
                    const Icon(Icons.check_rounded, color: _green, size: 44)),
            const SizedBox(height: 24),
            Text(
                AppStrings.of(context)
                    .tr('Document emis !', 'Document issued!'),
                style:
                    GoogleFonts.instrumentSerif(fontSize: 28, color: _textPri)),
            const SizedBox(height: 10),
            Text(
                AppStrings.of(context).tr(
                    'Le document a ete cree, chiffre et ancre sur la blockchain.\n'
                        'L\'etudiant peut maintenant y acceder dans son coffre Diplomax.',
                    'The document has been created, encrypted, and anchored on the blockchain.\n'
                        'The student can now access it in their Diplomax vault.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: _textSec,
                    fontWeight: FontWeight.w300,
                    height: 1.6)),
            const SizedBox(height: 8),
            if (_issuedDocId != null)
              Text(
                  '${AppStrings.of(context).tr('ID document', 'Document ID')}: ${_issuedDocId!.substring(0, 8).toUpperCase()}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: _textHint,
                  )),
            const SizedBox(height: 32),
            ElevatedButton.icon(
                icon: const Icon(Icons.draw_rounded, size: 18),
                label: Text(AppStrings.of(context)
                    .tr('Signer le document maintenant', 'Sign document now')),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0),
                onPressed: () =>
                    context.go('/issue/sign/${_issuedDocId ?? ""}')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(AppStrings.of(context)
                    .tr('Emettre un autre document', 'Issue another document')),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => context.go('/issue')),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => context.go('/documents'),
                child: Text(
                    AppStrings.of(context).tr('Aller a la liste des documents',
                        'Go to documents list'),
                    style: GoogleFonts.dmSans(color: _textSec, fontSize: 13))),
          ]),
        ))),
      );

  Widget _stepHeader(String num, String title) => Row(children: [
        Container(
            width: 26,
            height: 26,
            decoration:
                const BoxDecoration(color: _green, shape: BoxShape.circle),
            child: Center(
                child: Text(num,
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)))),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.dmSans(
                fontSize: 15, fontWeight: FontWeight.w500, color: _textPri)),
      ]);

  Widget _docTypeSelector() => Row(
        children: _docTypes.map((t) {
          final active = _docType == t.$1;
          return Expanded(
              child: GestureDetector(
            onTap: () => setState(() => _docType = t.$1),
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: active ? _greenLight : _surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: active ? _green : _border,
                        width: active ? 1.5 : 0.5)),
                child: Column(children: [
                  Icon(t.$3, color: active ? _green : _textHint, size: 22),
                  const SizedBox(height: 4),
                  Text(AppStrings.of(context).tr(t.$2, t.$2),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: active ? _green : _textSec)),
                ])),
          ));
        }).toList(),
      );

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    String? hint,
    IconData? icon,
    bool readOnly = false,
    VoidCallback? onTap,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w500, color: _textSec)),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          validator: validator,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(fontSize: 13, color: _textHint),
            prefixIcon:
                icon != null ? Icon(icon, size: 18, color: _textHint) : null,
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _green, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _red, width: 1)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ]);

  Widget _dropdownRow(String label, List<String> items, String value,
          void Function(String) onChanged) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w500, color: _textSec)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : null,
          hint: Text(AppStrings.of(context).tr('Selectionner...', 'Select...'),
              style: GoogleFonts.dmSans(color: _textHint, fontSize: 13)),
          decoration: InputDecoration(
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _green, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: items
              .map((i) => DropdownMenuItem(
                  value: i,
                  child: Text(i, style: GoogleFonts.dmSans(fontSize: 13))))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ]);

  Widget _averageCard() {
    if (_grades.isEmpty) return const SizedBox.shrink();
    double weightedSum = 0;
    int totalCredits = 0;
    for (final g in _grades) {
      weightedSum += g.grade * g.credits;
      totalCredits += g.credits;
    }
    final avg = totalCredits > 0 ? weightedSum / totalCredits : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _greenLight, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.calculate_rounded, color: _green, size: 16),
        const SizedBox(width: 8),
        Text(
            AppStrings.of(context)
                .tr('Moyenne ponderee : ', 'Weighted average: '),
            style: GoogleFonts.dmSans(fontSize: 12, color: _green)),
        Text('${avg.toStringAsFixed(2)} / 20',
            style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w700, color: _green)),
        const SizedBox(width: 8),
        Text(
            '($totalCredits ${AppStrings.of(context).tr('credits', 'credits')})',
            style: GoogleFonts.dmSans(
                fontSize: 11, color: _green.withOpacity(0.7))),
      ]),
    );
  }
}

// ─── Grade row widget ─────────────────────────────────────────────────────────
class _GradeRowWidget extends StatefulWidget {
  final int index;
  final _GradeRow row;
  final List<String> semesters;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _GradeRowWidget(
      {required this.index,
      required this.row,
      required this.semesters,
      required this.onRemove,
      required this.onChanged});
  @override
  State<_GradeRowWidget> createState() => _GradeRowWidgetState();
}

class _GradeRowWidgetState extends State<_GradeRowWidget> {
  late final _codeCtrl = TextEditingController(text: widget.row.code);
  late final _nameCtrl = TextEditingController(text: widget.row.name);
  late final _gradeCtrl = TextEditingController(
      text: widget.row.grade > 0 ? widget.row.grade.toString() : '');
  late final _credCtrl =
      TextEditingController(text: widget.row.credits.toString());

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _gradeCtrl.dispose();
    _credCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0DDD5))),
        child: Column(children: [
          Row(children: [
            Text(
                '${AppStrings.of(context).tr('Cours', 'Course')} ${widget.index + 1}',
                style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B6B6B))),
            const Spacer(),
            GestureDetector(
                onTap: widget.onRemove,
                child: const Icon(Icons.close_rounded,
                    size: 16, color: Color(0xFFAAAAAA))),
          ]),
          const SizedBox(height: 8),
          // Row 1: code + name
          Row(children: [
            SizedBox(
                width: 80,
                child: TextField(
                    controller: _codeCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration:
                        _mini(AppStrings.of(context).tr('Code', 'Code')),
                    onChanged: (v) {
                      widget.row.code = v;
                      widget.onChanged();
                    })),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: _mini(AppStrings.of(context)
                        .tr('Nom du cours', 'Course name')),
                    onChanged: (v) {
                      widget.row.name = v;
                      widget.onChanged();
                    })),
          ]),
          const SizedBox(height: 8),
          // Row 2: grade + credits + semester
          Row(children: [
            SizedBox(
                width: 72,
                child: TextField(
                    controller: _gradeCtrl,
                    style: const TextStyle(fontSize: 12),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _mini(
                        AppStrings.of(context).tr('Note /20', 'Grade /20')),
                    onChanged: (v) {
                      widget.row.grade = double.tryParse(v) ?? 0;
                      widget.onChanged();
                    })),
            const SizedBox(width: 8),
            SizedBox(
                width: 64,
                child: TextField(
                    controller: _credCtrl,
                    style: const TextStyle(fontSize: 12),
                    keyboardType: TextInputType.number,
                    decoration:
                        _mini(AppStrings.of(context).tr('Credits', 'Credits')),
                    onChanged: (v) {
                      widget.row.credits = int.tryParse(v) ?? 3;
                      widget.onChanged();
                    })),
            const SizedBox(width: 8),
            Expanded(
                child: DropdownButtonFormField<String>(
                    initialValue: widget.semesters.contains(widget.row.semester)
                        ? widget.row.semester
                        : 'S1',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)),
                    decoration: _mini(
                        AppStrings.of(context).tr('Semestre', 'Semester')),
                    items: widget.semesters
                        .map((s) => DropdownMenuItem(
                            value: s,
                            child:
                                Text(s, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        widget.row.semester = v;
                        widget.onChanged();
                      }
                    })),
          ]),
        ]),
      );

  InputDecoration _mini(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
        filled: true,
        fillColor: const Color(0xFFF7F6F2),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE0DDD5))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE0DDD5))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF0F6E56), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      );
}
