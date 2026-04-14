import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../l10n/app_strings.dart';

const _G = Color(0xFF0F6E56);
const _GL = Color(0xFFE1F5EE);
const _BG = Color(0xFFF7F6F2);
const _SUR = Color(0xFFFFFFFF);
const _BD = Color(0xFFE0DDD5);
const _T1 = Color(0xFF1A1A1A);
const _T2 = Color(0xFF6B6B6B);
const _TH = Color(0xFFAAAAAA);
const _R = Color(0xFFA32D2D);
const _RL = Color(0xFFFCEBEB);
const _A = Color(0xFFBA7517);
const _AL = Color(0xFFFAEEDA);
const _API = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://diplomax-backend.onrender.com/v1');
const _sto = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true));
Dio _dio(String tok) =>
    Dio(BaseOptions(baseUrl: _API, headers: {'Authorization': 'Bearer $tok'}));

// ── DOCUMENTS LIST ─────────────────────────────────────────────────────────────
class UnivDocumentsScreen extends ConsumerStatefulWidget {
  const UnivDocumentsScreen({super.key});
  @override
  ConsumerState<UnivDocumentsScreen> createState() => _DS();
}

class _DS extends ConsumerState<UnivDocumentsScreen> {
  List<Map<String, dynamic>> _docs = [];
  bool _load = true;
  String _type = 'all';
  final _q = TextEditingController();
  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _load = true);
    try {
      final tok = await _sto.read(key: 'access_token') ?? '';
      final params = <String, dynamic>{'page_size': 100};
      if (_type != 'all') params['type'] = _type;
      if (_q.text.isNotEmpty) params['q'] = _q.text.trim();
      final r =
          await _dio(tok).get('/documents/search', queryParameters: params);
      setState(() {
        _docs = ((r.data['items'] as List?) ?? []).cast<Map<String, dynamic>>();
        _load = false;
      });
    } catch (_) {
      setState(() => _load = false);
    }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
      backgroundColor: _BG,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(AppStrings.of(ctx).documents,
              style: GoogleFonts.instrumentSerif(fontSize: 22, color: _T1)),
          actions: [
            IconButton(
                icon: const Icon(Icons.batch_prediction_rounded, color: _G),
                tooltip:
                    AppStrings.of(ctx).tr('Signature en lot', 'Batch sign'),
                onPressed: () => ctx.go('/issue/batch'))
          ]),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _q,
                      onSubmitted: (_) => _fetch(),
                      decoration: InputDecoration(
                          hintText: AppStrings.of(ctx).tr(
                              'Rechercher des documents', 'Search documents'),
                          hintStyle: const TextStyle(color: _TH, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 18, color: _TH),
                          filled: true,
                          fillColor: _SUR,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _BD)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _BD)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: _G, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12)))),
              const SizedBox(width: 10),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _G,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: EdgeInsets.zero),
                  onPressed: _fetch,
                  child: const Icon(Icons.search_rounded, size: 20)),
            ])),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
                children: [
              'all',
              'diploma',
              'transcript',
              'certificate',
              'attestation'
            ].map((t) {
              final act = _type == t;
              return GestureDetector(
                  onTap: () {
                    setState(() => _type = t);
                    _fetch();
                  },
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                          color: act ? _G : _SUR,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: act ? _G : _BD, width: act ? 1.5 : 0.5)),
                      child: Text(_typeFilterLabel(ctx, t),
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: act ? Colors.white : _T2))));
            }).toList())),
        const SizedBox(height: 10),
        Expanded(
            child: _load
                ? const Center(child: CircularProgressIndicator(color: _G))
                : _docs.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            const Icon(Icons.folder_open_rounded,
                                size: 56, color: Color(0xFFE0DDD5)),
                            const SizedBox(height: 14),
                            Text(
                                AppStrings.of(ctx).tr('Aucun document trouve',
                                    'No documents found'),
                                style: GoogleFonts.dmSans(
                                    fontSize: 15, color: _T2))
                          ]))
                    : RefreshIndicator(
                        color: _G,
                        onRefresh: _fetch,
                        child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _docs.length,
                            itemBuilder: (_, i) {
                              final d = _docs[i];
                              final revoked = d['is_revoked'] == true;
                              return GestureDetector(
                                  onTap: () => ctx.go('/documents/${d['id']}'),
                                  child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                          color: _SUR,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: revoked
                                                  ? _R.withOpacity(0.3)
                                                  : _BD)),
                                      child: Row(children: [
                                        Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                                color: revoked ? _RL : _GL,
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            child: Icon(
                                                _typeIcon(d['type'] ?? ''),
                                                color: revoked ? _R : _G,
                                                size: 20)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Row(children: [
                                                Expanded(
                                                    child: Text(
                                                        d['title'] ?? '',
                                                        style:
                                                            GoogleFonts.dmSans(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis)),
                                                if (revoked)
                                                  Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                          color: _RL,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4)),
                                                      child: Text(
                                                          AppStrings.of(ctx).tr(
                                                              'REVOQUE',
                                                              'REVOKED'),
                                                          style: GoogleFonts
                                                              .dmSans(
                                                                  fontSize: 9,
                                                                  color: _R,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700)))
                                              ]),
                                              Text(
                                                  '${d['student_name'] ?? ''} · ${d['issue_date'] ?? ''}',
                                                  style: GoogleFonts.dmSans(
                                                      fontSize: 11,
                                                      color: _T2)),
                                              if (d['blockchain_anchored'] ==
                                                  true)
                                                Row(children: [
                                                  const Icon(Icons.link_rounded,
                                                      size: 11, color: _G),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                      AppStrings.of(ctx).tr(
                                                          'Ancre sur la blockchain',
                                                          'Blockchain anchored'),
                                                      style: GoogleFonts.dmSans(
                                                          fontSize: 10,
                                                          color: _G))
                                                ]),
                                            ])),
                                        const Icon(Icons.chevron_right_rounded,
                                            color: _TH, size: 18),
                                      ])));
                            }))),
      ]));

  IconData _typeIcon(String t) {
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

  String _typeFilterLabel(BuildContext context, String type) {
    switch (type) {
      case 'all':
        return AppStrings.of(context).tr('Tous', 'All');
      case 'diploma':
        return AppStrings.of(context).tr('Diplome', 'Diploma');
      case 'transcript':
        return AppStrings.of(context).tr('Releve', 'Transcript');
      case 'certificate':
        return AppStrings.of(context).tr('Certificat', 'Certificate');
      case 'attestation':
        return AppStrings.of(context).tr('Attestation', 'Attestation');
      default:
        return type;
    }
  }
}

// ── DOCUMENT DETAIL ────────────────────────────────────────────────────────────
class UnivDocDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const UnivDocDetailScreen({super.key, required this.id});
  @override
  ConsumerState<UnivDocDetailScreen> createState() => _DD();
}

class _DD extends ConsumerState<UnivDocDetailScreen> {
  Map<String, dynamic>? _doc;
  bool _load = true;
  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final tok = await _sto.read(key: 'access_token') ?? '';
      final r = await _dio(tok).get('/documents/${widget.id}');
      setState(() {
        _doc = r.data as Map<String, dynamic>;
        _load = false;
      });
    } catch (_) {
      setState(() => _load = false);
    }
  }

  Future<void> _revoke() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(
                  AppStrings.of(context)
                      .tr('Revoquer le document ?', 'Revoke document?'),
                  style: GoogleFonts.instrumentSerif()),
              content: Text(
                  AppStrings.of(context).tr(
                      'Cette action marquera definitivement le document comme REVOQUE sur la blockchain. L\'etudiant sera notifie.',
                      'This will permanently mark the document as REVOKED on the blockchain. The student will be notified.'),
                  style: GoogleFonts.dmSans(fontSize: 13)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child:
                        Text(AppStrings.of(context).tr('Annuler', 'Cancel'))),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _R,
                        foregroundColor: Colors.white,
                        elevation: 0),
                    onPressed: () => Navigator.pop(context, true),
                    child:
                        Text(AppStrings.of(context).tr('Revoquer', 'Revoke')))
              ],
            ));
    if (confirm != true) return;
    try {
      final tok = await _sto.read(key: 'access_token') ?? '';
      await _dio(tok).post('/documents/${widget.id}/revoke',
          data: {'reason': 'Revoked by university registrar'});
      _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppStrings.of(context).tr(
                'Document revoque sur la blockchain',
                'Document revoked on blockchain')),
            backgroundColor: _R,
            behavior: SnackBarBehavior.floating));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
        backgroundColor: _BG,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: const BackButton(color: _T1),
            title: Text(
                AppStrings.of(ctx).tr('Detail du document', 'Document detail'),
                style: GoogleFonts.instrumentSerif(fontSize: 20, color: _T1)),
            actions: [
              if (_doc != null && _doc!['is_revoked'] != true)
                IconButton(
                    icon: const Icon(Icons.block_rounded, color: _R),
                    tooltip: AppStrings.of(ctx).tr('Revoquer', 'Revoke'),
                    onPressed: _revoke)
            ]),
        body: _load
            ? const Center(child: CircularProgressIndicator(color: _G))
            : _body(),
      );

  Widget _body() {
    final d = _doc!;
    final revoked = d['is_revoked'] == true;
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (revoked)
            Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _RL,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _R.withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.block_rounded, color: _R, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          AppStrings.of(context).tr(
                              'Ce document a ete REVOQUE sur la blockchain.',
                              'This document has been REVOKED on the blockchain.'),
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: _R,
                              fontWeight: FontWeight.w500)))
                ])),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _SUR,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _BD)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['title'] ?? '',
                        style: GoogleFonts.instrumentSerif(
                            fontSize: 18, color: _T1)),
                    const SizedBox(height: 12),
                    ...[
                      (
                        AppStrings.of(context).tr('Etudiant', 'Student'),
                        d['student_name'] ?? '-'
                      ),
                      (
                        AppStrings.of(context).tr('Matricule', 'Matricule'),
                        d['matricule'] ?? '-'
                      ),
                      (
                        AppStrings.of(context).tr('Type', 'Type'),
                        d['type'] ?? '-'
                      ),
                      (
                        AppStrings.of(context).tr('Diplome', 'Degree'),
                        d['degree'] ?? '-'
                      ),
                      (
                        AppStrings.of(context).tr('Filiere', 'Field'),
                        d['field'] ?? '-'
                      ),
                      (
                        AppStrings.of(context).tr('Mention', 'Mention'),
                        d['mention'] ?? '-'
                      ),
                      (
                        AppStrings.of(context)
                            .tr('Date d\'emission', 'Issue date'),
                        d['issue_date'] ?? '-'
                      )
                    ].map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          SizedBox(
                              width: 100,
                              child: Text(r.$1,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 12, color: _T2))),
                          Expanded(
                              child: Text(r.$2,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)))
                        ]))),
                  ])),
          const SizedBox(height: 16),
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _GL,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _G.withOpacity(0.2))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.security_rounded, color: _G, size: 16),
                      const SizedBox(width: 8),
                      Text(
                          AppStrings.of(context).tr(
                              'Preuve cryptographique', 'Cryptographic proof'),
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _G))
                    ]),
                    const SizedBox(height: 10),
                    Text('SHA-256: ${(d['hash_sha256'] as String?) ?? '-'}',
                        style: GoogleFonts.dmSans(fontSize: 10, color: _G),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (d['blockchain_tx'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                          '${AppStrings.of(context).tr('Transaction blockchain', 'Blockchain TX')}: ${d['blockchain_tx']}',
                          style: GoogleFonts.dmSans(fontSize: 10, color: _G),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)
                    ],
                    if (d['is_blockchain_anchored'] == true) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            color: _G, size: 14),
                        const SizedBox(width: 6),
                        Text(
                            AppStrings.of(context).tr(
                                'Ancre sur Hyperledger Fabric',
                                'Anchored on Hyperledger Fabric'),
                            style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: _G,
                                fontWeight: FontWeight.w500))
                      ])
                    ],
                  ])),
          const SizedBox(height: 16),
          if (d['rsa_signature'] == null)
            ElevatedButton.icon(
                icon: const Icon(Icons.draw_rounded, size: 18),
                label: Text(AppStrings.of(context)
                    .tr('Signer ce document', 'Sign this document')),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _G,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0),
                onPressed: () => context.go('/issue/sign/${d['id']}')),
        ]));
  }
}
