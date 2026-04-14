// ═══════════════════════════════════════════════════════════════════════════
// DIPLOMAX CM — Institution Onboarding Flow
// Used by any institution connecting to Diplomax for the first time.
// Routes through 5 steps:
//   Step 1: Institution type selection
//   Step 2: Institution details
//   Step 3: Accreditation information
//   Step 4: Admin contact
//   Step 5: Review and submit
// ═══════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../l10n/app_strings.dart';

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
const _red = Color(0xFFA32D2D);

// ─── Institution types ────────────────────────────────────────────────────────

class _InstType {
  final String id;
  final String label;
  final String labelFr;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final List<String> allowedDocs;
  const _InstType({
    required this.id,
    required this.label,
    required this.labelFr,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.allowedDocs,
  });
}

const _instTypes = [
  _InstType(
    id: 'university',
    label: 'University',
    labelFr: 'Université',
    description: 'Public or private university accredited by MINESUP',
    icon: Icons.account_balance_rounded,
    color: _green,
    bgColor: _greenLight,
    allowedDocs: ['diploma', 'transcript', 'certificate', 'attestation'],
  ),
  _InstType(
    id: 'grande_ecole',
    label: 'Grande École',
    labelFr: 'Grande École',
    description: 'ENSP, ENSPT, ENAM, IRIC and similar',
    icon: Icons.school_rounded,
    color: _blue,
    bgColor: _blueLight,
    allowedDocs: ['diploma', 'transcript', 'certificate', 'attestation'],
  ),
  _InstType(
    id: 'training_centre',
    label: 'Training Centre',
    labelFr: 'Centre de formation',
    description: 'Professional skills training, MINEFOP-accredited',
    icon: Icons.precision_manufacturing_rounded,
    color: _amber,
    bgColor: _amberLight,
    allowedDocs: ['certificate', 'attestation'],
  ),
  _InstType(
    id: 'professional_school',
    label: 'Professional School',
    labelFr: 'École professionnelle',
    description: 'Nursing, midwifery, allied health, law schools',
    icon: Icons.local_hospital_rounded,
    color: Color(0xFF993C1D),
    bgColor: Color(0xFFFAECE7),
    allowedDocs: ['diploma', 'certificate', 'attestation'],
  ),
  _InstType(
    id: 'language_institute',
    label: 'Language Institute',
    labelFr: 'Institut de langues',
    description: 'French, English, German, Chinese language schools',
    icon: Icons.translate_rounded,
    color: Color(0xFF534AB7),
    bgColor: Color(0xFFEEEDFE),
    allowedDocs: ['certificate', 'attestation'],
  ),
  _InstType(
    id: 'tvet_centre',
    label: 'TVET Centre',
    labelFr: 'Centre TVET',
    description: 'Technical and Vocational Education and Training',
    icon: Icons.construction_rounded,
    color: Color(0xFF185FA5),
    bgColor: Color(0xFFE6F1FB),
    allowedDocs: ['certificate', 'attestation', 'diploma'],
  ),
  _InstType(
    id: 'online_platform',
    label: 'Online Platform',
    labelFr: 'Plateforme en ligne',
    description: 'E-learning, MOOCs, remote learning programmes',
    icon: Icons.computer_rounded,
    color: Color(0xFF0F6E56),
    bgColor: Color(0xFFE1F5EE),
    allowedDocs: ['certificate', 'attestation'],
  ),
  _InstType(
    id: 'corporate_training',
    label: 'Corporate Training',
    labelFr: 'Formation entreprise',
    description: 'In-house company training and upskilling programmes',
    icon: Icons.business_rounded,
    color: Color(0xFF6B6B6B),
    bgColor: Color(0xFFF1EFE8),
    allowedDocs: ['certificate', 'attestation'],
  ),
];

// ─── Onboarding data ──────────────────────────────────────────────────────────

class _OnboardingData {
  // Step 1
  String institutionType = '';
  // Step 2
  String name = '';
  String shortName = '';
  String acronym = '';
  String description = '';
  String foundedYear = '';
  String city = '';
  String region = '';
  String country = 'Cameroon';
  String address = '';
  String website = '';
  String email = '';
  String phone = '';
  String whatsapp = '';
  // Step 3
  String accreditationBody = '';
  String accreditationNumber = '';
  bool isGovernment = false;
  String matriculePrefix = '';
  // Step 4
  String adminFullName = '';
  String adminEmail = '';
  String adminPhone = '';
  String adminTitle = '';
  String adminPassword = '';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class InstitutionOnboardingScreen extends ConsumerStatefulWidget {
  const InstitutionOnboardingScreen({super.key});
  @override
  ConsumerState<InstitutionOnboardingScreen> createState() =>
      _OnboardingState();
}

class _OnboardingState extends ConsumerState<InstitutionOnboardingScreen> {
  int _step = 0;
  final _data = _OnboardingData();
  bool _loading = false;
  bool _done = false;
  String? _registrationId;
  String? _error;

  final _pageCtrl = PageController();

  static const _steps = [
    'Institution type',
    'Basic details',
    'Accreditation',
    'Admin contact',
    'Review & submit',
  ];

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() {
        _step++;
        _error = null;
      });
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() {
        _step--;
        _error = null;
      });
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('API_BASE_URL',
              defaultValue: 'https://diplomax-backend.onrender.com/v1')));
      final r = await dio.post('/institutions/register', data: {
        'institution_type': _data.institutionType,
        'name': _data.name,
        'short_name': _data.shortName,
        'acronym': _data.acronym,
        'description': _data.description,
        'founded_year': _data.foundedYear,
        'city': _data.city,
        'region': _data.region,
        'country': _data.country,
        'address': _data.address,
        'website': _data.website,
        'email': _data.email,
        'phone': _data.phone,
        'whatsapp': _data.whatsapp,
        'accreditation_body': _data.accreditationBody,
        'accreditation_number': _data.accreditationNumber,
        'is_government': _data.isGovernment,
        'matricule_prefix': _data.matriculePrefix.toUpperCase(),
        'admin_full_name': _data.adminFullName,
        'admin_email': _data.adminEmail,
        'admin_phone': _data.adminPhone,
        'admin_title': _data.adminTitle,
        'admin_password': _data.adminPassword,
      });
      setState(() {
        _done = true;
        _registrationId = (r.data['reference'] as String?) ?? '';
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = (e.response?.data as Map?)?['detail']?.toString() ??
            'Submission failed. Please check all fields.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    if (_done) return _buildDone();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: BackButton(
            color: _textPri,
            onPressed: _step == 0 ? () => context.go('/login') : _back),
        title: Text(strings.tr('Rejoindre Diplomax CM', 'Join Diplomax CM'),
            style: GoogleFonts.instrumentSerif(fontSize: 20, color: _textPri)),
      ),
      body: Column(children: [
        _progressBar(),
        Expanded(
            child: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _Step1TypeSelect(data: _data, onNext: _next),
            _Step2Details(data: _data, onNext: _next),
            _Step3Accreditation(data: _data, onNext: _next),
            _Step4Admin(data: _data, onNext: _next),
            _Step5Review(
                data: _data,
                loading: _loading,
                error: _error,
                onSubmit: _submit),
          ],
        )),
      ]),
    );
  }

  Widget _progressBar() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: List.generate(
                _steps.length,
                (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    margin:
                        EdgeInsets.only(right: i < _steps.length - 1 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i <= _step ? _green : _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.of(context).tr(
                      'Etape ${_step + 1} sur ${_steps.length}',
                      'Step ${_step + 1} of ${_steps.length}'),
                  style: GoogleFonts.dmSans(fontSize: 11, color: _textSec),
                ),
                Text(
                  _stepLabel(_steps[_step], AppStrings.of(context)),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      );

  Widget _buildDone() => Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
          child: Center(
              child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            width: 90,
                            height: 90,
                            decoration: const BoxDecoration(
                                color: _greenLight, shape: BoxShape.circle),
                            child: const Icon(Icons.mark_email_read_rounded,
                                color: _green, size: 46)),
                        const SizedBox(height: 24),
                        Text(
                            AppStrings.of(context).tr(
                                'Demande soumise!', 'Application submitted!'),
                            style: GoogleFonts.instrumentSerif(
                                fontSize: 28, color: _textPri),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text(
                            AppStrings.of(context).tr(
                                'Votre inscription a ete recue.\nL\'equipe Diplomax l\'examinera sous 2 jours ouvrables\net vous contactera a ${_data.adminEmail}.',
                                'Your registration has been received.\nThe Diplomax team will review it within 2 business days\nand contact you at ${_data.adminEmail}.'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: _textSec,
                                height: 1.6,
                                fontWeight: FontWeight.w300)),
                        const SizedBox(height: 20),
                        Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: _greenLight,
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(children: [
                              _refRow(
                                  AppStrings.of(context)
                                      .tr('ID reference', 'Reference ID'),
                                  _registrationId?.toUpperCase() ?? '—'),
                              _refRow(
                                  AppStrings.of(context)
                                      .tr('Institution', 'Institution'),
                                  _data.name),
                              _refRow(
                                  AppStrings.of(context)
                                      .tr('Email contact', 'Contact email'),
                                  _data.adminEmail),
                              _refRow(
                                  AppStrings.of(context)
                                      .tr('Prochaine etape', 'Next step'),
                                  AppStrings.of(context).tr(
                                      'Verifiez votre email pour confirmation',
                                      'Check your email for confirmation')),
                            ])),
                        const SizedBox(height: 24),
                        Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: _amberLight,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: _amber.withOpacity(0.3))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      AppStrings.of(context).tr(
                                          'En attendant:', 'While you wait:'),
                                      style: GoogleFonts.dmSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _amber)),
                                  const SizedBox(height: 8),
                                  ...[
                                    AppStrings.of(context).tr(
                                        'Preparez votre certificat d\'accreditation MINESUP/MINEFOP',
                                        'Prepare your MINESUP/MINEFOP accreditation certificate'),
                                    AppStrings.of(context).tr(
                                        'Preparez le papier entete officiel de votre institution',
                                        'Have your institution\'s official letterhead ready'),
                                    AppStrings.of(context).tr(
                                        'Choisissez votre format de matricule (ex: ${_data.matriculePrefix.toUpperCase()}20241001)',
                                        'Decide on your matricule format (e.g. ${_data.matriculePrefix.toUpperCase()}20241001)'),
                                    AppStrings.of(context).tr(
                                        'Informez votre service de scolarite du flux Diplomax',
                                        'Brief your registrar on the Diplomax workflow'),
                                  ].map((s) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(children: [
                                        const Icon(Icons.check_box_rounded,
                                            color: _amber, size: 14),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(s,
                                                style: GoogleFonts.dmSans(
                                                    fontSize: 11,
                                                    color: _amber))),
                                      ]))),
                                ])),
                        const SizedBox(height: 24),
                        TextButton(
                            onPressed: () => context.go('/login'),
                            child: Text(
                                AppStrings.of(context).tr(
                                    'Retour a la connexion', 'Back to login'),
                                style: GoogleFonts.dmSans(
                                    color: _textSec, fontSize: 13))),
                      ])))));

  String _stepLabel(String step, AppStrings strings) {
    switch (step) {
      case 'Institution type':
        return strings.tr('Type d\'institution', 'Institution type');
      case 'Basic details':
        return strings.tr('Informations de base', 'Basic details');
      case 'Accreditation':
        return strings.tr('Accreditation', 'Accreditation');
      case 'Admin contact':
        return strings.tr('Contact administrateur', 'Admin contact');
      case 'Review & submit':
        return strings.tr('Verifier et soumettre', 'Review & submit');
      default:
        return step;
    }
  }

  Widget _refRow(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: GoogleFonts.dmSans(fontSize: 11, color: _textSec)),
        Flexible(
            child: Text(v,
                style: GoogleFonts.dmSans(
                    fontSize: 11, fontWeight: FontWeight.w500),
                textAlign: TextAlign.end)),
      ]));
}

// ─── STEP 1 — Institution Type ────────────────────────────────────────────────

class _Step1TypeSelect extends StatefulWidget {
  final _OnboardingData data;
  final VoidCallback onNext;
  const _Step1TypeSelect({required this.data, required this.onNext});
  @override
  State<_Step1TypeSelect> createState() => _Step1State();
}

class _Step1State extends State<_Step1TypeSelect> {
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            AppStrings.of(context).tr('Quel type d\'institution etes-vous?',
                'What type of institution are you?'),
            style: GoogleFonts.instrumentSerif(fontSize: 22, color: _textPri)),
        const SizedBox(height: 6),
        Text(
            AppStrings.of(context).tr(
                'Cela determine les types de documents que vous pouvez emettre.',
                'This determines which document types you can issue.'),
            style: GoogleFonts.dmSans(
                fontSize: 13, color: _textSec, fontWeight: FontWeight.w300)),
        const SizedBox(height: 20),
        ..._instTypes.map((t) {
          final selected = widget.data.institutionType == t.id;
          return GestureDetector(
              onTap: () => setState(() => widget.data.institutionType = t.id),
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: selected ? t.bgColor : _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: selected ? t.color : _border,
                          width: selected ? 2 : 0.5)),
                  child: Row(children: [
                    Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: selected
                                ? t.color.withOpacity(0.15)
                                : const Color(0xFFF1EFE8),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(t.icon,
                            color: selected ? t.color : _textHint, size: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            Text(t.label,
                                style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: selected ? t.color : _textPri)),
                            const SizedBox(width: 6),
                            Text('(${t.labelFr})',
                                style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: selected
                                        ? t.color.withOpacity(0.7)
                                        : _textSec)),
                          ]),
                          const SizedBox(height: 3),
                          Text(t.description,
                              style: GoogleFonts.dmSans(
                                  fontSize: 11, color: _textSec, height: 1.4)),
                          const SizedBox(height: 4),
                          Text(
                              AppStrings.of(context).tr(
                                  'Docs: ${t.allowedDocs.join(' · ')}',
                                  'Docs: ${t.allowedDocs.join(' · ')}'),
                              style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: selected ? t.color : _textHint,
                                  fontWeight: FontWeight.w500)),
                        ])),
                    if (selected)
                      Icon(Icons.check_circle_rounded,
                          color: t.color, size: 20),
                  ])));
        }),
        const SizedBox(height: 20),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed:
                widget.data.institutionType.isEmpty ? null : widget.onNext,
            child: Text(AppStrings.of(context).tr('Continuer', 'Continue'))),
      ]));
}

// ─── STEP 2 — Basic Details ───────────────────────────────────────────────────

class _Step2Details extends StatelessWidget {
  final _OnboardingData data;
  final VoidCallback onNext;
  const _Step2Details({required this.data, required this.onNext});

  static final _cameroonRegions = [
    'Centre',
    'Littoral',
    'Ouest',
    'Sud-Ouest',
    'Nord-Ouest',
    'Adamaoua',
    'Nord',
    'Extrême-Nord',
    'Est',
    'Sud',
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            AppStrings.of(context).tr('Parlez-nous de votre institution',
                'Tell us about your institution'),
            style: GoogleFonts.instrumentSerif(fontSize: 22, color: _textPri)),
        const SizedBox(height: 20),
        _tf(
            AppStrings.of(context).tr(
                'Nom complet de l\'institution *', 'Full institution name *'),
            (v) => data.name = v,
            hint: AppStrings.of(context)
                .tr('ex: The ICT University', 'e.g. The ICT University')),
        _tf(AppStrings.of(context).tr('Nom court', 'Short name'),
            (v) => data.shortName = v,
            hint: AppStrings.of(context)
                .tr('ex: ICT University', 'e.g. ICT University')),
        _tf(AppStrings.of(context).tr('Acronyme', 'Acronym'),
            (v) => data.acronym = v,
            hint: AppStrings.of(context)
                .tr('ex: ICTU, ENSP, UY1', 'e.g. ICTU, ENSP, UY1')),
        _tf(AppStrings.of(context).tr('Description breve', 'Brief description'),
            (v) => data.description = v,
            hint: AppStrings.of(context).tr('Une phrase sur votre institution',
                'One sentence about your institution'),
            maxLines: 2),
        _tf(AppStrings.of(context).tr('Annee de creation', 'Founded year'),
            (v) => data.foundedYear = v,
            hint: AppStrings.of(context).tr('ex: 2005', 'e.g. 2005'),
            keyboardType: TextInputType.number),
        _divider(AppStrings.of(context).tr('Localisation', 'Location')),
        _tf(AppStrings.of(context).tr('Ville *', 'City *'),
            (v) => data.city = v,
            hint: AppStrings.of(context).tr('ex: Yaounde, Douala, Bafoussam',
                'e.g. Yaounde, Douala, Bafoussam')),
        _regionDropdown(context),
        _tf(AppStrings.of(context).tr('Adresse', 'Address'),
            (v) => data.address = v,
            hint: AppStrings.of(context)
                .tr('Adresse et quartier', 'Street address, neighbourhood')),
        _divider(AppStrings.of(context).tr('Contact', 'Contact')),
        _tf(AppStrings.of(context).tr('Email officiel *', 'Official email *'),
            (v) => data.email = v,
            hint: 'info@institution.cm',
            keyboardType: TextInputType.emailAddress),
        _tf(AppStrings.of(context).tr('Telephone *', 'Phone *'),
            (v) => data.phone = v,
            hint: '+237 6XX XXX XXX', keyboardType: TextInputType.phone),
        _tf(AppStrings.of(context).tr('WhatsApp', 'WhatsApp'),
            (v) => data.whatsapp = v,
            hint: '+237 6XX XXX XXX', keyboardType: TextInputType.phone),
        _tf(AppStrings.of(context).tr('Site web', 'Website'),
            (v) => data.website = v,
            hint: 'https://www.institution.cm',
            keyboardType: TextInputType.url),
        const SizedBox(height: 20),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed: data.name.trim().isEmpty || data.city.trim().isEmpty
                ? null
                : onNext,
            child: Text(AppStrings.of(context).tr('Continuer', 'Continue'))),
      ]));

  Widget _regionDropdown(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppStrings.of(context).tr('Region', 'Region'),
            style: GoogleFonts.dmSans(
                fontSize: 11, fontWeight: FontWeight.w500, color: _textSec)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
            hint: Text(
                AppStrings.of(context)
                    .tr('Selectionner une region', 'Select region'),
                style: GoogleFonts.dmSans(color: _textHint, fontSize: 13)),
            decoration: _inputDec(),
            items: _cameroonRegions
                .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r, style: GoogleFonts.dmSans(fontSize: 13))))
                .toList(),
            onChanged: (v) {
              if (v != null) data.region = v;
            }),
      ]));

  Widget _tf(String label, void Function(String) onChanged,
          {String? hint, int maxLines = 1, TextInputType? keyboardType}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _textSec)),
            const SizedBox(height: 4),
            TextField(
                maxLines: maxLines,
                keyboardType: keyboardType,
                onChanged: onChanged,
                style: GoogleFonts.dmSans(fontSize: 13),
                decoration: _inputDec(hint: hint)),
          ]));

  Widget _divider(String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w500, color: _green)),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: Color(0xFFE0DDD5))),
      ]));

  InputDecoration _inputDec({String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(fontSize: 12, color: _textHint),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true);
}

// ─── STEP 3 — Accreditation ───────────────────────────────────────────────────

class _Step3Accreditation extends StatefulWidget {
  final _OnboardingData data;
  final VoidCallback onNext;
  const _Step3Accreditation({required this.data, required this.onNext});
  @override
  State<_Step3Accreditation> createState() => _Step3State();
}

class _Step3State extends State<_Step3Accreditation> {
  static const _accreditationBodies = [
    'MINESUP (Ministère de l\'Enseignement Supérieur)',
    'MINEFOP (Ministère de l\'Emploi et de la Formation Professionnelle)',
    'MINESEC (Ministère des Enseignements Secondaires)',
    'MINSANTE (Ministère de la Santé) — for health schools',
    'GCE Board',
    'Other (specify)',
    'Not yet accredited',
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            AppStrings.of(context).tr('Accreditation et identification',
                'Accreditation & identification'),
            style: GoogleFonts.instrumentSerif(fontSize: 22, color: _textPri)),
        const SizedBox(height: 6),
        Text(
            AppStrings.of(context).tr(
                'Ces informations servent a verifier votre institution et a la relier au registre national de l\'education.',
                'This information is used to verify your institution and link it to the national education registry.'),
            style:
                GoogleFonts.dmSans(fontSize: 12, color: _textSec, height: 1.5)),
        const SizedBox(height: 16),
        _label(AppStrings.of(context)
            .tr('Organisme d\'accreditation *', 'Accreditation body *')),
        DropdownButtonFormField<String>(
            hint: Text(
                AppStrings.of(context).tr('Selectionner...', 'Select...'),
                style: GoogleFonts.dmSans(color: _textHint, fontSize: 13)),
            decoration: _inputDec(),
            items: _accreditationBodies
                .map((b) => DropdownMenuItem(
                    value: b,
                    child: Text(b,
                        style: GoogleFonts.dmSans(fontSize: 12),
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) {
              if (v != null) widget.data.accreditationBody = v;
            }),
        const SizedBox(height: 12),
        _tf(
            AppStrings.of(context).tr('Numero d\'accreditation / licence',
                'Accreditation / licence number'),
            (v) => widget.data.accreditationNumber = v,
            hint: AppStrings.of(context).tr(
                'Votre numero officiel d\'enregistrement',
                'Your official registration number')),
        const SizedBox(height: 8),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border)),
            child: Row(children: [
              const Icon(Icons.account_balance_rounded,
                  size: 18, color: _textSec),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        AppStrings.of(context).tr(
                            'Institution publique?', 'Government institution?'),
                        style: GoogleFonts.dmSans(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(
                        AppStrings.of(context).tr(
                            'Universites publiques, ecoles nationales, centres de formation d\'Etat',
                            'Public universities, national schools, state training centres'),
                        style:
                            GoogleFonts.dmSans(fontSize: 11, color: _textSec)),
                  ])),
              Switch(
                  value: widget.data.isGovernment,
                  activeThumbColor: _green,
                  onChanged: (v) =>
                      setState(() => widget.data.isGovernment = v)),
            ])),
        const SizedBox(height: 20),
        _label(AppStrings.of(context)
            .tr('Prefixe matricule *', 'Matricule prefix *')),
        const SizedBox(height: 4),
        TextField(
            maxLength: 8,
            textCapitalization: TextCapitalization.characters,
            onChanged: (v) => widget.data.matriculePrefix = v.toUpperCase(),
            style: GoogleFonts.dmSans(fontSize: 14),
            decoration: _inputDec(
                hint: AppStrings.of(context)
                    .tr('ex: ICTU, ENSP, CFPR', 'e.g. ICTU, ENSP, CFPR'))),
        const SizedBox(height: 4),
        if (widget.data.matriculePrefix.isNotEmpty)
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _greenLight, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_rounded, color: _green, size: 14),
                const SizedBox(width: 8),
                Text(
                    '${AppStrings.of(context).tr('Exemple matricule: ', 'Example matricule: ')}'
                    '${widget.data.matriculePrefix.toUpperCase()}20241001',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: _green,
                    )),
              ])),
        const SizedBox(height: 20),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _amberLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _amber.withOpacity(0.2))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  AppStrings.of(context).tr(
                      'Documents a televerser apres approbation:',
                      'Documents you will need to upload after approval:'),
                  style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _amber)),
              const SizedBox(height: 6),
              ...[
                AppStrings.of(context).tr(
                    'Certificat officiel d\'accreditation du ministere',
                    'Official accreditation certificate from the ministry'),
                AppStrings.of(context).tr(
                    'Document d\'enregistrement ou statuts de l\'institution',
                    'Institution registration document or statutes'),
                AppStrings.of(context).tr(
                    'Papier entete officiel (pour le modele PDF)',
                    'Official letterhead (for the PDF template)'),
                AppStrings.of(context).tr('Logo (PNG, minimum 200x200px)',
                    'Logo (PNG, minimum 200x200px)'),
              ].map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(children: [
                    const Icon(Icons.circle, size: 5, color: _amber),
                    const SizedBox(width: 8),
                    Text(s,
                        style: GoogleFonts.dmSans(fontSize: 11, color: _amber)),
                  ]))),
            ])),
        const SizedBox(height: 20),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed:
                widget.data.matriculePrefix.isEmpty ? null : widget.onNext,
            child: Text(AppStrings.of(context).tr('Continuer', 'Continue'))),
      ]));

  Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(t,
          style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w500, color: _textSec)));

  Widget _tf(String label, void Function(String) onChanged, {String? hint}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        TextField(
            onChanged: onChanged,
            style: GoogleFonts.dmSans(fontSize: 13),
            decoration: _inputDec(hint: hint)),
        const SizedBox(height: 12),
      ]);

  InputDecoration _inputDec({String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(fontSize: 12, color: _textHint),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true);
}

// ─── STEP 4 — Admin Contact ───────────────────────────────────────────────────

class _Step4Admin extends StatelessWidget {
  final _OnboardingData data;
  final VoidCallback onNext;
  const _Step4Admin({required this.data, required this.onNext});

  static const _titles = [
    'Registrar',
    'Director',
    'Dean',
    'Head of Academics',
    'Administrative Director',
    'IT Manager',
    'Other',
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            AppStrings.of(context)
                .tr('Compte administrateur', 'Administrator account'),
            style: GoogleFonts.instrumentSerif(fontSize: 22, color: _textPri)),
        const SizedBox(height: 6),
        Text(
            AppStrings.of(context).tr(
                'Cette personne sera le premier administrateur de votre institution sur Diplomax. Elle pourra creer d\'autres comptes staff apres connexion.',
                'This person will be the first admin of your institution on Diplomax. They can create additional staff accounts after logging in.'),
            style:
                GoogleFonts.dmSans(fontSize: 12, color: _textSec, height: 1.5)),
        const SizedBox(height: 20),
        _tf(AppStrings.of(context).tr('Nom complet *', 'Full name *'),
            (v) => data.adminFullName = v,
            hint: AppStrings.of(context)
                .tr('ex: Jean-Paul Mbarga', 'e.g. Jean-Paul Mbarga')),
        _label(AppStrings.of(context).tr('Titre / role *', 'Title / Role *')),
        DropdownButtonFormField<String>(
            hint: Text(
                AppStrings.of(context)
                    .tr('Selectionnez votre role', 'Select your role'),
                style: GoogleFonts.dmSans(color: _textHint, fontSize: 13)),
            decoration: _inputDec(),
            items: _titles
                .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t, style: GoogleFonts.dmSans(fontSize: 13))))
                .toList(),
            onChanged: (v) {
              if (v != null) data.adminTitle = v;
            }),
        const SizedBox(height: 12),
        _tf(AppStrings.of(context).tr('Email professionnel *', 'Work email *'),
            (v) => data.adminEmail = v,
            hint: 'your.email@institution.cm',
            keyboardType: TextInputType.emailAddress),
        _tf(AppStrings.of(context).tr('Telephone *', 'Phone *'),
            (v) => data.adminPhone = v,
            hint: '+237 6XX XXX XXX', keyboardType: TextInputType.phone),
        _tf(
            AppStrings.of(context)
                .tr('Choisir un mot de passe *', 'Choose a password *'),
            (v) => data.adminPassword = v,
            hint: AppStrings.of(context)
                .tr('Minimum 8 caracteres', 'Minimum 8 characters'),
            obscure: true),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _greenLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _green.withOpacity(0.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.security_rounded, color: _green, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      AppStrings.of(context).tr(
                          'Votre mot de passe est chiffre avant stockage. L\'equipe Diplomax ne peut pas le voir. Vous pourrez le modifier apres votre premiere connexion.',
                          'Your password is encrypted before storage. Diplomax staff cannot see it. You can change it after your first login.'),
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: _green, height: 1.5))),
            ])),
        const SizedBox(height: 20),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed: data.adminFullName.isEmpty || data.adminEmail.isEmpty
                ? null
                : onNext,
            child: Text(AppStrings.of(context)
                .tr('Continuer vers la revision', 'Continue to review'))),
      ]));

  Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(t,
          style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w500, color: _textSec)));

  Widget _tf(String label, void Function(String) onChanged,
          {String? hint, TextInputType? keyboardType, bool obscure = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        TextField(
            obscureText: obscure,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: GoogleFonts.dmSans(fontSize: 13),
            decoration: _inputDec(hint: hint)),
        const SizedBox(height: 12),
      ]);

  InputDecoration _inputDec({String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(fontSize: 12, color: _textHint),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true);
}

// ─── STEP 5 — Review and Submit ───────────────────────────────────────────────

class _Step5Review extends StatelessWidget {
  final _OnboardingData data;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;
  const _Step5Review(
      {required this.data,
      required this.loading,
      required this.error,
      required this.onSubmit});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            AppStrings.of(context)
                .tr('Verifiez votre demande', 'Review your application'),
            style: GoogleFonts.instrumentSerif(fontSize: 22, color: _textPri)),
        const SizedBox(height: 6),
        Text(
            AppStrings.of(context).tr(
                'Verifiez toutes les informations avant de soumettre.',
                'Check all information before submitting.'),
            style: GoogleFonts.dmSans(fontSize: 12, color: _textSec)),
        const SizedBox(height: 20),
        _reviewSection('Institution', [
          ('Type', _typeLabel(data.institutionType)),
          ('Name', data.name),
          ('City', data.city),
          ('Country', data.country),
          ('Email', data.email),
          ('Phone', data.phone),
        ]),
        _reviewSection('Accreditation', [
          ('Accreditation body', data.accreditationBody),
          ('Licence number', data.accreditationNumber),
          ('Government institution', data.isGovernment ? 'Yes' : 'No'),
          ('Matricule prefix', data.matriculePrefix.toUpperCase()),
          (
            'Example matricule',
            '${data.matriculePrefix.toUpperCase()}20241001'
          ),
        ]),
        _reviewSection('Administrator', [
          ('Full name', data.adminFullName),
          ('Title', data.adminTitle),
          ('Email', data.adminEmail),
          ('Phone', data.adminPhone),
        ]),
        if (error != null) ...[
          const SizedBox(height: 8),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFCEBEB),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(error!,
                  style: GoogleFonts.dmSans(color: _red, fontSize: 12))),
        ],
        const SizedBox(height: 16),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _amberLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _amber.withOpacity(0.2))),
            child: Text(
                AppStrings.of(context).tr(
                    'En soumettant, vous confirmez que toutes les informations sont exactes et que votre institution est legalement autorisee a emettre des documents academiques. De fausses informations peuvent entrainer une suspension permanente.',
                    'By submitting, you confirm that all information is accurate and that your institution is legally permitted to issue academic documents. False information may result in permanent suspension.'),
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: _amber, height: 1.5))),
        const SizedBox(height: 20),
        ElevatedButton.icon(
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(loading
                ? AppStrings.of(context)
                    .tr('Soumission en cours...', 'Submitting...')
                : AppStrings.of(context)
                    .tr('Soumettre la demande', 'Submit application')),
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed: loading ? null : onSubmit),
      ]));

  Widget _reviewSection(String title, List<(String, String)> rows) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
                color: _greenLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
            child: Text(title,
                style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w500, color: _green))),
        ...rows.map((r) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                border:
                    Border(top: BorderSide(color: _border.withOpacity(0.5)))),
            child: Row(children: [
              SizedBox(
                  width: 130,
                  child: Text(r.$1,
                      style:
                          GoogleFonts.dmSans(fontSize: 11, color: _textSec))),
              Expanded(
                  child: Text(r.$2.isEmpty ? '—' : r.$2,
                      style: GoogleFonts.dmSans(
                          fontSize: 11, fontWeight: FontWeight.w500))),
            ]))),
      ]));

  String _typeLabel(String t) {
    const m = {
      'university': 'University',
      'grande_ecole': 'Grande École',
      'training_centre': 'Training Centre',
      'professional_school': 'Professional School',
      'language_institute': 'Language Institute',
      'online_platform': 'Online Platform',
      'tvet_centre': 'TVET Centre',
      'corporate_training': 'Corporate Training',
    };
    return m[t] ?? t;
  }
}
