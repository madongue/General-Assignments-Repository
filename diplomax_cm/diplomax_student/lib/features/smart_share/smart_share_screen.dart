import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../core/api/student_documents_api.dart';
import '../../l10n/app_strings.dart';

class SmartShareScreen extends StatefulWidget {
  const SmartShareScreen({super.key});
  @override
  State<SmartShareScreen> createState() => _SmartShareState();
}

class _SmartShareState extends State<SmartShareScreen> {
  final _api = StudentDocumentsApi.instance;
  Map<String, dynamic>? _selected;
  List<Map<String, dynamic>> _docs = const [];
  bool _loading = true;
  String? _error;
  int _expiryHours = 48;
  bool _zkpMode = false;
  bool _generated = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      final docs = await _api.fetchDocuments(pageSize: 30);
      if (!mounted) return;
      setState(() {
        _docs = docs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppStrings.of(context).tr(
            'Impossible de charger les documents', 'Unable to load documents');
        _loading = false;
      });
    }
  }

  String get _shareLink {
    if (_selected == null) return '';
    final idValue = _selected!['id'] as String? ?? '';
    final id = idValue.length > 8 ? idValue.substring(0, 8) : idValue;
    final hashValue = _selected!['hash_sha256'] as String? ?? '';
    final hash = hashValue.length > 23 ? hashValue.substring(7, 23) : hashValue;
    return 'https://verify.diplomax.cm/doc/$id?t=${_expiryHours}h&zkp=$_zkpMode&sig=$hash';
  }

  String get _expiresAt {
    final exp = DateTime.now().add(Duration(hours: _expiryHours));
    return '${exp.day}/${exp.month}/${exp.year} à ${exp.hour}h${exp.minute.toString().padLeft(2, '0')}';
  }

  void _generate() => setState(() => _generated = true);

  void _copyLink(BuildContext ctx) {
    Clipboard.setData(ClipboardData(text: _shareLink));
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(AppStrings.of(ctx).tr('Lien copie !', 'Link copied!'),
            style: GoogleFonts.dmSans()),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/home')),
        title: Text(
            AppStrings.of(context).tr('Partage intelligent', 'Smart Share'),
            style: GoogleFonts.instrumentSerif(fontSize: 22)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoBox(),
            const SizedBox(height: 20),
            _sectionTitle(AppStrings.of(context)
                .tr('1. Selectionner le document', '1. Select document')),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              )
            else
              ..._docs.map(_docTile),
            const SizedBox(height: 20),
            _sectionTitle(AppStrings.of(context)
                .tr('2. Parametres de partage', '2. Share settings')),
            const SizedBox(height: 10),
            _optionsCard(),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.link_rounded, size: 18),
              label: Text(AppStrings.of(context)
                  .tr('Generer le lien securise', 'Generate secure link')),
              onPressed: _selected == null ? null : _generate,
            ),
            if (_generated && _selected != null) ...[
              const SizedBox(height: 20),
              _linkResultCard(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.of(context).tr(
                  'Le document n\'est jamais envoye directement. Le recruteur consulte une version securisee depuis le serveur universitaire.',
                  'The document is never sent directly. Recruiters view a secured version from the university server.'),
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: AppColors.info, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary),
      );

  Widget _docTile(Map<String, dynamic> d) {
    final sel = _selected?['id'] == d['id'];
    final type = _docType(d['type'] as String? ?? 'attestation');
    return GestureDetector(
      onTap: () => setState(() {
        _selected = d;
        _generated = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? AppColors.primary : AppColors.border,
              width: sel ? 1.5 : 0.5),
        ),
        child: Row(
          children: [
            Icon(_typeIcon(type), color: _typeColor(type), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['title'] as String? ?? '',
                      style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(_typeLabel(type),
                      style: GoogleFonts.dmSans(
                          fontSize: 10, color: AppColors.textHint)),
                ],
              ),
            ),
            if (sel)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }

  String _docType(String value) => value.toLowerCase();

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

  String _typeLabel(String type) {
    switch (type) {
      case 'diploma':
        return AppStrings.of(context).diplomaLabel;
      case 'transcript':
        return AppStrings.of(context).transcriptLabel;
      case 'certificate':
        return AppStrings.of(context).certificateLabel;
      default:
        return AppStrings.of(context).attestationLabel;
    }
  }

  Widget _optionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Expiry
          Row(
            children: [
              const Icon(Icons.timer_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                  AppStrings.of(context)
                      .tr('Expiration du lien', 'Link expiry'),
                  style: GoogleFonts.dmSans(fontSize: 13)),
              const Spacer(),
              ...[24, 48, 72].map((h) {
                final active = _expiryHours == h;
                return GestureDetector(
                  onTap: () => setState(() {
                    _expiryHours = h;
                    _generated = false;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(left: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${h}h',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color:
                              active ? Colors.white : AppColors.textSecondary,
                        )),
                  ),
                );
              }),
            ],
          ),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppColors.divider)),
          // ZKP
          Row(
            children: [
              const Icon(Icons.visibility_off_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        AppStrings.of(context)
                            .tr('Mode Zero-Knowledge', 'Zero-Knowledge mode'),
                        style: GoogleFonts.dmSans(fontSize: 13)),
                    Text(
                        AppStrings.of(context).tr(
                            'Partager seulement la mention (ex: "Bien"), sans exposer toutes les notes',
                            'Share only the mention (e.g. "Good"), without exposing all grades'),
                        style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: AppColors.textHint,
                            height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                  value: _zkpMode,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() {
                        _zkpMode = v;
                        _generated = false;
                      })),
            ],
          ),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppColors.divider)),
          // No copy info
          Row(
            children: [
              const Icon(Icons.block_rounded, size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    AppStrings.of(context).tr(
                        'Aucune copie modifiable envoyee - consultation serveur uniquement',
                        'No editable copy is sent - server-view only'),
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _linkResultCard(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                  AppStrings.of(context)
                      .tr('Lien securise genere', 'Secure link generated'),
                  style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_shareLink,
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                        AppStrings.of(context).tr(
                            'Expire le $_expiresAt', 'Expires on $_expiresAt'),
                        style: GoogleFonts.dmSans(
                            fontSize: 10, color: AppColors.textHint)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(AppStrings.of(context).tr('Copier', 'Copy')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(0, 44),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => _copyLink(ctx),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text(AppStrings.of(context).tr('Partager', 'Share')),
                  style:
                      ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
