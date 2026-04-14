// ═══════════════════════════════════════════════════════════════════════════
// INPUT METHOD 5 — Template Fill
// University chooses a pre-defined document template.
// Only student-specific fields need to be entered.
// All structural fields are pre-filled from the template.
// ═══════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_strings.dart';

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _coral = Color(0xFF993C1D);
const _coralLight = Color(0xFFFAECE7);
const _blue = Color(0xFF185FA5);
const _blueLight = Color(0xFFE6F1FB);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);
const _textHint = Color(0xFFAAAAAA);
const _red = Color(0xFFA32D2D);

// ─── Template definitions ─────────────────────────────────────────────────────
class DocumentTemplate {
  final String id;
  final String name;
  final String description;
  final String docType;
  final String degree;
  final String field;
  final String titleTemplate; // {student_name} will be replaced
  final List<String> preFilledCourses;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const DocumentTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.docType,
    required this.degree,
    required this.field,
    required this.titleTemplate,
    required this.preFilledCourses,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

const _templates = [
  DocumentTemplate(
    id: 'bsc_software_eng',
    name: 'BSc Software Engineering',
    description: 'Bachelor in Software Engineering & Cybersecurity',
    docType: 'diploma',
    degree: 'Licence (Bachelor)',
    field: 'Software Engineering & Cybersecurity',
    titleTemplate: 'Licence en Génie Logiciel et Cybersécurité',
    preFilledCourses: [
      'INF301,Algorithms & Data Structures,S5',
      'INF302,Object-Oriented Programming,S5',
      'INF303,Database Systems,S5',
      'INF304,Computer Networks,S5',
      'INF305,Software Engineering,S6',
      'INF306,Cybersecurity Fundamentals,S6',
      'INF307,Mobile Development,S6',
      'INF308,Cloud Computing,S6',
    ],
    icon: Icons.computer_rounded,
    color: _green,
    bgColor: _greenLight,
  ),
  DocumentTemplate(
    id: 'transcript_standard',
    name: 'Official Transcript',
    description: 'Standard academic transcript for all programmes',
    docType: 'transcript',
    degree: 'Licence (Bachelor)',
    field: '',
    titleTemplate: 'Relevé de Notes Officiel',
    preFilledCourses: [],
    icon: Icons.description_rounded,
    color: _blue,
    bgColor: _blueLight,
  ),
  DocumentTemplate(
    id: 'attestation_inscription',
    name: 'Attestation d\'inscription',
    description: 'Certificate confirming student enrolment',
    docType: 'attestation',
    degree: '',
    field: '',
    titleTemplate: 'Attestation d\'Inscription',
    preFilledCourses: [],
    icon: Icons.assignment_rounded,
    color: _coral,
    bgColor: _coralLight,
  ),
  DocumentTemplate(
    id: 'certificate_completion',
    name: 'Certificate of Completion',
    description: 'Certificate confirming programme completion',
    docType: 'certificate',
    degree: '',
    field: '',
    titleTemplate: 'Certificat de Réussite',
    preFilledCourses: [],
    icon: Icons.verified_rounded,
    color: Color(0xFF534AB7),
    bgColor: Color(0xFFEEEDFE),
  ),
  DocumentTemplate(
    id: 'bsc_networks',
    name: 'BSc Networks & Telecom',
    description: 'Bachelor in Networks & Telecommunications',
    docType: 'diploma',
    degree: 'Licence (Bachelor)',
    field: 'Networks & Telecommunications',
    titleTemplate: 'Licence en Réseaux et Télécommunications',
    preFilledCourses: [
      'NET301,Computer Networks I,S5',
      'NET302,Routing & Switching,S5',
      'NET303,Network Security,S5',
      'NET304,Wireless Communications,S6',
      'NET305,VoIP Systems,S6',
      'NET306,Network Administration,S6',
    ],
    icon: Icons.wifi_rounded,
    color: Color(0xFF854F0B),
    bgColor: Color(0xFFFAEEDA),
  ),
  DocumentTemplate(
    id: 'bsc_data_science',
    name: 'BSc Data Science & AI',
    description: 'Bachelor in Data Science and Artificial Intelligence',
    docType: 'diploma',
    degree: 'Licence (Bachelor)',
    field: 'Data Science & Artificial Intelligence',
    titleTemplate:
        'Licence en Science des Données et Intelligence Artificielle',
    preFilledCourses: [
      'DS301,Statistics & Probability,S5',
      'DS302,Machine Learning,S5',
      'DS303,Data Engineering,S5',
      'DS304,Deep Learning,S6',
      'DS305,Big Data Processing,S6',
      'DS306,Data Visualization,S6',
    ],
    icon: Icons.analytics_rounded,
    color: Color(0xFF185FA5),
    bgColor: Color(0xFFE6F1FB),
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class TemplateFillScreen extends ConsumerStatefulWidget {
  const TemplateFillScreen({super.key});
  @override
  ConsumerState<TemplateFillScreen> createState() => _TemplateState();
}

enum _TplPhase { selectTemplate, fillFields, issuing, done }

class _TemplateState extends ConsumerState<TemplateFillScreen> {
  _TplPhase _phase = _TplPhase.selectTemplate;
  DocumentTemplate? _selected;
  String? _issuedDocId;
  String? _error;

  final _matCtrl = TextEditingController();
  final _mentionCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _fieldCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  // Per-course grade controllers (for diploma templates with pre-filled courses)
  final List<TextEditingController> _gradeCtrl = [];
  final List<TextEditingController> _creditCtrl = [];

  @override
  void dispose() {
    _matCtrl.dispose();
    _mentionCtrl.dispose();
    _dateCtrl.dispose();
    _fieldCtrl.dispose();
    _titleCtrl.dispose();
    for (final c in _gradeCtrl) {
      c.dispose();
    }
    for (final c in _creditCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectTemplate(DocumentTemplate tpl) {
    // Prepare grade controllers for pre-filled courses
    _gradeCtrl.clear();
    _creditCtrl.clear();
    for (var _ in tpl.preFilledCourses) {
      _gradeCtrl.add(TextEditingController());
      _creditCtrl.add(TextEditingController(text: '3'));
    }
    _titleCtrl.text = tpl.titleTemplate;
    _fieldCtrl.text = tpl.field;
    _mentionCtrl.text = 'Bien';
    setState(() {
      _selected = tpl;
      _phase = _TplPhase.fillFields;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.light(primary: _green)),
            child: child!));
    if (picked != null) {
      setState(() => _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _issue() async {
    if (_matCtrl.text.trim().isEmpty) {
      setState(() => _error = AppStrings.of(context)
          .tr('Le matricule est requis', 'Student matricule is required'));
      return;
    }
    if (_dateCtrl.text.trim().isEmpty) {
      setState(() => _error = AppStrings.of(context)
          .tr('La date d\'emission est requise', 'Issue date is required'));
      return;
    }

    setState(() {
      _phase = _TplPhase.issuing;
      _error = null;
    });

    // Build courses from template + entered grades
    final courses = <Map>[];
    final tpl = _selected!;
    for (var i = 0; i < tpl.preFilledCourses.length; i++) {
      final parts = tpl.preFilledCourses[i].split(',');
      courses.add({
        'code': parts[0],
        'name': parts[1],
        'grade': double.tryParse(_gradeCtrl[i].text) ?? 10.0,
        'credits': int.tryParse(_creditCtrl[i].text) ?? 3,
        'semester': parts[2],
      });
    }

    try {
      final dio = Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('API_BASE_URL',
              defaultValue: 'https://diplomax-backend.onrender.com/v1')));

      final r = await dio.post('/documents/issue', data: {
        'student_matricule': _matCtrl.text.trim().toUpperCase(),
        'document_type': tpl.docType,
        'title': _titleCtrl.text.trim(),
        'degree': tpl.degree,
        'field': _fieldCtrl.text.trim(),
        'mention': _mentionCtrl.text.trim(),
        'issue_date': _dateCtrl.text.trim(),
        'courses': courses,
      });

      setState(() {
        _issuedDocId = r.data['document_id'] as String?;
        _phase = _TplPhase.done;
      });
    } on DioException catch (e) {
      setState(() {
        _error = (e.response?.data as Map?)?['detail']?.toString() ??
            AppStrings.of(context)
                .tr('Echec de l\'emission', 'Issuance failed');
        _phase = _TplPhase.fillFields;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: BackButton(
            color: _textPri,
            onPressed: () {
              if (_phase == _TplPhase.fillFields) {
                setState(() => _phase = _TplPhase.selectTemplate);
              } else {
                context.go('/issue');
              }
            }),
        title: Text(
            _phase == _TplPhase.selectTemplate
                ? AppStrings.of(context)
                    .tr('Choisir un modele', 'Choose a template')
                : AppStrings.of(context)
                    .tr('Remplir le modele', 'Fill template'),
            style: GoogleFonts.instrumentSerif(fontSize: 20, color: _textPri)),
      ),
      body: Padding(padding: const EdgeInsets.all(20), child: _buildBody()));

  Widget _buildBody() {
    switch (_phase) {
      case _TplPhase.selectTemplate:
        return _selectView();
      case _TplPhase.fillFields:
        return _fillView();
      case _TplPhase.issuing:
        return const Center(child: CircularProgressIndicator(color: _green));
      case _TplPhase.done:
        return _doneView();
    }
  }

  Widget _selectView() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            AppStrings.of(context).tr(
                'Choisissez un modele pour pre-remplir tous les champs standards.',
                'Choose a template to pre-fill all standard fields.'),
            style: GoogleFonts.dmSans(
                fontSize: 13, color: _textSec, fontWeight: FontWeight.w300)),
        const SizedBox(height: 16),
        Expanded(
            child: ListView(
                children: _templates
                    .map((t) => GestureDetector(
                        onTap: () => _selectTemplate(t),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _border),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2))
                              ]),
                          child: Row(children: [
                            Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    color: t.bgColor,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Icon(t.icon, color: t.color, size: 24)),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(t.name,
                                      style: GoogleFonts.dmSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                  Text(t.description,
                                      style: GoogleFonts.dmSans(
                                          fontSize: 11,
                                          color: _textSec,
                                          fontWeight: FontWeight.w300)),
                                  if (t.preFilledCourses.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                        AppStrings.of(context).tr(
                                            '${t.preFilledCourses.length} cours precharges',
                                            '${t.preFilledCourses.length} courses pre-loaded'),
                                        style: GoogleFonts.dmSans(
                                            fontSize: 10, color: t.color)),
                                  ],
                                ])),
                            Icon(Icons.chevron_right_rounded,
                                color: _textSec.withOpacity(0.4), size: 20),
                          ]),
                        )))
                    .toList())),
      ]);

  Widget _fillView() {
    final tpl = _selected!;
    return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Template badge
      Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: tpl.bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tpl.color.withOpacity(0.2))),
          child: Row(children: [
            Icon(tpl.icon, color: tpl.color, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(tpl.name,
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: tpl.color))),
            GestureDetector(
                onTap: () => setState(() => _phase = _TplPhase.selectTemplate),
                child: Text(AppStrings.of(context).tr('Changer', 'Change'),
                    style: GoogleFonts.dmSans(color: tpl.color, fontSize: 12))),
          ])),
      const SizedBox(height: 16),

      // Student-specific fields
      _sectionHeader(AppStrings.of(context)
          .tr('Informations etudiant', 'Student information')),
      _tf(_matCtrl, AppStrings.of(context).tr('Matricule *', 'Matricule *'),
          'ICTU20223180', Icons.badge_rounded),
      const SizedBox(height: 10),
      _tf(
          _dateCtrl,
          AppStrings.of(context).tr('Date d\'emission *', 'Issue date *'),
          AppStrings.of(context).tr('Touchez pour choisir', 'Tap to pick'),
          Icons.calendar_today_rounded,
          readOnly: true,
          onTap: _pickDate),
      const SizedBox(height: 10),
      _mentionDropdown(),
      const SizedBox(height: 16),

      // Pre-filled fields (editable)
      _sectionHeader(AppStrings.of(context).tr(
          'Details du document (pre-remplis, modifiables)',
          'Document details (pre-filled, editable)')),
      _tf(_titleCtrl, AppStrings.of(context).tr('Titre', 'Title'),
          tpl.titleTemplate, Icons.title_rounded),
      const SizedBox(height: 10),
      _tf(
          _fieldCtrl,
          AppStrings.of(context).tr('Domaine d\'etude', 'Field of study'),
          tpl.field,
          Icons.school_rounded),
      const SizedBox(height: 16),

      // Course grades (if diploma)
      if (tpl.preFilledCourses.isNotEmpty) ...[
        _sectionHeader(
            AppStrings.of(context).tr('Saisir les notes', 'Enter grades')),
        const SizedBox(height: 8),
        ...tpl.preFilledCourses.asMap().entries.map((e) {
          final parts = e.value.split(',');
          return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border)),
              child: Row(children: [
                Container(
                    width: 50,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: tpl.bgColor,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(parts[0],
                        style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: tpl.color,
                            fontWeight: FontWeight.w500))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(parts[1],
                        style: GoogleFonts.dmSans(fontSize: 12))),
                const SizedBox(width: 8),
                SizedBox(
                    width: 72,
                    child: TextField(
                        controller: _gradeCtrl[e.key],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                            hintText: '/20',
                            hintStyle: const TextStyle(
                                fontSize: 11, color: Color(0xFFAAAAAA)),
                            filled: true,
                            fillColor: const Color(0xFFF7F6F2),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE0DDD5))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE0DDD5))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: _green, width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            isDense: true))),
              ]));
        }),
        const SizedBox(height: 8),
      ],

      if (_error != null) ...[
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFFCEBEB),
                borderRadius: BorderRadius.circular(8)),
            child: Text(_error!,
                style: GoogleFonts.dmSans(color: _red, fontSize: 12))),
        const SizedBox(height: 10),
      ],

      ElevatedButton.icon(
          icon: const Icon(Icons.verified_rounded, size: 18),
          label: Text(AppStrings.of(context)
              .tr('Emettre depuis le modele', 'Issue from template')),
          style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0),
          onPressed: _issue),
      const SizedBox(height: 20),
    ]));
  }

  Widget _doneView() => Center(
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
            AppStrings.of(context).tr('Depuis le modele: ${_selected?.name}',
                'From template: ${_selected?.name}'),
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
            onPressed: () => context.go('/issue/sign/${_issuedDocId ?? ''}'),
            child: Text(AppStrings.of(context)
                .tr('Signer ce document', 'Sign this document'))),
        const SizedBox(height: 10),
        OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => context.go('/issue'),
            child: Text(AppStrings.of(context)
                .tr('Emettre un autre document', 'Issue another document'))),
      ]));

  Widget _sectionHeader(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t,
          style: GoogleFonts.dmSans(
              fontSize: 13, fontWeight: FontWeight.w500, color: _textPri)));

  Widget _mentionDropdown() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppStrings.of(context).tr('Mention', 'Mention'),
            style: GoogleFonts.dmSans(
                fontSize: 11, fontWeight: FontWeight.w500, color: _textSec)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
            initialValue: _mentionCtrl.text,
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
                isDense: true),
            items: ['Très Bien', 'Bien', 'Assez Bien', 'Passable']
                .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m, style: GoogleFonts.dmSans(fontSize: 13))))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _mentionCtrl.text = v);
            }),
      ]);

  Widget _tf(TextEditingController c, String label, String hint, IconData icon,
          {bool readOnly = false, VoidCallback? onTap}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 11, fontWeight: FontWeight.w500, color: _textSec)),
        const SizedBox(height: 4),
        TextField(
            controller: c,
            readOnly: readOnly,
            onTap: onTap,
            style: GoogleFonts.dmSans(fontSize: 13),
            decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.dmSans(fontSize: 12, color: _textHint),
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
                    borderSide: const BorderSide(color: _green, width: 1.5)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true)),
      ]);
}
