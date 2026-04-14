import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../l10n/app_strings.dart';

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

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashState();
}

class _DashState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _blockchainHealthy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = UnivApiClient();
      final results = await Future.wait([
        client.dio.get('/university/dashboard'),
        client.dio.get('/blockchain/health'),
      ]);
      setState(() {
        _data = results[0].data as Map<String, dynamic>;
        _blockchainHealthy = results[1].data['status'] == 'ok';
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: EdgeInsets.all(isWide ? 28 : 16),
                sliver: SliverToBoxAdapter(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statsGrid(isWide),
                    const SizedBox(height: 24),
                    _blockchainStatus(),
                    const SizedBox(height: 24),
                    _quickActions(context),
                    const SizedBox(height: 24),
                    _recentDocuments(),
                  ],
                )),
              ),
            ]),
    );
  }

  Widget _buildHeader() {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      decoration: const BoxDecoration(
          color: _surface, border: Border(bottom: BorderSide(color: _border))),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(strings.dashboard,
              style:
                  GoogleFonts.instrumentSerif(fontSize: 22, color: _textPri)),
          Text(
              strings.tr('The ICT University - Yaounde',
                  'The ICT University - Yaounde'),
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: _textSec, fontWeight: FontWeight.w300)),
        ]),
        const Spacer(),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text(strings.issueDocument),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: () => context.go('/issue'),
        ),
      ]),
    );
  }

  Widget _statsGrid(bool isWide) {
    final strings = AppStrings.of(context);
    final d = _data ?? {};
    final stats = [
      (
        '${d['total_students'] ?? 0}',
        strings.students,
        Icons.people_rounded,
        _green,
        _greenLight
      ),
      (
        '${d['total_documents'] ?? 0}',
        strings.tr('Documents emis', 'Documents issued'),
        Icons.description_rounded,
        _blue,
        _blueLight
      ),
      (
        '${d['blockchain_anchored'] ?? 0}',
        strings.tr('Sur blockchain', 'On blockchain'),
        Icons.verified_rounded,
        _green,
        _greenLight
      ),
    ];
    return GridView.count(
      crossAxisCount: isWide ? 3 : 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isWide ? 2.4 : 3.5,
      children: stats
          .map((s) => Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: s.$5,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: s.$4.withOpacity(0.3))),
                child: Row(children: [
                  Icon(s.$3, color: s.$4, size: 28),
                  const SizedBox(width: 14),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.$1,
                            style: GoogleFonts.instrumentSerif(
                                fontSize: 26, color: s.$4)),
                        Text(s.$2,
                            style: GoogleFonts.dmSans(
                                fontSize: 11, color: s.$4.withOpacity(0.8))),
                      ]),
                ]),
              ))
          .toList(),
    );
  }

  Widget _blockchainStatus() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _blockchainHealthy ? _greenLight : _amberLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    (_blockchainHealthy ? _green : _amber).withOpacity(0.3))),
        child: Row(children: [
          Icon(_blockchainHealthy ? Icons.link_rounded : Icons.link_off_rounded,
              color: _blockchainHealthy ? _green : _amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    AppStrings.of(context).tr(
                      'Hyperledger Fabric blockchain : ${_blockchainHealthy ? "En ligne" : "Hors ligne"}',
                      'Hyperledger Fabric blockchain: ${_blockchainHealthy ? "Online" : "Offline"}',
                    ),
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _blockchainHealthy ? _green : _amber)),
                Text(
                    _blockchainHealthy
                        ? AppStrings.of(context).tr(
                            'Tous les nouveaux documents seront ancres automatiquement',
                            'All new documents will be anchored automatically')
                        : AppStrings.of(context).tr(
                            'Les documents seront ancres quand le reseau sera retabli',
                            'Documents will be anchored when the network is restored'),
                    style: GoogleFonts.dmSans(fontSize: 11, color: _textSec)),
              ])),
          TextButton(
              onPressed: _load,
              child: Text(AppStrings.of(context).tr('Actualiser', 'Refresh'),
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: _blockchainHealthy ? _green : _amber))),
        ]),
      );

  Widget _quickActions(BuildContext ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.of(context).tr('Actions rapides', 'Quick actions'),
              style: GoogleFonts.dmSans(
                  fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(children: [
            _actionCard(
                ctx,
                Icons.add_circle_rounded,
                AppStrings.of(context)
                    .tr('Emettre un diplome', 'Issue diploma'),
                _green,
                '/issue'),
            const SizedBox(width: 10),
            _actionCard(ctx, Icons.people_rounded,
                AppStrings.of(context).students, _blue, '/students'),
            const SizedBox(width: 10),
            _actionCard(ctx, Icons.folder_rounded,
                AppStrings.of(context).documents, _amber, '/documents'),
          ]),
        ],
      );

  Widget _actionCard(BuildContext ctx, IconData icon, String label, Color c,
          String route) =>
      Expanded(
          child: GestureDetector(
        onTap: () => ctx.go(route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border)),
          child: Column(children: [
            Icon(icon, color: c, size: 26),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: _textSec,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ));

  Widget _recentDocuments() {
    final docs = (_data?['recent_documents'] as List? ?? []).cast<Map>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(
              AppStrings.of(context)
                  .tr('Documents recents', 'Recent documents'),
              style: GoogleFonts.dmSans(
                  fontSize: 15, fontWeight: FontWeight.w500)),
          const Spacer(),
          TextButton(
              onPressed: () => context.go('/documents'),
              child: Text(AppStrings.of(context).tr('Voir tout', 'View all'),
                  style: GoogleFonts.dmSans(color: _green, fontSize: 12))),
        ]),
        const SizedBox(height: 10),
        if (docs.isEmpty)
          Center(
              child: Text(
                  AppStrings.of(context).tr(
                      'Aucun document emis pour le moment.',
                      'No documents issued yet.'),
                  style: GoogleFonts.dmSans(color: _textSec, fontSize: 13)))
        else
          ...docs.take(8).map((d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border)),
                child: Row(children: [
                  Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: _greenLight,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.description_rounded,
                          color: _green, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(d['title'] as String? ?? '',
                            style: GoogleFonts.dmSans(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                        Text('${d['type']} · ${d['issue_date']}',
                            style: GoogleFonts.dmSans(
                                fontSize: 11, color: _textSec)),
                      ])),
                  if (d['blockchain_anchored'] == true)
                    const Icon(Icons.link_rounded, color: _green, size: 16),
                ]),
              )),
      ],
    );
  }
}
