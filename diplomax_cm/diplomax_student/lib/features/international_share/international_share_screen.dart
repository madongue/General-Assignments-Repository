// ═══════════════════════════════════════════════════════════════════════════
// DIPLOMAX CM — International Share Screen
// For students sharing academic documents to abroad institutions
// (embassies, foreign universities, visa applications)
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

// ─── Model ────────────────────────────────────────────────────────────────────
class IntlShareRequest {
  List<String> documentIds = [];
  String institutionName = '';
  String institutionEmail = '';
  String institutionCountry = '';
  String purpose = '';
  int expiryDays = 30;
  bool includeGrades = true;
  bool includeBlockchainProof = true;
  bool includeUniversityLetter = false;
  String? password;
}

class IntlShareResult {
  final String packageId;
  final String token;
  final String accessUrl;
  final String expiresAt;
  final String message;

  IntlShareResult.fromJson(Map<String, dynamic> j)
      : packageId = j['package_id'] as String,
        token = j['token'] as String,
        accessUrl = j['access_url'] as String,
        expiresAt = j['expires_at'] as String,
        message = j['message'] as String;
}

// ─── Service ──────────────────────────────────────────────────────────────────
class IntlShareService {
  final Dio _dio;
  IntlShareService(this._dio);

  Future<IntlShareResult> createShare(IntlShareRequest req) async {
    final response = await _dio.post('/international-shares', data: {
      'document_ids': req.documentIds,
      'institution_name': req.institutionName,
      'institution_email':
          req.institutionEmail.isEmpty ? null : req.institutionEmail,
      'institution_country': req.institutionCountry,
      'purpose': req.purpose,
      'expiry_days': req.expiryDays,
      'include_grades': req.includeGrades,
      'include_blockchain_proof': req.includeBlockchainProof,
      'include_university_letter': req.includeUniversityLetter,
      if (req.password != null && req.password!.isNotEmpty)
        'password': req.password,
    });
    return IntlShareResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getMyShares() async {
    final r = await _dio.get('/international-shares');
    return (r.data['items'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> revokeShare(String token) async =>
      _dio.delete('/international-shares/$token');
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class InternationalShareScreen extends ConsumerStatefulWidget {
  final List<String> documentIds;
  final List<String> documentTitles;

  const InternationalShareScreen({
    super.key,
    required this.documentIds,
    required this.documentTitles,
  });

  @override
  ConsumerState<InternationalShareScreen> createState() => _IntlShareState();
}

class _IntlShareState extends ConsumerState<InternationalShareScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _form = GlobalKey<FormState>();
  final _req = IntlShareRequest();
  bool _loading = false;
  IntlShareResult? _result;

  // Controllers
  final _instName = TextEditingController();
  final _instEmail = TextEditingController();
  final _instCountry = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _showPwField = false;
  bool _obscurePw = true;

  final _commonPurposes = [
    'Master\'s degree application',
    'PhD application',
    'Visa application',
    'Scholarship application',
    'Professional licence',
    'Job application abroad',
    'Recognition of prior learning',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _req.documentIds = List.from(widget.documentIds);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _instName.dispose();
    _instEmail.dispose();
    _instCountry.dispose();
    _purposeCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    _req.institutionName = _instName.text.trim();
    _req.institutionEmail = _instEmail.text.trim();
    _req.institutionCountry = _instCountry.text.trim();
    _req.purpose = _purposeCtrl.text.trim();
    _req.password =
        _showPwField && _pwCtrl.text.isNotEmpty ? _pwCtrl.text : null;

    setState(() {
      _loading = true;
    });
    try {
      // In the real app, _dio is injected from the API client provider
      final dio = Dio(); // replace with ref.read(apiClientProvider).dio
      final result = await IntlShareService(dio).createShare(_req);
      setState(() {
        _result = result;
      });
      _tabs.animateTo(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              AppStrings.of(context)
                  .tr('Erreur: ${e.toString()}', 'Error: ${e.toString()}'),
              style: GoogleFonts.dmSans()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: BackButton(onPressed: () => context.pop(), color: _textPri),
          title: Text(
              AppStrings.of(context)
                  .tr('Partage international', 'International share'),
              style:
                  GoogleFonts.instrumentSerif(fontSize: 20, color: _textPri)),
          bottom: TabBar(
            controller: _tabs,
            labelColor: _green,
            unselectedLabelColor: _textSec,
            indicatorColor: _green,
            labelStyle:
                GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: [
              Tab(
                  text: AppStrings.of(context)
                      .tr('Creer un package', 'Create package')),
              Tab(
                  text: AppStrings.of(context)
                      .tr('Package pret', 'Package ready'))
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildCreateForm(),
            _buildResultView(),
          ],
        ),
      );

  // ── Create Form ────────────────────────────────────────────────────────────
  Widget _buildCreateForm() => Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // What is this?
              _infoBox(
                icon: Icons.flight_takeoff_rounded,
                color: _blue,
                bgColor: _blueLight,
                title: AppStrings.of(context).tr(
                    'Pour voyages, etudes a l\'etranger et visas',
                    'For travel, studies abroad & visa applications'),
                body: AppStrings.of(context).tr(
                    'Cela cree un package securise pret pour ambassade avec vos documents académiques certifies et preuve blockchain. L\'institution destinataire recoit un lien pour acceder et telecharger un PDF professionnel.',
                    'This creates a secure, embassy-ready package containing your certified academic documents with blockchain proof. The recipient institution receives a link to access and download a professional PDF.'),
              ),
              const SizedBox(height: 20),

              // Selected documents
              _sectionTitle(AppStrings.of(context)
                  .tr('Documents inclus', 'Documents included')),
              const SizedBox(height: 10),
              ...widget.documentTitles.asMap().entries.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border)),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          color: _green, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(e.value,
                              style: GoogleFonts.dmSans(
                                  fontSize: 13, fontWeight: FontWeight.w400))),
                    ]),
                  )),
              const SizedBox(height: 20),

              // Recipient institution
              _sectionTitle(AppStrings.of(context)
                  .tr('Institution destinataire', 'Recipient institution')),
              const SizedBox(height: 10),
              _textField(
                ctrl: _instName,
                label: AppStrings.of(context)
                    .tr('Nom de l\'institution', 'Institution name'),
                hint: 'e.g. Université de Paris, MIT, Embassy of France',
                required: true,
              ),
              const SizedBox(height: 12),
              _textField(
                ctrl: _instCountry,
                label: AppStrings.of(context).tr('Pays', 'Country'),
                hint: 'e.g. France, Canada, Germany',
                required: true,
              ),
              const SizedBox(height: 12),
              _textField(
                ctrl: _instEmail,
                label: AppStrings.of(context).tr(
                    'Email institution (optionnel)',
                    'Institution email (optional)'),
                hint: 'admissions@university.fr',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // Purpose
              _sectionTitle(AppStrings.of(context).tr('Objet', 'Purpose')),
              const SizedBox(height: 10),
              // Quick select chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonPurposes
                    .map((p) => GestureDetector(
                          onTap: () => setState(() => _purposeCtrl.text = p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: _purposeCtrl.text == p
                                    ? _greenLight
                                    : _surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _purposeCtrl.text == p
                                        ? _green
                                        : _border,
                                    width: _purposeCtrl.text == p ? 1.5 : 0.5)),
                            child: Text(p,
                                style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _purposeCtrl.text == p
                                        ? _green
                                        : _textSec)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 10),
              _textField(
                  ctrl: _purposeCtrl,
                  label: AppStrings.of(context).tr(
                      'Ou saisir un objet personnalise',
                      'Or type custom purpose'),
                  hint: AppStrings.of(context)
                      .tr('Decrivez l\'objet', 'Describe the purpose'),
                  required: true),
              const SizedBox(height: 20),

              // Package contents
              _sectionTitle(AppStrings.of(context)
                  .tr('Contenu du package', 'Package contents')),
              const SizedBox(height: 10),
              _toggleOption(
                icon: Icons.format_list_numbered_rounded,
                title: AppStrings.of(context)
                    .tr('Inclure les notes de cours', 'Include course grades'),
                subtitle: AppStrings.of(context).tr(
                    'Toutes les notes individuelles seront incluses dans le PDF',
                    'All individual course marks will be included in the PDF'),
                value: _req.includeGrades,
                onChanged: (v) => setState(() => _req.includeGrades = v),
              ),
              _toggleOption(
                icon: Icons.verified_rounded,
                title: AppStrings.of(context).tr(
                    'Inclure la preuve blockchain', 'Include blockchain proof'),
                subtitle: AppStrings.of(context).tr(
                    'ID de transaction Hyperledger Fabric et URL de verification',
                    'Hyperledger Fabric transaction ID and verification URL'),
                value: _req.includeBlockchainProof,
                onChanged: (v) =>
                    setState(() => _req.includeBlockchainProof = v),
              ),
              _toggleOption(
                icon: Icons.description_rounded,
                title: AppStrings.of(context).tr(
                    'Inclure la lettre d\'attestation universitaire',
                    'Include university attestation letter'),
                subtitle: AppStrings.of(context).tr(
                    'Lettre officielle de l\'universite certifiant votre inscription',
                    'An official letter from the university certifying your enrolment'),
                value: _req.includeUniversityLetter,
                onChanged: (v) =>
                    setState(() => _req.includeUniversityLetter = v),
              ),
              const SizedBox(height: 20),

              // Validity
              _sectionTitle(AppStrings.of(context)
                  .tr('Validite du package', 'Package validity')),
              const SizedBox(height: 10),
              Row(
                  children: [15, 30, 60, 90].map((d) {
                final active = _req.expiryDays == d;
                return GestureDetector(
                  onTap: () => setState(() => _req.expiryDays = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                        color: active ? _green : _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: active ? _green : _border,
                            width: active ? 1.5 : 0.5)),
                    child: Column(children: [
                      Text('${d}d',
                          style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: active ? Colors.white : _textSec)),
                      Text(
                          d <= 15
                              ? AppStrings.of(context)
                                  .tr('2 semaines', '2 weeks')
                              : d <= 30
                                  ? AppStrings.of(context)
                                      .tr('1 mois', '1 month')
                                  : d <= 60
                                      ? AppStrings.of(context)
                                          .tr('2 mois', '2 months')
                                      : AppStrings.of(context)
                                          .tr('3 mois', '3 months'),
                          style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: active ? Colors.white70 : _textHint)),
                    ]),
                  ),
                );
              }).toList()),
              const SizedBox(height: 20),

              // Optional password
              _sectionTitle(AppStrings.of(context)
                  .tr('Securite (optionnel)', 'Security (optional)')),
              const SizedBox(height: 10),
              _toggleOption(
                icon: Icons.lock_rounded,
                title: AppStrings.of(context).tr(
                    'Proteger ce package par mot de passe',
                    'Password protect this package'),
                subtitle: AppStrings.of(context).tr(
                    'L\'institution devra entrer un mot de passe pour acceder aux documents',
                    'The institution will need a password to access the documents'),
                value: _showPwField,
                onChanged: (v) => setState(() => _showPwField = v),
              ),
              if (_showPwField) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _pwCtrl,
                  obscureText: _obscurePw,
                  decoration: InputDecoration(
                    hintText: AppStrings.of(context).tr(
                        'Entrez le mot de passe du package',
                        'Enter package password'),
                    prefixIcon: const Icon(Icons.key_rounded,
                        size: 18, color: _textHint),
                    suffixIcon: IconButton(
                        icon: Icon(
                            _obscurePw
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            size: 18,
                            color: _textHint),
                        onPressed: () =>
                            setState(() => _obscurePw = !_obscurePw)),
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
                        borderSide:
                            const BorderSide(color: _green, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ],
              const SizedBox(height: 28),

              ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.flight_takeoff_rounded, size: 18),
                label: Text(_loading
                    ? AppStrings.of(context)
                        .tr('Creation du package...', 'Creating package...')
                    : AppStrings.of(context).tr(
                        'Creer un package international',
                        'Create international package')),
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );

  // ── Result View ────────────────────────────────────────────────────────────
  Widget _buildResultView() {
    if (_result == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.flight_takeoff_rounded, size: 56, color: _textHint),
          const SizedBox(height: 16),
          Text(
              AppStrings.of(context)
                  .tr('Creez d\'abord un package', 'Create a package first'),
              style: GoogleFonts.dmSans(color: _textHint, fontSize: 14)),
        ]),
      );
    }

    final r = _result!;
    final expDate = r.expiresAt.substring(0, 10);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success banner
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _greenLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _green.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: _green, size: 22),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          AppStrings.of(context).tr('Package cree avec succes',
                              'Package created successfully'),
                          style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _green)),
                      Text(
                          AppStrings.of(context).tr(
                              'Valide jusqu\'au $expDate · ${_req.expiryDays} jours',
                              'Valid until $expDate · ${_req.expiryDays} days'),
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: _green.withOpacity(0.7))),
                    ])),
              ])),
          const SizedBox(height: 20),

          // QR Code for the institution to scan
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border)),
              child: Column(children: [
                Text(
                    AppStrings.of(context)
                        .tr('Partagez ce QR code', 'Share this QR code'),
                    style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _textPri)),
                const SizedBox(height: 4),
                Text(
                    AppStrings.of(context).tr(
                        'L\'institution scanne ceci pour acceder a vos documents',
                        'The institution scans this to access your documents'),
                    style: GoogleFonts.dmSans(fontSize: 11, color: _textSec)),
                const SizedBox(height: 16),
                QrImageView(
                  data: r.accessUrl,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  foregroundColor: _green,
                ),
                const SizedBox(height: 12),
                if (_showPwField && _pwCtrl.text.isNotEmpty)
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: _amberLight,
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.lock_rounded, size: 13, color: _amber),
                        const SizedBox(width: 6),
                        Text(
                            AppStrings.of(context).tr(
                                'Protege par mot de passe',
                                'Password protected'),
                            style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: _amber,
                                fontWeight: FontWeight.w500)),
                      ])),
              ])),
          const SizedBox(height: 12),

          // Access URL (copy)
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border)),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          AppStrings.of(context)
                              .tr('URL d\'acces', 'Access URL'),
                          style: GoogleFonts.dmSans(
                              fontSize: 10, color: _textHint)),
                      const SizedBox(height: 2),
                      Text(r.accessUrl,
                          style:
                              GoogleFonts.dmSans(fontSize: 11, color: _textSec),
                          overflow: TextOverflow.ellipsis),
                    ])),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: r.accessUrl));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            AppStrings.of(context)
                                .tr('Lien copie!', 'Link copied!'),
                            style: GoogleFonts.dmSans()),
                        backgroundColor: _green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))));
                  },
                  child: const Icon(Icons.copy_rounded,
                      size: 16, color: _textHint),
                ),
              ])),
          const SizedBox(height: 12),

          // Download PDF button
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: Text(AppStrings.of(context).tr(
                'Telecharger le PDF pret pour ambassade',
                'Download embassy-ready PDF')),
            style: OutlinedButton.styleFrom(
              foregroundColor: _green,
              side: const BorderSide(color: _green),
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () {
              final pdfUrl =
                  '${r.accessUrl.replaceAll('/intl/', '/v1/international-shares/')}/pdf';
              // Open in browser: launch(pdfUrl)
            },
          ),
          const SizedBox(height: 10),

          // What's in the package
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _blueLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _blue.withOpacity(0.2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    AppStrings.of(context)
                        .tr('Le package inclut:', 'Package includes:'),
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _blue)),
                const SizedBox(height: 8),
                _pkgItem(AppStrings.of(context).tr(
                    '${_req.documentIds.length} document(s) academique(s) certifie(s)',
                    '${_req.documentIds.length} certified academic document(s)')),
                if (_req.includeGrades)
                  _pkgItem(AppStrings.of(context).tr(
                      'Toutes les notes et evaluations de cours',
                      'Full course grades and marks')),
                if (_req.includeBlockchainProof)
                  _pkgItem(AppStrings.of(context).tr(
                      'Preuve blockchain Hyperledger Fabric',
                      'Hyperledger Fabric blockchain proof')),
                if (_req.includeUniversityLetter)
                  _pkgItem(AppStrings.of(context).tr(
                      'Lettre officielle d\'attestation universitaire',
                      'Official university attestation letter')),
                _pkgItem(AppStrings.of(context).tr(
                    'Empreinte cryptographique SHA-256',
                    'SHA-256 cryptographic fingerprint')),
                _pkgItem(AppStrings.of(context).tr(
                    'Signature numerique universitaire RSA-2048',
                    'University RSA-2048 digital signature')),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Revoke button
          TextButton.icon(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 16, color: Colors.red),
            label: Text(
                AppStrings.of(context)
                    .tr('Revoquer ce package', 'Revoke this package'),
                style: GoogleFonts.dmSans(color: Colors.red, fontSize: 13)),
            onPressed: () => _confirmRevoke(r.token),
          ),
        ],
      ),
    );
  }

  void _confirmRevoke(String token) => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
              AppStrings.of(context)
                  .tr('Revoquer le package?', 'Revoke package?'),
              style: GoogleFonts.instrumentSerif()),
          content: Text(
              AppStrings.of(context).tr(
                  'L\'institution perdra immediatement l\'acces. Action irreversible.',
                  'The institution will immediately lose access. This cannot be undone.'),
              style: GoogleFonts.dmSans()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppStrings.of(context).tr('Annuler', 'Cancel'))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0),
                onPressed: () async {
                  Navigator.pop(context);
                  // await IntlShareService(dio).revokeShare(token);
                  context.pop();
                },
                child: Text(AppStrings.of(context).tr('Revoquer', 'Revoke'))),
          ],
        ),
      );

  Widget _pkgItem(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        const Icon(Icons.check_rounded, size: 13, color: _blue),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: GoogleFonts.dmSans(fontSize: 11, color: _blue))),
      ]));

  Widget _infoBox(
          {required IconData icon,
          required Color color,
          required Color bgColor,
          required String title,
          required String body}) =>
      Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: color, height: 1.5)),
                ])),
          ]));

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w500, color: _textPri));

  Widget _toggleOption(
          {required IconData icon,
          required String title,
          required String subtitle,
          required bool value,
          required ValueChanged<bool> onChanged}) =>
      Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border)),
          child: Row(children: [
            Icon(icon, size: 18, color: _textSec),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(subtitle,
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: _textSec, height: 1.4)),
                ])),
            Switch(
                value: value, activeThumbColor: _green, onChanged: onChanged),
          ]));

  Widget _textField(
          {required TextEditingController ctrl,
          required String label,
          String? hint,
          bool required = false,
          TextInputType? keyboardType}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w500, color: _textPri)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty)
                  ? AppStrings.of(context).tr('Requis', 'Required')
                  : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(color: _textHint, fontSize: 13),
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
        ),
      ]);
}
