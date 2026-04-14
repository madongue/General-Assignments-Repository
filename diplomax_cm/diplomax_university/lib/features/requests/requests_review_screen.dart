// ═══════════════════════════════════════════════════════════════════════════
// DIPLOMAX CM — University Request Review Screen
// University sees all pending student requests.
// Can approve, reject, or issue directly from the request.
// ═══════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../l10n/app_strings.dart';

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _blue = Color(0xFF185FA5);
const _blueLight = Color(0xFFE6F1FB);
const _amber = Color(0xFFBA7517);
const _amberLight = Color(0xFFFAEEDA);
const _red = Color(0xFFA32D2D);
const _redLight = Color(0xFFFCEBEB);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);

class RequestsReviewScreen extends ConsumerStatefulWidget {
  const RequestsReviewScreen({super.key});
  @override
  ConsumerState<RequestsReviewScreen> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<RequestsReviewScreen> {
  final _api = UnivApiClient();
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String _filterStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.dio.get('/requests/admin/all',
          queryParameters: {'status': _filterStatus});
      setState(() {
        _requests =
            (r.data['requests'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String requestId, String status,
      {String? notes}) async {
    await _api.dio.put('/requests/admin/$requestId', data: {
      'status': status,
      'admin_notes': notes,
    });
    await _load();
    if (mounted) {
      final strings = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(strings.tr('Demande $status', 'Request $status'),
              style: GoogleFonts.dmSans()),
          backgroundColor: status == 'approved' ? _green : _red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
    }
  }

  Future<void> _issueFromRequest(String requestId) async {
    await _api.dio.post('/requests/admin/$requestId/issue');
    await _load();
    if (mounted) {
      final strings = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              strings.tr(
                  'Document emis et envoye dans le coffre de l\'etudiant',
                  'Document issued and sent to student vault'),
              style: GoogleFonts.dmSans()),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _openPricingDialog() async {
    final Map<String, TextEditingController> ctrls = {
      'diploma': TextEditingController(),
      'transcript': TextEditingController(),
      'certificate': TextEditingController(),
      'attestation': TextEditingController(),
    };

    try {
      final res = await _api.dio.get('/requests/admin/pricing');
      final items = (res.data['prices'] as List? ?? []).cast<dynamic>();
      for (final item in items) {
        final map = Map<String, dynamic>.from(item as Map);
        final docType = (map['doc_type'] ?? '').toString();
        final fee = (map['base_fee_fcfa'] as num?)?.toInt();
        if (ctrls.containsKey(docType) && fee != null) {
          ctrls[docType]!.text = '$fee';
        }
      }
    } catch (_) {
      // Keep empty values and let staff fill manually.
    }

    if (!mounted) return;
    final strings = AppStrings.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            strings.tr(
                'Configurer les tarifs des demandes', 'Set request pricing'),
            style: GoogleFonts.instrumentSerif()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _priceField(ctrls['diploma']!,
                  strings.tr('Copie du diplome', 'Diploma copy')),
              _priceField(ctrls['transcript']!,
                  strings.tr('Releve officiel', 'Official transcript')),
              _priceField(ctrls['certificate']!,
                  strings.tr('Certificat', 'Certificate')),
              _priceField(ctrls['attestation']!,
                  strings.tr('Attestation', 'Attestation')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.tr('Annuler', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              try {
                await _api.dio.put('/requests/admin/pricing', data: {
                  'prices': [
                    {
                      'doc_type': 'diploma',
                      'base_fee_fcfa':
                          int.tryParse(ctrls['diploma']!.text.trim()) ?? 0
                    },
                    {
                      'doc_type': 'transcript',
                      'base_fee_fcfa':
                          int.tryParse(ctrls['transcript']!.text.trim()) ?? 0
                    },
                    {
                      'doc_type': 'certificate',
                      'base_fee_fcfa':
                          int.tryParse(ctrls['certificate']!.text.trim()) ?? 0
                    },
                    {
                      'doc_type': 'attestation',
                      'base_fee_fcfa':
                          int.tryParse(ctrls['attestation']!.text.trim()) ?? 0
                    },
                  ]
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          strings.tr('Tarifs mis a jour', 'Pricing updated'),
                          style: GoogleFonts.dmSans()),
                      backgroundColor: _green,
                    ),
                  );
                  _load();
                }
              } on DioException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      (e.response?.data as Map?)?['detail']?.toString() ??
                          strings.tr('Echec de la mise a jour des tarifs',
                              'Failed to update pricing'),
                      style: GoogleFonts.dmSans(),
                    ),
                    backgroundColor: _red,
                  ),
                );
              }
            },
            child: Text(strings.tr('Enregistrer', 'Save')),
          ),
        ],
      ),
    );

    for (final c in ctrls.values) {
      c.dispose();
    }
  }

  Widget _priceField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: '$label (FCFA)',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
        ),
      ),
    );
  }

  void _showRejectDialog(String requestId) => showDialog(
      context: context,
      builder: (_) {
        final strings = AppStrings.of(context);
        final ctrl = TextEditingController();
        return AlertDialog(
            title: Text(strings.tr('Rejeter la demande', 'Reject request'),
                style: GoogleFonts.instrumentSerif()),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  strings.tr('Fournissez une raison (visible par l\'etudiant):',
                      'Provide a reason (shown to the student):'),
                  style: GoogleFonts.dmSans(fontSize: 13)),
              const SizedBox(height: 10),
              TextField(
                  controller: ctrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                      hintText: strings.tr(
                          'ex: Frais non regles / Inscription incomplete',
                          'e.g. Fees not yet settled / Incomplete enrolment'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(10))),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(strings.tr('Annuler', 'Cancel'))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      elevation: 0),
                  onPressed: () {
                    Navigator.pop(context);
                    _updateStatus(requestId, 'rejected',
                        notes: ctrl.text.trim());
                  },
                  child: Text(strings.tr('Rejeter', 'Reject'))),
            ]);
      });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(strings.tr('Demandes etudiantes', 'Student requests'),
            style: GoogleFonts.instrumentSerif(fontSize: 20, color: _textPri)),
        actions: [
          IconButton(
              icon: const Icon(Icons.payments_rounded, color: _textPri),
              tooltip: strings.tr('Gerer les tarifs', 'Manage pricing'),
              onPressed: _openPricingDialog),
          IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _textPri),
              onPressed: _load),
        ],
      ),
      body: Column(children: [
        // Status filter tabs
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
                children: [
              'pending',
              'reviewing',
              'approved',
              'rejected',
              'ready',
            ].map((s) {
              final active = _filterStatus == s;
              return GestureDetector(
                  onTap: () {
                    setState(() => _filterStatus = s);
                    _load();
                  },
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                          color: active ? _green : _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: active ? _green : _border,
                              width: active ? 1.5 : 0.5)),
                      child: Text(_statusLabel(s, strings),
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: active ? Colors.white : _textSec))));
            }).toList())),
        // List
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _green))
                : _requests.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            const Icon(Icons.inbox_rounded,
                                size: 56, color: Color(0xFFE0DDD5)),
                            const SizedBox(height: 14),
                            Text(
                                strings.tr(
                                    'Aucune demande ${_statusLabel(_filterStatus, strings).toLowerCase()}',
                                    'No ${_statusLabel(_filterStatus, strings).toLowerCase()} requests'),
                                style: GoogleFonts.dmSans(
                                    fontSize: 15, color: _textSec)),
                          ]))
                    : RefreshIndicator(
                        color: _green,
                        onRefresh: _load,
                        child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _requests.length,
                            itemBuilder: (_, i) => _RequestReviewCard(
                                  data: _requests[i],
                                  onApprove: () => _updateStatus(
                                      _requests[i]['id'], 'approved'),
                                  onReject: () =>
                                      _showRejectDialog(_requests[i]['id']),
                                  onIssue: () =>
                                      _issueFromRequest(_requests[i]['id']),
                                )))),
      ]),
    );
  }

  String _statusLabel(String status, AppStrings strings) {
    switch (status) {
      case 'pending':
        return strings.tr('En attente', 'Pending');
      case 'reviewing':
        return strings.tr('En revision', 'Reviewing');
      case 'approved':
        return strings.tr('Approuve', 'Approved');
      case 'rejected':
        return strings.tr('Rejete', 'Rejected');
      case 'ready':
        return strings.tr('Pret', 'Ready');
      default:
        return status;
    }
  }
}

class _RequestReviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onApprove, onReject, onIssue;
  const _RequestReviewCard(
      {required this.data,
      required this.onApprove,
      required this.onReject,
      required this.onIssue});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final status = data['status'] as String? ?? 'pending';
    final urgency = data['urgency'] as String? ?? 'normal';
    final docType = data['doc_type'] as String? ?? '';
    final purpose = data['purpose'] as String? ?? '';
    final destination = data['destination'] as String?;
    final notes = data['notes'] as String?;
    final fee = data['fee_fcfa']?.toString() ?? '0';

    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: urgency == 'very_urgent'
                      ? _redLight
                      : urgency == 'urgent'
                          ? _amberLight
                          : const Color(0xFFF7F6F2),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14))),
              child: Row(children: [
                Icon(_docIcon(docType),
                    size: 20,
                    color: urgency == 'very_urgent'
                        ? _red
                        : urgency == 'urgent'
                            ? _amber
                            : _textSec),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          strings.tr(
                              _docTypeLabelFr(docType), _docTypeLabel(docType)),
                          style: GoogleFonts.dmSans(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(
                          strings.tr(
                              'Matricule: ${data['matricule'] ?? data['student_id'] ?? '—'}',
                              'Matricule: ${data['matricule'] ?? data['student_id'] ?? '—'}'),
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: _textSec)),
                    ])),
                if (urgency != 'normal')
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: urgency == 'very_urgent'
                              ? _redLight
                              : _amberLight,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                          urgency == 'very_urgent'
                              ? strings.tr('🔴 TRES URGENT', '🔴 URGENT')
                              : strings.tr('🟡 Urgent', '🟡 Urgent'),
                          style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color:
                                  urgency == 'very_urgent' ? _red : _amber))),
              ])),
          // Body
          Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(Icons.help_outline_rounded,
                        strings.tr('Objet', 'Purpose'), purpose),
                    if (destination != null && destination.isNotEmpty)
                      _infoRow(
                          Icons.location_on_rounded,
                          strings.tr('Destination', 'Destination'),
                          destination),
                    if (notes != null && notes.isNotEmpty)
                      _infoRow(Icons.note_rounded, strings.tr('Notes', 'Notes'),
                          notes),
                    _infoRow(Icons.payments_rounded, strings.tr('Frais', 'Fee'),
                        '$fee FCFA'),
                    const SizedBox(height: 12),
                    // Action buttons based on status
                    if (status == 'pending')
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: _red,
                                    side: const BorderSide(color: _red),
                                    minimumSize: const Size(0, 40),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                onPressed: onReject,
                                child: Text(strings.tr('Rejeter', 'Reject')))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: _green,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 40),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                onPressed: onApprove,
                                child:
                                    Text(strings.tr('Approuver', 'Approve')))),
                      ]),
                    if (status == 'approved')
                      ElevatedButton.icon(
                          icon: const Icon(Icons.verified_rounded, size: 16),
                          label: Text(strings.tr(
                              'Emettre le document maintenant',
                              'Issue document now')),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 42),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          onPressed: onIssue),
                    if (status == 'ready')
                      Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: _greenLight,
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            const Icon(Icons.check_circle_rounded,
                                color: _green, size: 16),
                            const SizedBox(width: 8),
                            Text(
                                strings.tr(
                                    'Document emis. En attente du paiement et du retrait par l\'etudiant.',
                                    'Document issued. Waiting for student to pay and collect.'),
                                style: GoogleFonts.dmSans(
                                    fontSize: 11, color: _green)),
                          ])),
                  ])),
        ]));
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 13, color: _textSec),
        const SizedBox(width: 8),
        Text('$label: ',
            style: GoogleFonts.dmSans(fontSize: 11, color: _textSec)),
        Expanded(
            child: Text(value,
                style: GoogleFonts.dmSans(
                    fontSize: 11, fontWeight: FontWeight.w500))),
      ]));

  IconData _docIcon(String t) {
    switch (t) {
      case 'diploma':
        return Icons.school_rounded;
      case 'transcript':
        return Icons.description_rounded;
      case 'certificate':
        return Icons.verified_rounded;
      default:
        return Icons.assignment_rounded;
    }
  }

  String _docTypeLabel(String t) {
    switch (t) {
      case 'diploma':
        return 'Diploma copy';
      case 'transcript':
        return 'Official transcript';
      case 'certificate':
        return 'Certificate';
      default:
        return 'Attestation';
    }
  }

  String _docTypeLabelFr(String t) {
    switch (t) {
      case 'diploma':
        return 'Copie du diplome';
      case 'transcript':
        return 'Releve officiel';
      case 'certificate':
        return 'Certificat';
      default:
        return 'Attestation';
    }
  }
}
