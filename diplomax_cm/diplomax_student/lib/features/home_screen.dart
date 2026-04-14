import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/app_colors.dart';
import '../core/api/student_documents_api.dart';
import '../l10n/app_strings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  int _tab = 0;
  final _api = StudentDocumentsApi.instance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _docs = const [];
  String _fullName = 'Etudiant';
  String _firstName = 'Etudiant';
  String _matricule = '—';
  String _university = 'Universite';

  @override
  void initState() {
    super.initState();
    _loadIdentity();
    _loadDocuments();
  }

  Future<void> _loadIdentity() async {
    final storedName = await _storage.read(key: 'student_name');
    final storedMat = await _storage.read(key: 'matricule');

    if (!mounted) return;
    final fullName = (storedName != null && storedName.trim().isNotEmpty)
        ? storedName.trim()
        : 'Student';
    final firstName = fullName.split(' ').first;

    setState(() {
      _fullName = fullName;
      _firstName = firstName;
      _matricule = (storedMat != null && storedMat.trim().isNotEmpty)
          ? storedMat.trim()
          : '—';
    });
  }

  String get _initials {
    final parts = _fullName
        .split(' ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'ET';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Future<void> _loadDocuments() async {
    try {
      final docs = await _api.fetchDocuments(pageSize: 10);
      if (!mounted) return;
      setState(() {
        _docs = docs;
        if (docs.isNotEmpty) {
          final univ = docs.first['university_name'] as String?;
          if (univ != null && univ.trim().isNotEmpty) {
            _university = univ.trim();
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppStrings.of(context).tr(
          'Impossible de charger les documents',
          'Unable to load documents',
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            // ── Stats Row ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildStatsRow(),
            ),

            // ── Quick Actions ────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSection(
                title: strings.tr('Actions rapides', 'Quick actions'),
                child: _buildQuickActions(),
              ),
            ),

            // ── Recent Documents ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      strings.tr('Mes documents', 'My documents'),
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/home/vault'),
                      child: Text(
                        strings.tr('Voir tout', 'View all'),
                        style: GoogleFonts.dmSans(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _errorCard(),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildDocCard(_docs[i]),
                  childCount: _docs.length > 3 ? 3 : _docs.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),

      // Bottom Navigation
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.of(context).tr('Bonjour,', 'Hello,'),
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(
                      _firstName,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Matricule badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.badge_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  _matricule,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _university,
            style: GoogleFonts.dmSans(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final verifiedCount = _docs.where((d) => d['is_verified'] == true).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _statCard('${_docs.length}', 'Documents', AppColors.primary),
          const SizedBox(width: 10),
          _statCard(
              '$verifiedCount',
              AppStrings.of(context).tr('Verifies', 'Verified'),
              AppColors.success),
          const SizedBox(width: 10),
          _statCard('1', AppStrings.of(context).tr('Diplome', 'Diploma'),
              AppColors.certifColor),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.instrumentSerif(
                fontSize: 26,
                color: color,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: color.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final strings = AppStrings.of(context);
    final actions = [
      (
        Icons.qr_code_rounded,
        strings.tr('Generer\nQR Code', 'Generate\nQR Code'),
        AppColors.primary,
        '/home/qr-generate'
      ),
      (
        Icons.qr_code_scanner_rounded,
        strings.tr('Scanner\nQR Code', 'Scan\nQR Code'),
        AppColors.info,
        '/home/qr-scan'
      ),
      (
        Icons.nfc_rounded,
        strings.tr('Validation\nNFC', 'NFC\nValidation'),
        AppColors.certifColor,
        '/home/nfc'
      ),
      (
        Icons.account_circle_rounded,
        strings.tr('Mon\nProfil', 'My\nProfile'),
        const Color(0xFF7F77DD),
        '/home/profile'
      ),
    ];
    return Row(
      children: actions.map((a) {
        return Expanded(
          child: GestureDetector(
            onTap: () => context.go(a.$4),
            child: Container(
              margin: EdgeInsets.only(right: actions.indexOf(a) < 3 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(a.$1, color: a.$3, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    a.$2,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDocCard(Map<String, dynamic> doc) {
    final type = (doc['type'] as String? ?? 'attestation').toLowerCase();
    final typeLabel = _typeLabel(type);
    final typeIcon = _typeIcon(type);
    final color = _typeColor(type);
    final issueDate = doc['issue_date'] as String? ?? '';
    final id = doc['id'] as String? ?? '';
    final shortId =
        id.length <= 8 ? id.toUpperCase() : id.substring(0, 8).toUpperCase();
    return GestureDetector(
      onTap: () => context.go('/home/document/${doc['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(typeIcon, size: 12, color: color),
                            const SizedBox(width: 4),
                            Text(
                              typeLabel,
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (doc['is_verified'] == true)
                        const Icon(Icons.verified_rounded,
                            size: 18, color: AppColors.success),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    doc['title'] as String? ?? '',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doc['university_name'] as String? ?? '',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _infoChip(
                          Icons.star_rounded, doc['mention'] as String? ?? '—'),
                      const SizedBox(width: 8),
                      _infoChip(
                          Icons.calendar_today_rounded, _formatDate(issueDate)),
                      const Spacer(),
                      Text(
                        '#$shortId',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? '',
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value.isEmpty ? '—' : value;
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'diploma':
        return AppStrings.of(context).tr('Diplome', 'Diploma');
      case 'transcript':
        return AppStrings.of(context).tr('Releve', 'Transcript');
      case 'certificate':
        return AppStrings.of(context).tr('Certificat', 'Certificate');
      default:
        return AppStrings.of(context).tr('Attestation', 'Attestation');
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'diploma':
        return AppColors.diplomaColor;
      case 'transcript':
        return AppColors.transcriptColor;
      case 'certificate':
        return AppColors.certifColor;
      default:
        return AppColors.attestColor;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
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

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final strings = AppStrings.of(context);
    final items = [
      (Icons.home_rounded, strings.tr('Accueil', 'Home')),
      (Icons.folder_rounded, strings.tr('Coffre-fort', 'Vault')),
      (Icons.qr_code_rounded, 'QR Code'),
      (Icons.person_rounded, strings.tr('Profil', 'Profile')),
    ];
    final routes = [
      '/home',
      '/home/vault',
      '/home/qr-generate',
      '/home/profile'
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = _tab == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _tab = i);
                  context.go(routes[i]);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[i].$1,
                      color: active ? AppColors.primary : AppColors.textHint,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[i].$2,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: active ? AppColors.primary : AppColors.textHint,
                        fontWeight: active ? FontWeight.w500 : FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
