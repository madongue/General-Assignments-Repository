import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/app_colors.dart';
import '../../core/api/student_documents_api.dart';
import '../../l10n/app_strings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final _docsApi = StudentDocumentsApi.instance;
  int _docsCount = 0;
  bool _loading = true;
  String _fullName = 'Etudiant';
  String _matricule = '—';
  List<Map<String, dynamic>> _universities = const [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final storedName = await _storage.read(key: 'student_name');
    final storedMat = await _storage.read(key: 'matricule');

    try {
      final docs = await _docsApi.fetchDocuments(pageSize: 50);
      final seen = <String>{};
      final universities = <Map<String, dynamic>>[];
      for (final d in docs) {
        final name = (d['university_name'] as String? ?? '').trim();
        if (name.isEmpty || seen.contains(name.toLowerCase())) continue;
        seen.add(name.toLowerCase());
        final parts = name
            .split(' ')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final short = parts.isEmpty
            ? 'UN'
            : (parts.length == 1
                    ? parts.first.substring(0, parts.first.length >= 2 ? 2 : 1)
                    : '${parts.first[0]}${parts.last[0]}')
                .toUpperCase();
        universities.add({
          'name': name,
          'short': short,
          'city': 'Cameroon',
          'connected': true,
        });
      }

      if (!mounted) return;
      setState(() {
        _fullName = (storedName != null && storedName.trim().isNotEmpty)
            ? storedName.trim()
            : 'Etudiant';
        _matricule = (storedMat != null && storedMat.trim().isNotEmpty)
            ? storedMat.trim()
            : '—';
        _docsCount = docs.length;
        _universities = universities;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fullName = (storedName != null && storedName.trim().isNotEmpty)
            ? storedName.trim()
            : 'Etudiant';
        _matricule = (storedMat != null && storedMat.trim().isNotEmpty)
            ? storedMat.trim()
            : '—';
        _universities = const [];
        _loading = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/home')),
        title: Text(strings.tr('Mon profil', 'My profile'),
            style: GoogleFonts.instrumentSerif(fontSize: 20)),
        actions: [
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text(strings.logout,
                style:
                    GoogleFonts.dmSans(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: GoogleFonts.instrumentSerif(
                      color: Colors.white, fontSize: 32),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(_fullName, style: GoogleFonts.instrumentSerif(fontSize: 26)),
            Text(_matricule,
                style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w300)),

            const SizedBox(height: 24),

            // Info card
            _card(
              title: strings.tr(
                  'Informations personnelles', 'Personal information'),
              children: [
                _row(Icons.badge_rounded, strings.tr('Matricule', 'Matricule'),
                    _matricule),
                _row(Icons.person_rounded,
                    strings.tr('Nom complet', 'Full name'), _fullName),
                _row(
                    Icons.info_outline_rounded,
                    strings.tr('Statut', 'Status'),
                    _loading
                        ? strings.tr('Chargement...', 'Loading...')
                        : strings.tr('Compte actif', 'Active account')),
              ],
            ),

            const SizedBox(height: 16),

            // Security
            _card(
              title: strings.tr('Securite', 'Security'),
              children: [
                _toggle(strings.tr('Biometrie', 'Biometrics'),
                    Icons.fingerprint_rounded, true),
                _toggle(
                    strings.tr('Reconnaissance faciale', 'Face recognition'),
                    Icons.face_rounded,
                    false),
                _toggle(
                    strings.tr(
                        'Notifications de partage', 'Share notifications'),
                    Icons.notifications_rounded,
                    true),
              ],
            ),

            const SizedBox(height: 16),

            // Universities
            _card(
              title: strings.tr(
                  'Universites disponibles', 'Available universities'),
              children: _universities.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          strings.tr(
                              'Aucune universite detectee depuis vos documents.',
                              'No university detected from your documents.'),
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: AppColors.textHint),
                        ),
                      )
                    ]
                  : _universities.map((u) => _uniRow(u)).toList(),
            ),

            const SizedBox(height: 16),

            // Stats
            Row(
              children: [
                _statCard('$_docsCount', strings.documents, AppColors.primary),
                const SizedBox(width: 10),
                _statCard(
                    '3', strings.tr('Partages', 'Shares'), AppColors.info),
                const SizedBox(width: 10),
                _statCard(
                    '0', strings.tr('Alertes', 'Alerts'), AppColors.error),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.dmSans(
                      fontSize: 10, color: AppColors.textHint)),
              Text(value,
                  style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w400)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, IconData icon, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.dmSans(fontSize: 13)),
          const Spacer(),
          Switch(
              value: value,
              activeThumbColor: AppColors.primary,
              onChanged: (_) {}),
        ],
      ),
    );
  }

  Widget _uniRow(Map<String, dynamic> u) {
    final isConnected = u['connected'] == true;
    final short = (u['short'] as String? ?? 'UN');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  isConnected ? AppColors.primaryLight : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                short.length <= 2 ? short : short.substring(0, 2),
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: isConnected ? AppColors.primary : AppColors.textHint,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u['name'] as String? ?? 'Université',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, fontWeight: FontWeight.w400)),
                Text(u['city'] as String? ?? 'Cameroon',
                    style: GoogleFonts.dmSans(
                        fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:
                  isConnected ? AppColors.primaryLight : AppColors.warningLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isConnected ? 'Connectée' : 'Bientôt',
              style: GoogleFonts.dmSans(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isConnected ? AppColors.primary : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.instrumentSerif(fontSize: 26, color: color)),
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
