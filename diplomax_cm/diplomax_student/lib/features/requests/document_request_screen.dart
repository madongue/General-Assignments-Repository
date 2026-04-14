// ═══════════════════════════════════════════════════════════════════════════
// DIPLOMAX CM — Student Document Request Screen
// Students request diplomas, transcripts, certificates, and attestations.
// University receives, reviews, and issues the document.
// ═══════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../l10n/app_strings.dart';

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _blue = Color(0xFF185FA5);
const _blueLight = Color(0xFFE6F1FB);
const _amber = Color(0xFFBA7517);
const _amberLight = Color(0xFFFAEEDA);
const _purple = Color(0xFF534AB7);
const _purpleLight = Color(0xFFEEEDFE);
const _red = Color(0xFFA32D2D);
const _redLight = Color(0xFFFCEBEB);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);
const _textHint = Color(0xFFAAAAAA);

// ─── Request data model ───────────────────────────────────────────────────────
class RequestData {
  String docType = 'transcript';
  String purpose = '';
  String destination = '';
  String urgency = 'normal';
  String notes = '';
}

class RequestResult {
  final String requestId;
  final int feeFcfa;
  final String estimatedReady;
  final String message;
  RequestResult.fromJson(Map<String, dynamic> j)
      : requestId = j['request_id'] as String,
        feeFcfa = (j['fee_fcfa'] as num).toInt(),
        estimatedReady = j['estimated_ready'] as String,
        message = j['message'] as String;
}

// ─── Status model for tracking ────────────────────────────────────────────────
class RequestStatus {
  final String id;
  final String docType;
  final String purpose;
  final String urgency;
  final String status;
  final String? adminNotes;
  final String feeFcfa;
  final bool feePaid;
  final String submittedAt;
  final String? documentId;

  RequestStatus.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        docType = j['doc_type'] as String,
        purpose = j['purpose'] as String? ?? '',
        urgency = j['urgency'] as String? ?? 'normal',
        status = j['status'] as String,
        adminNotes = j['admin_notes'] as String?,
        feeFcfa = j['fee_fcfa']?.toString() ?? '0',
        feePaid = j['fee_paid'] as bool? ?? false,
        submittedAt = j['submitted_at'] as String? ?? '',
        documentId = j['document_id'] as String?;
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class DocumentRequestScreen extends ConsumerStatefulWidget {
  const DocumentRequestScreen({super.key});
  @override
  ConsumerState<DocumentRequestScreen> createState() => _RequestState();
}

class _RequestState extends ConsumerState<DocumentRequestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          titleSpacing: 0,
          backgroundColor: Colors.transparent,
          leading:
              BackButton(color: _textPri, onPressed: () => context.go('/home')),
          title: Text(
              AppStrings.of(context)
                  .tr('Demander un document', 'Request a document'),
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
                      .tr('Nouvelle demande', 'New request')),
              Tab(
                  text:
                      AppStrings.of(context).tr('Mes demandes', 'My requests')),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _NewRequestTab(onSubmitted: () => _tabs.animateTo(1)),
            const _MyRequestsTab(),
          ],
        ),
      );
}

// ─── NEW REQUEST TAB ──────────────────────────────────────────────────────────
class _NewRequestTab extends ConsumerStatefulWidget {
  final VoidCallback onSubmitted;
  const _NewRequestTab({required this.onSubmitted});
  @override
  ConsumerState<_NewRequestTab> createState() => _NewRequestState();
}

class _NewRequestState extends ConsumerState<_NewRequestTab> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _data = RequestData();
  bool _loading = false;
  bool _pricingLoading = true;
  RequestResult? _result;
  String? _error;

  final _purposeCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final Map<String, int> _docBaseFees = {
    'transcript': 1000,
    'diploma': 2500,
    'certificate': 1500,
    'attestation': 500,
  };

  final Map<String, int> _urgencyFees = {
    'normal': 0,
    'urgent': 500,
    'very_urgent': 1500,
  };

  static const _docTypes = [
    (
      'transcript',
      'Official Transcript',
      'Relevé de notes',
      1000,
      Icons.description_rounded,
      _blue
    ),
    (
      'diploma',
      'Diploma Copy',
      'Copie du diplôme',
      2500,
      Icons.school_rounded,
      _green
    ),
    (
      'certificate',
      'Certificate',
      'Certificat',
      1500,
      Icons.verified_rounded,
      _purple
    ),
    (
      'attestation',
      'Attestation',
      'Attestation',
      500,
      Icons.assignment_rounded,
      _amber
    ),
  ];

  static const _purposes = [
    'Job application',
    'Visa application',
    'Further studies abroad',
    'Recognition of qualifications',
    'Bank / financial institution',
    'Professional licence',
    'Scholarship application',
    'Other',
  ];

  static const _urgencies = [
    ('normal', 'Standard', '5 business days', 0, _textSec),
    ('urgent', 'Urgent', '2 business days', 500, _amber),
    ('very_urgent', 'Very Urgent', 'Next business day', 1500, _red),
  ];

  int get _baseFee => _docTypes
      .firstWhere((t) => t.$1 == _data.docType, orElse: () => _docTypes[0])
      .$4
      .let((fallback) => _docBaseFees[_data.docType] ?? fallback);
  int get _urgencyFee => _urgencies
      .firstWhere((u) => u.$1 == _data.urgency, orElse: () => _urgencies[0])
      .$4
      .let((fallback) => _urgencyFees[_data.urgency] ?? fallback);
  int get _totalFee => _baseFee + _urgencyFee;

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    setState(() => _pricingLoading = true);
    try {
      final r = await _api.dio.get('/requests/pricing');
      final prices = (r.data['prices'] as List? ?? []).cast<dynamic>();
      final urgency = Map<String, dynamic>.from(
          r.data['urgency_surcharges'] as Map? ?? const {});

      for (final item in prices) {
        final map = Map<String, dynamic>.from(item as Map);
        final docType = (map['doc_type'] ?? '').toString();
        final fee = (map['base_fee_fcfa'] as num?)?.toInt();
        if (docType.isNotEmpty && fee != null) {
          _docBaseFees[docType] = fee;
        }
      }

      urgency.forEach((key, value) {
        if (value is num) {
          _urgencyFees[key] = value.toInt();
        }
      });
    } catch (_) {
      // Fallback to default catalog when backend pricing is unavailable.
    } finally {
      if (!mounted) return;
      setState(() => _pricingLoading = false);
    }
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    _destCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _data.purpose = _purposeCtrl.text.trim();
    _data.destination = _destCtrl.text.trim();
    _data.notes = _notesCtrl.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final r = await _api.dio.post('/requests/', data: {
        'doc_type': _data.docType,
        'purpose': _data.purpose,
        'destination': _data.destination,
        'urgency': _data.urgency,
        'notes': _data.notes,
      });

      setState(() {
        _result = RequestResult.fromJson(r.data as Map<String, dynamic>);
        _loading = false;
      });
      widget.onSubmitted();
    } on DioException catch (e) {
      setState(() {
        _error = (e.response?.data as Map?)?['detail']?.toString() ??
            'Submission failed. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    if (_result != null) return _buildSuccess();
    return Form(
        key: _formKey,
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoBox(),
              const SizedBox(height: 20),

              // Doc type selector
              _sectionTitle(strings.tr('De quel document avez-vous besoin ?',
                  'What document do you need?')),
              const SizedBox(height: 10),
              if (_pricingLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        strings.tr('Chargement des tarifs de l\'universite...',
                            'Loading university pricing...'),
                        style:
                            GoogleFonts.dmSans(fontSize: 11, color: _textSec),
                      ),
                    ],
                  ),
                ),
              _docTypeGrid(),
              const SizedBox(height: 20),

              // Purpose
              _sectionTitle(strings.tr('Objet *', 'Purpose *')),
              const SizedBox(height: 8),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _purposes
                      .map((p) => GestureDetector(
                          onTap: () => setState(() => _purposeCtrl.text = p),
                          child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                  color: _purposeCtrl.text == p
                                      ? _greenLight
                                      : _surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _purposeCtrl.text == p
                                          ? _green
                                          : _border,
                                      width:
                                          _purposeCtrl.text == p ? 1.5 : 0.5)),
                              child: Text(_purposeLabel(p, strings),
                                  style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _purposeCtrl.text == p
                                          ? _green
                                          : _textSec)))))
                      .toList()),
              const SizedBox(height: 10),
              _textField(
                  _purposeCtrl,
                  strings.tr(
                      'Ou decrivez votre objectif', 'Or describe your purpose'),
                  strings.tr('ex: Candidature chez Camtel',
                      'e.g. Job application at Camtel'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? strings.tr('L\'objet est requis', 'Purpose is required')
                      : null),
              const SizedBox(height: 16),

              // Destination
              _sectionTitle(strings.tr('Pour qui / destination (optionnel)',
                  'For whom / destination (optional)')),
              const SizedBox(height: 8),
              _textField(
                  _destCtrl,
                  strings.tr('Destinataire', 'Recipient'),
                  strings.tr('ex: Ambassade de France, Entreprise XYZ',
                      'e.g. Embassy of France, Company XYZ')),
              const SizedBox(height: 16),

              // Urgency
              _sectionTitle(strings.tr('Urgence', 'Urgency')),
              const SizedBox(height: 10),
              Column(
                  children: _urgencies.map((u) {
                final active = _data.urgency == u.$1;
                final surcharge = _urgencyFees[u.$1] ?? u.$4;
                return GestureDetector(
                    onTap: () => setState(() => _data.urgency = u.$1),
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: active ? u.$5.withOpacity(0.07) : _surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: active ? u.$5 : _border,
                                width: active ? 1.5 : 0.5)),
                        child: Row(children: [
                          Icon(
                              active
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: active ? u.$5 : _textHint,
                              size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(_urgencyLabel(u.$1, strings),
                                    style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: active ? u.$5 : _textPri)),
                                Text(_urgencyDelayLabel(u.$1, strings),
                                    style: GoogleFonts.dmSans(
                                        fontSize: 11, color: _textSec)),
                              ])),
                          if (surcharge > 0)
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: u.$5.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text('+$surcharge FCFA',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 10,
                                        color: u.$5,
                                        fontWeight: FontWeight.w500))),
                        ])));
              }).toList()),
              const SizedBox(height: 16),

              // Additional notes
              _sectionTitle(strings.tr('Notes supplementaires (optionnel)',
                  'Additional notes (optional)')),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  style: GoogleFonts.dmSans(fontSize: 13),
                  decoration: InputDecoration(
                      hintText: strings.tr(
                          'Information complementaire pour le service de scolarite...',
                          'Any additional information for the registrar...'),
                      hintStyle:
                          GoogleFonts.dmSans(color: _textHint, fontSize: 13),
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
                      contentPadding: const EdgeInsets.all(14))),
              const SizedBox(height: 20),

              // Fee summary
              Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _greenLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _green.withOpacity(0.25))),
                  child: Column(children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              strings.tr('Frais de base ($_data.docType)',
                                  'Base fee ($_data.docType)'),
                              style: GoogleFonts.dmSans(
                                  fontSize: 12, color: _textSec)),
                          Text('$_baseFee FCFA',
                              style: GoogleFonts.dmSans(fontSize: 12)),
                        ]),
                    if (_urgencyFee > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                strings.tr(
                                    'Supplement urgence', 'Urgency surcharge'),
                                style: GoogleFonts.dmSans(
                                    fontSize: 12, color: _textSec)),
                            Text('+$_urgencyFee FCFA',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12, color: _amber)),
                          ]),
                      const Divider(height: 12, color: Color(0xFFD3D1C7)),
                    ],
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(strings.tr('Total', 'Total'),
                              style: GoogleFonts.dmSans(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                          Text('$_totalFee FCFA',
                              style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _green)),
                        ]),
                    const SizedBox(height: 6),
                    Text(
                        strings.tr(
                            'Paiement via MTN MoMo ou Orange Money lorsque le document est pret.',
                            'Payable via MTN MoMo or Orange Money when document is ready.'),
                        style:
                            GoogleFonts.dmSans(fontSize: 10, color: _textSec)),
                  ])),
              const SizedBox(height: 20),

              if (_error != null) ...[
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _redLight,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!,
                        style: GoogleFonts.dmSans(color: _red, fontSize: 12))),
                const SizedBox(height: 10),
              ],

              ElevatedButton.icon(
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_loading
                      ? strings.tr('Envoi en cours...', 'Submitting...')
                      : strings.tr('Soumettre la demande', 'Submit request')),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0),
                  onPressed: _loading ? null : _submit),
              const SizedBox(height: 20),
            ])));
  }

  Widget _buildSuccess() => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                    color: _greenLight, shape: BoxShape.circle),
                child:
                    const Icon(Icons.check_rounded, color: _green, size: 44)),
            const SizedBox(height: 20),
            Text(
                AppStrings.of(context)
                    .tr('Demande envoyee!', 'Request submitted!'),
                style:
                    GoogleFonts.instrumentSerif(fontSize: 26, color: _textPri)),
            const SizedBox(height: 8),
            Text(_result!.message,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: _textSec, height: 1.5)),
            const SizedBox(height: 16),
            Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _greenLight,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  _resultRow(
                      AppStrings.of(context).tr('ID demande', 'Request ID'),
                      _result!.requestId.substring(0, 8).toUpperCase()),
                  _resultRow(AppStrings.of(context).tr('Frais', 'Fee'),
                      '${_result!.feeFcfa} FCFA'),
                  _resultRow(
                      AppStrings.of(context).tr('Pret estime', 'Est. ready'),
                      _result!.estimatedReady),
                ])),
            const SizedBox(height: 24),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0),
                onPressed: () => setState(() => _result = null),
                child: Text(AppStrings.of(context).tr(
                    'Soumettre une autre demande', 'Submit another request'))),
          ])));

  Widget _resultRow(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: GoogleFonts.dmSans(fontSize: 12, color: _textSec)),
        Text(v,
            style:
                GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500)),
      ]));

  Widget _infoBox() => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _blueLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _blue.withOpacity(0.2))),
      child: Row(children: [
        const Icon(Icons.info_rounded, color: _blue, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(
                AppStrings.of(context).tr(
                    'Demandez un document a votre universite. Le service de scolarite examinera votre demande et delivrera le document dans le delai indique. Vous ne payez que lorsque le document est pret.',
                    'Request a document from your university. The registrar will review your request and issue it within the stated timeframe. You pay only when the document is ready.'),
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: _blue, height: 1.5))),
      ]));

  Widget _docTypeGrid() => GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: _docTypes.map((t) {
        final active = _data.docType == t.$1;
        return GestureDetector(
            onTap: () => setState(() => _data.docType = t.$1),
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: active ? t.$6.withOpacity(0.1) : _surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: active ? t.$6 : _border,
                        width: active ? 1.5 : 0.5)),
                child: Row(children: [
                  Icon(t.$5, color: active ? t.$6 : _textHint, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(AppStrings.of(context).tr(t.$3, t.$2),
                            style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: active ? t.$6 : _textPri)),
                        Text('${_docBaseFees[t.$1] ?? t.$4} FCFA',
                            style: GoogleFonts.dmSans(
                                fontSize: 10, color: active ? t.$6 : _textSec)),
                      ])),
                ])));
      }).toList());

  String _purposeLabel(String key, AppStrings strings) {
    switch (key) {
      case 'Job application':
        return strings.tr('Candidature emploi', 'Job application');
      case 'Visa application':
        return strings.tr('Demande de visa', 'Visa application');
      case 'Further studies abroad':
        return strings.tr('Etudes a l\'etranger', 'Further studies abroad');
      case 'Recognition of qualifications':
        return strings.tr(
            'Reconnaissance de diplome', 'Recognition of qualifications');
      case 'Bank / financial institution':
        return strings.tr(
            'Banque / institution financiere', 'Bank / financial institution');
      case 'Professional licence':
        return strings.tr('Licence professionnelle', 'Professional licence');
      case 'Scholarship application':
        return strings.tr('Demande de bourse', 'Scholarship application');
      case 'Other':
        return strings.tr('Autre', 'Other');
      default:
        return key;
    }
  }

  String _urgencyLabel(String key, AppStrings strings) {
    switch (key) {
      case 'normal':
        return strings.tr('Standard', 'Standard');
      case 'urgent':
        return strings.tr('Urgent', 'Urgent');
      case 'very_urgent':
        return strings.tr('Tres urgent', 'Very Urgent');
      default:
        return key;
    }
  }

  String _urgencyDelayLabel(String key, AppStrings strings) {
    switch (key) {
      case 'normal':
        return strings.tr('5 jours ouvrables', '5 business days');
      case 'urgent':
        return strings.tr('2 jours ouvrables', '2 business days');
      case 'very_urgent':
        return strings.tr('Prochain jour ouvrable', 'Next business day');
      default:
        return '';
    }
  }

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w500, color: _textPri));

  Widget _textField(TextEditingController c, String label, String hint,
          {String? Function(String?)? validator}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 11, fontWeight: FontWeight.w500, color: _textSec)),
        const SizedBox(height: 4),
        TextFormField(
            controller: c,
            validator: validator,
            style: GoogleFonts.dmSans(fontSize: 13),
            decoration: InputDecoration(
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true)),
      ]);
}

// ─── MY REQUESTS TAB ─────────────────────────────────────────────────────────
class _MyRequestsTab extends ConsumerStatefulWidget {
  const _MyRequestsTab();
  @override
  ConsumerState<_MyRequestsTab> createState() => _MyRequestsState();
}

class _MyRequestsState extends ConsumerState<_MyRequestsTab> {
  final _api = ApiClient();
  List<RequestStatus> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.dio.get('/requests/my');
      final items =
          (r.data['requests'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _requests = items.map(RequestStatus.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (_error != null) {
      return Center(
          child: Text(strings.tr('Erreur: $_error', 'Error: $_error'),
              style: GoogleFonts.dmSans(color: _red)));
    }
    if (_requests.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.inbox_rounded, size: 56, color: Color(0xFFE0DDD5)),
        const SizedBox(height: 16),
        Text(strings.tr('Aucune demande', 'No requests yet'),
            style: GoogleFonts.dmSans(fontSize: 16, color: _textSec)),
        const SizedBox(height: 6),
        Text(
            strings.tr('Vos demandes apparaitront ici.',
                'Your submitted requests will appear here.'),
            style: GoogleFonts.dmSans(fontSize: 12, color: _textHint)),
      ]));
    }

    return RefreshIndicator(
        color: _green,
        onRefresh: _load,
        child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _requests.length,
            itemBuilder: (_, i) => _RequestCard(req: _requests[i])));
  }
}

class _RequestCard extends StatelessWidget {
  final RequestStatus req;
  const _RequestCard({required this.req});

  static const _statusConfig = {
    'pending': (
      _amber,
      _amberLight,
      Icons.hourglass_empty_rounded,
      'Pending review'
    ),
    'reviewing': (_blue, _blueLight, Icons.rate_review_rounded, 'Under review'),
    'approved': (_green, _greenLight, Icons.thumb_up_rounded, 'Approved'),
    'rejected': (_red, _redLight, Icons.cancel_rounded, 'Rejected'),
    'ready': (
      _green,
      _greenLight,
      Icons.check_circle_rounded,
      'Ready to collect'
    ),
    'collected': (
      _textSec,
      Color(0xFFF1EFE8),
      Icons.done_all_rounded,
      'Collected'
    ),
  };

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final cfg = _statusConfig[req.status] ??
        (
          _textSec,
          const Color(0xFFF1EFE8),
          Icons.help_outline_rounded,
          req.status
        );

    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: cfg.$2, borderRadius: BorderRadius.circular(8)),
                child: Icon(cfg.$3, color: cfg.$1, size: 18)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_docTypeLabel(req.docType),
                      style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(req.purpose,
                      style: GoogleFonts.dmSans(fontSize: 11, color: _textSec),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ])),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: cfg.$2, borderRadius: BorderRadius.circular(6)),
                child: Text(_statusLabel(cfg.$4, strings),
                    style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: cfg.$1))),
          ]),
          if (req.adminNotes != null && req.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFF1EFE8),
                    borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  const Icon(Icons.comment_rounded, size: 13, color: _textSec),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(req.adminNotes!,
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: _textSec, height: 1.4))),
                ])),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Text('${req.feeFcfa} FCFA',
                style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: req.feePaid ? _green : _textSec)),
            const SizedBox(width: 8),
            if (req.feePaid)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _greenLight,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(strings.tr('Paye', 'Paid'),
                      style: GoogleFonts.dmSans(
                          fontSize: 9,
                          color: _green,
                          fontWeight: FontWeight.w500))),
            const Spacer(),
            Text(
                req.submittedAt.length > 10
                    ? req.submittedAt.substring(0, 10)
                    : req.submittedAt,
                style: GoogleFonts.dmSans(fontSize: 10, color: _textHint)),
          ]),
          // Pay button when ready
          if (req.status == 'ready' && !req.feePaid) ...[
            const SizedBox(height: 10),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: Text(strings.tr(
                        'Payer ${req.feeFcfa} FCFA et telecharger',
                        'Pay ${req.feeFcfa} FCFA & download')),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0),
                    onPressed: () => context.go('/home/payment'))),
          ],
          if (req.status == 'ready' &&
              req.feePaid &&
              req.documentId != null) ...[
            const SizedBox(height: 10),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(strings.tr('Voir le document dans le coffre',
                        'View document in vault')),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0),
                    onPressed: () =>
                        context.go('/home/document/${req.documentId}'))),
          ],
        ]));
  }

  String _docTypeLabel(String t) {
    switch (t) {
      case 'diploma':
        return 'Diploma copy';
      case 'transcript':
        return 'Official transcript';
      case 'certificate':
        return 'Certificate';
      case 'attestation':
        return 'Attestation';
      default:
        return t;
    }
  }

  String _statusLabel(String statusLabel, AppStrings strings) {
    switch (statusLabel) {
      case 'Pending review':
        return strings.tr('En attente de revue', 'Pending review');
      case 'Under review':
        return strings.tr('En cours de revue', 'Under review');
      case 'Approved':
        return strings.tr('Approuvee', 'Approved');
      case 'Rejected':
        return strings.tr('Rejetee', 'Rejected');
      case 'Ready to collect':
        return strings.tr('Pret a recuperer', 'Ready to collect');
      case 'Collected':
        return strings.tr('Recupere', 'Collected');
      default:
        return statusLabel;
    }
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T value) fn) => fn(this);
}
