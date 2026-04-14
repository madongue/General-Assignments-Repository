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
const _API = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://diplomax-backend.onrender.com/v1');

Dio _dio(String tok) =>
    Dio(BaseOptions(baseUrl: _API, headers: {'Authorization': 'Bearer $tok'}));
const _sto = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true));

InputDecoration _id(String h, {IconData? ic}) => InputDecoration(
    hintText: h,
    hintStyle: const TextStyle(color: _TH, fontSize: 13),
    prefixIcon: ic != null ? Icon(ic, size: 18, color: _TH) : null,
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
        borderSide: const BorderSide(color: _G, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12));

// ── STUDENTS LIST ─────────────────────────────────────────────────────────────
class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});
  @override
  ConsumerState<StudentsScreen> createState() => _SS();
}

class _SS extends ConsumerState<StudentsScreen> {
  List<Map<String, dynamic>> _all = [], _show = [];
  bool _load = true;
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
      final r = await _dio(tok).get('/students');
      final items =
          ((r.data['items'] as List?) ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _all = items;
        _show = items;
        _load = false;
      });
    } catch (_) {
      setState(() => _load = false);
    }
  }

  void _filter(String q) {
    final ql = q.toLowerCase();
    setState(() => _show = _all
        .where((s) =>
            '${s['full_name'] ?? ''} ${s['matricule'] ?? ''} ${s['email'] ?? ''}'
                .toLowerCase()
                .contains(ql))
        .toList());
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
      backgroundColor: _BG,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(AppStrings.of(ctx).students,
              style: GoogleFonts.instrumentSerif(fontSize: 22, color: _T1)),
          actions: [
            TextButton.icon(
                icon: const Icon(Icons.person_add_rounded, size: 16, color: _G),
                label: Text(AppStrings.of(ctx).tr('Ajouter', 'Add'),
                    style: GoogleFonts.dmSans(color: _G, fontSize: 13)),
                onPressed: () => _addSheet(ctx))
          ]),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                controller: _q,
                onChanged: _filter,
                decoration: _id(
                    AppStrings.of(ctx).tr(
                        'Rechercher par nom, matricule, email',
                        'Search by name, matricule, email'),
                    ic: Icons.search_rounded))),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
                AppStrings.of(ctx).tr(
                    '${_show.length} etudiants', '${_show.length} students'),
                style: GoogleFonts.dmSans(fontSize: 12, color: _T2))),
        const SizedBox(height: 8),
        Expanded(
            child: _load
                ? const Center(child: CircularProgressIndicator(color: _G))
                : _show.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            const Icon(Icons.people_outline_rounded,
                                size: 56, color: Color(0xFFE0DDD5)),
                            const SizedBox(height: 14),
                            Text(
                                AppStrings.of(ctx)
                                    .tr('Aucun etudiant', 'No students'),
                                style: GoogleFonts.dmSans(
                                    fontSize: 15, color: _T2))
                          ]))
                    : RefreshIndicator(
                        color: _G,
                        onRefresh: _fetch,
                        child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _show.length,
                            itemBuilder: (_, i) {
                              final s = _show[i];
                              final initials =
                                  (s['full_name'] as String?) ?? '?';
                              final first = initials.isNotEmpty
                                  ? initials[0].toUpperCase()
                                  : '?';
                              return GestureDetector(
                                onTap: () => ctx.go('/students/${s['id']}'),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _SUR,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _BD),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: const BoxDecoration(
                                          color: _GL, shape: BoxShape.circle),
                                      child: Center(
                                          child: Text(first,
                                              style:
                                                  GoogleFonts.instrumentSerif(
                                                      fontSize: 18,
                                                      color: _G))),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(s['full_name'] ?? '',
                                                style: GoogleFonts.dmSans(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                            Text(s['matricule'] ?? '',
                                                style: GoogleFonts.dmSans(
                                                    fontSize: 11, color: _T2)),
                                            Text(s['email'] ?? '',
                                                style: GoogleFonts.dmSans(
                                                    fontSize: 11, color: _TH)),
                                          ]),
                                    ),
                                    const Icon(Icons.chevron_right_rounded,
                                        color: _TH, size: 18),
                                  ]),
                                ),
                              );
                            }))),
      ]));

  void _addSheet(BuildContext ctx) {
    final c = List.generate(5, (_) => TextEditingController());
    final labels = [
      AppStrings.of(ctx).tr('Nom complet *', 'Full name *'),
      AppStrings.of(ctx).tr('Matricule *', 'Matricule *'),
      AppStrings.of(ctx).tr('Email *', 'Email *'),
      AppStrings.of(ctx).tr('Telephone', 'Phone'),
      AppStrings.of(ctx).tr('Mot de passe initial *', 'Initial password *')
    ];
    final hints = [
      'Nguend Arthur Johann',
      'ICTU20240001',
      'student@ictuniversity.cm',
      '+237 6XX XXX XXX',
      'TempPass123!'
    ];
    showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      AppStrings.of(ctx)
                          .tr('Ajouter un etudiant', 'Add student'),
                      style: GoogleFonts.instrumentSerif(fontSize: 20)),
                  const SizedBox(height: 14),
                  ...List.generate(
                      5,
                      (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextField(
                              controller: c[i],
                              obscureText: i == 4,
                              style: GoogleFonts.dmSans(fontSize: 13),
                              decoration: _id(hints[i])
                                  .copyWith(labelText: labels[i])))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _G,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0),
                      onPressed: () async {
                        try {
                          final tok =
                              await _sto.read(key: 'access_token') ?? '';
                          await _dio(tok).post('/students', data: {
                            'full_name': c[0].text,
                            'matricule': c[1].text,
                            'email': c[2].text,
                            'phone': c[3].text,
                            'password':
                                c[4].text.isEmpty ? 'TempPass123!' : c[4].text
                          });
                          Navigator.pop(ctx);
                          _fetch();
                        } catch (_) {}
                      },
                      child: Text(AppStrings.of(ctx)
                          .tr('Ajouter etudiant', 'Add student'))),
                  const SizedBox(height: 8),
                ])));
  }
}

// ── STUDENT DETAIL ────────────────────────────────────────────────────────────
class StudentDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const StudentDetailScreen({super.key, required this.id});
  @override
  ConsumerState<StudentDetailScreen> createState() => _SDS();
}

class _SDS extends ConsumerState<StudentDetailScreen> {
  Map<String, dynamic>? _s;
  List<Map<String, dynamic>> _docs = [];
  bool _load = true;
  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final tok = await _sto.read(key: 'access_token') ?? '';
      final dio = _dio(tok);
      final sr = await dio.get('/students/${widget.id}');
      final dr = await dio.get('/documents/search',
          queryParameters: {'student_id': widget.id, 'page_size': 50});
      setState(() {
        _s = sr.data as Map<String, dynamic>;
        _docs =
            ((dr.data['items'] as List?) ?? []).cast<Map<String, dynamic>>();
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
            leading: const BackButton(color: _T1),
            title: Text(
                _s?['full_name'] ??
                    AppStrings.of(ctx).tr('Etudiant', 'Student'),
                style: GoogleFonts.instrumentSerif(fontSize: 20, color: _T1))),
        body: _load
            ? const Center(child: CircularProgressIndicator(color: _G))
            : _body(ctx),
      );

  Widget _body(BuildContext ctx) {
    final s = _s!;
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _SUR,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _BD)),
              child: Column(children: [
                Container(
                    width: 64,
                    height: 64,
                    decoration:
                        const BoxDecoration(color: _GL, shape: BoxShape.circle),
                    child: Center(
                        child: Text(
                            (s['full_name'] as String? ?? '?')[0].toUpperCase(),
                            style: GoogleFonts.instrumentSerif(
                                fontSize: 28, color: _G)))),
                const SizedBox(height: 10),
                Text(s['full_name'] ?? '',
                    style: GoogleFonts.dmSans(
                        fontSize: 16, fontWeight: FontWeight.w500)),
                Text(s['matricule'] ?? '',
                    style: GoogleFonts.dmSans(fontSize: 13, color: _T2)),
                const SizedBox(height: 10),
                ...[
                  (AppStrings.of(ctx).tr('Email', 'Email'), s['email'] ?? '—'),
                  (
                    AppStrings.of(ctx).tr('Telephone', 'Phone'),
                    s['phone'] ?? '—'
                  )
                ].map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(
                          width: 80,
                          child: Text(r.$1,
                              style: GoogleFonts.dmSans(
                                  fontSize: 12, color: _T2))),
                      Expanded(
                          child: Text(r.$2,
                              style: GoogleFonts.dmSans(
                                  fontSize: 12, fontWeight: FontWeight.w500)))
                    ]))),
              ])),
          const SizedBox(height: 20),
          Text(
              AppStrings.of(ctx).tr(
                  'Documents (${_docs.length})', 'Documents (${_docs.length})'),
              style: GoogleFonts.dmSans(
                  fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          if (_docs.isEmpty)
            Text(
                AppStrings.of(ctx)
                    .tr('Aucun document pour le moment.', 'No documents yet.'),
                style: GoogleFonts.dmSans(fontSize: 13, color: _T2))
          else
            ..._docs.map(
              (d) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: _SUR,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _BD)),
                  child: Row(children: [
                    const Icon(Icons.description_rounded, color: _G, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(d['title'] ?? '',
                              style: GoogleFonts.dmSans(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text('${d['type'] ?? ''} · ${d['issue_date'] ?? ''}',
                              style:
                                  GoogleFonts.dmSans(fontSize: 11, color: _T2))
                        ])),
                    if (d['is_verified'] == true)
                      const Icon(Icons.verified_rounded, color: _G, size: 16)
                  ])),
            ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(AppStrings.of(ctx)
                  .tr('Emettre un document', 'Issue a document')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _G,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0),
              onPressed: () => ctx.go('/issue/form')),
        ]));
  }
}
