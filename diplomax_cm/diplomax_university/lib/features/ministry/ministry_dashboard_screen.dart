// ═══════════════════════════════════════════════════════════════════════════
// DIPLOMAX CM — Ministry Analytics Dashboard
// Real-time dashboard for the Ministry of Higher Education (MINESUP)
// Shows: institutions, documents issued, verifications, revenue, trends
// This is part of the university app but scoped to the MINISTRY role
// ═══════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../l10n/app_strings.dart';

const _G = Color(0xFF0F6E56);
const _GL = Color(0xFFE1F5EE);
const _B = Color(0xFF185FA5);
const _BL = Color(0xFFE6F1FB);
const _P = Color(0xFF534AB7);
const _PL = Color(0xFFEEEDFE);
const _A = Color(0xFFBA7517);
const _AL = Color(0xFFFAEEDA);
const _BG = Color(0xFFF7F6F2);
const _S = Color(0xFFFFFFFF);
const _BD = Color(0xFFE0DDD5);
const _T1 = Color(0xFF1A1A1A);
const _T2 = Color(0xFF6B6B6B);
const _API = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://diplomax-backend.onrender.com/v1');
const _sto = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true));

class MinistryDashboardScreen extends ConsumerStatefulWidget {
  const MinistryDashboardScreen({super.key});
  @override
  ConsumerState<MinistryDashboardScreen> createState() => _MDS();
}

class _MDS extends ConsumerState<MinistryDashboardScreen> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _institutions = [];
  List<Map<String, dynamic>> _recentDocs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Dio get _dio => Dio(BaseOptions(baseUrl: _API));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tok = await _sto.read(key: 'access_token') ?? '';
      final dio = Dio(BaseOptions(
          baseUrl: _API, headers: {'Authorization': 'Bearer $tok'}));

      final results = await Future.wait([
        dio.get('/ministry/stats').catchError(
            (_) => Response(requestOptions: RequestOptions(), data: {
                  'total_institutions': 0,
                  'total_documents': 0,
                  'total_verifications': 0,
                  'total_revenue_fcfa': 0,
                  'documents_today': 0,
                  'verifications_today': 0
                })),
        dio.get('/institutions/', queryParameters: {
          'page_size': 20
        }).catchError((_) =>
            Response(requestOptions: RequestOptions(), data: {'items': []})),
        dio.get('/ministry/recent-documents', queryParameters: {
          'page_size': 10
        }).catchError((_) =>
            Response(requestOptions: RequestOptions(), data: {'items': []})),
      ]);

      setState(() {
        _stats = results[0].data as Map<String, dynamic>? ?? {};
        _institutions = ((results[1].data['items']) as List? ?? [])
            .cast<Map<String, dynamic>>();
        _recentDocs = ((results[2].data['items']) as List? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _BG,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                AppStrings.of(context)
                    .tr('Tableau de bord ministeriel', 'Ministry Dashboard'),
                style: GoogleFonts.instrumentSerif(fontSize: 20, color: _T1)),
            Text(
                AppStrings.of(context).tr('MINESUP - Analytique en temps reel',
                    'MINESUP - Real-time analytics'),
                style: GoogleFonts.dmSans(fontSize: 11, color: _T2)),
          ]),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh_rounded, color: _G),
                onPressed: _load),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _G))
            : RefreshIndicator(
                color: _G,
                onRefresh: _load,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(AppStrings.of(context)
                            .tr('Vue d\'ensemble', 'Overview')),
                        const SizedBox(height: 10),
                        _statsGrid(),
                        const SizedBox(height: 24),
                        _revenueCard(),
                        const SizedBox(height: 24),
                        _sectionTitle(AppStrings.of(context).tr(
                            'Institutions connectees (${_institutions.length})',
                            'Connected institutions (${_institutions.length})')),
                        const SizedBox(height: 10),
                        _institutionsList(),
                        const SizedBox(height: 24),
                        _sectionTitle(AppStrings.of(context).tr(
                            'Documents emis recemment',
                            'Recent documents issued')),
                        const SizedBox(height: 10),
                        _recentDocsList(),
                        const SizedBox(height: 24),
                        _sectionTitle(AppStrings.of(context)
                            .tr('Etat de la blockchain', 'Blockchain health')),
                        const SizedBox(height: 10),
                        _blockchainCard(),
                      ]),
                )),
      );

  Widget _statsGrid() {
    final s = _stats ?? {};
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _statCard(
            '${s['total_institutions'] ?? 0}',
            AppStrings.of(context)
                .tr('Institutions\nconnectees', 'Institutions\nconnected'),
            _G,
            _GL,
            Icons.account_balance_rounded),
        _statCard(
            '${s['total_documents'] ?? 0}',
            AppStrings.of(context).tr('Documents\nemis', 'Documents\nissued'),
            _B,
            _BL,
            Icons.description_rounded),
        _statCard(
            '${s['total_verifications'] ?? 0}',
            AppStrings.of(context)
                .tr('Verifications\ntotales', 'Verifications\ntotal'),
            _P,
            _PL,
            Icons.verified_rounded),
        _statCard(
            '${s['documents_today'] ?? 0}',
            AppStrings.of(context)
                .tr('Documents\naujourd\'hui', 'Documents\ntoday'),
            _A,
            _AL,
            Icons.today_rounded),
      ],
    );
  }

  Widget _statCard(
          String value, String label, Color c, Color bg, IconData icon) =>
      Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.withOpacity(0.25))),
          child: Row(children: [
            Icon(icon, color: c, size: 28),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(value,
                      style:
                          GoogleFonts.instrumentSerif(fontSize: 22, color: c)),
                  Text(label,
                      style: GoogleFonts.dmSans(
                          fontSize: 10, color: c, height: 1.3)),
                ])),
          ]));

  Widget _revenueCard() {
    final s = _stats ?? {};
    final total = (s['total_revenue_fcfa'] as num? ?? 0).toInt();
    final treasury = (total * 0.4).toInt(); // 40% — Treasury
    final univ = (total * 0.4).toInt(); // 40% — Universities
    final platform = (total * 0.2).toInt(); // 20% — Platform

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _S,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _BD)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.account_balance_wallet_rounded,
                color: _G, size: 20),
            const SizedBox(width: 8),
            Text(
                AppStrings.of(context).tr(
                    'Revenus collectes - ${_formatFcfa(total)} FCFA au total',
                    'Revenue collected - ${_formatFcfa(total)} FCFA total'),
                style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 14),
          _revenueRow(
              AppStrings.of(context).tr('Tresor / Etat', 'Treasury / State'),
              treasury,
              total,
              _G),
          const SizedBox(height: 8),
          _revenueRow(AppStrings.of(context).tr('Universites', 'Universities'),
              univ, total, _B),
          const SizedBox(height: 8),
          _revenueRow(
              AppStrings.of(context)
                  .tr('Plateforme (Diplomax)', 'Platform (Diplomax)'),
              platform,
              total,
              _P),
          const SizedBox(height: 10),
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _GL, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_rounded, color: _G, size: 14),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        AppStrings.of(context).tr(
                            'Repartition: 40% Tresor - 40% Universite - 20% Plateforme',
                            'Revenue split: 40% Treasury - 40% University - 20% Platform'),
                        style: GoogleFonts.dmSans(fontSize: 11, color: _G))),
              ])),
        ]));
  }

  Widget _revenueRow(String label, int amount, int total, Color c) {
    final pct = total > 0 ? amount / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: _T2)),
        Text('${_formatFcfa(amount)} FCFA  (${(pct * 100).toInt()}%)',
            style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w500, color: c)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: pct,
              backgroundColor: _BD,
              minHeight: 6,
              valueColor: AlwaysStoppedAnimation<Color>(c))),
    ]);
  }

  Widget _institutionsList() {
    if (_institutions.isEmpty) {
      return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _S,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _BD)),
          child: Text(
              AppStrings.of(context).tr(
                  'Aucune institution connectee pour le moment.',
                  'No institutions connected yet.'),
              style: GoogleFonts.dmSans(fontSize: 13, color: _T2)));
    }

    return Column(
        children: _institutions
            .map((inst) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _S,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _BD)),
                child: Row(children: [
                  Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: _GL, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.account_balance_rounded,
                          color: _G, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(inst['name'] ?? '',
                            style: GoogleFonts.dmSans(
                                fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                            '${inst['city'] ?? ''} - ${AppStrings.of(context).tr('Prefixe', 'Prefix')}: ${inst['matricule_prefix'] ?? ''}',
                            style:
                                GoogleFonts.dmSans(fontSize: 11, color: _T2)),
                      ])),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: inst['is_connected'] == true
                              ? _GL
                              : const Color(0xFFFAEEDA),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                          inst['is_connected'] == true
                              ? AppStrings.of(context).tr('Active', 'Active')
                              : AppStrings.of(context)
                                  .tr('En attente', 'Pending'),
                          style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: inst['is_connected'] == true
                                  ? _G
                                  : const Color(0xFFBA7517)))),
                ])))
            .toList());
  }

  Widget _recentDocsList() {
    if (_recentDocs.isEmpty) {
      return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _S,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _BD)),
          child: Text(
              AppStrings.of(context)
                  .tr('Aucun document recent.', 'No recent documents.'),
              style: GoogleFonts.dmSans(fontSize: 13, color: _T2)));
    }

    return Column(
        children: _recentDocs
            .map((d) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: _S,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _BD)),
                child: Row(children: [
                  const Icon(Icons.description_rounded, color: _G, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(d['title'] ?? '',
                            style: GoogleFonts.dmSans(
                                fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                            '${d['student_name'] ?? ''} · ${d['university'] ?? ''} · ${d['issue_date'] ?? ''}',
                            style:
                                GoogleFonts.dmSans(fontSize: 10, color: _T2)),
                      ])),
                  if (d['blockchain_anchored'] == true)
                    const Icon(Icons.link_rounded, color: _G, size: 14),
                ])))
            .toList());
  }

  Widget _blockchainCard() => FutureBuilder<bool>(
      future: _checkBlockchain(),
      builder: (_, snap) {
        final ok = snap.data ?? false;
        return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: ok ? _GL : const Color(0xFFFCEBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: ok
                        ? _G.withOpacity(0.3)
                        : const Color(0xFFA32D2D).withOpacity(0.3))),
            child: Row(children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: ok ? _G : const Color(0xFFA32D2D), size: 22),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        ok
                            ? AppStrings.of(context).tr(
                                'Hyperledger Fabric - En ligne',
                                'Hyperledger Fabric - Online')
                            : AppStrings.of(context).tr(
                                'Reseau blockchain - Injoignable',
                                'Blockchain network - Unreachable'),
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: ok ? _G : const Color(0xFFA32D2D))),
                    Text(
                        ok
                            ? AppStrings.of(context).tr(
                                'Tous les hash de documents sont ancres on-chain.',
                                'All document hashes are being anchored on-chain.')
                            : AppStrings.of(context).tr(
                                'Les documents sont en file d\'attente et seront ancres quand le reseau sera retabli.',
                                'Documents are queued and will be anchored when network recovers.'),
                        style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: ok ? _G : const Color(0xFFA32D2D),
                            height: 1.4)),
                  ])),
            ]));
      });

  Future<bool> _checkBlockchain() async {
    try {
      final r = await Dio(BaseOptions(baseUrl: _API)).get('/blockchain/health');
      return r.data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.dmSans(
          fontSize: 15, fontWeight: FontWeight.w500, color: _T1));

  String _formatFcfa(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toString();
  }
}
