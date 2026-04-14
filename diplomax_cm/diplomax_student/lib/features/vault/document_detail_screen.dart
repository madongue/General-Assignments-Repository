import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/models.dart';
import '../../core/api/student_documents_api.dart';
import '../../l10n/app_strings.dart';

class DocumentDetailScreen extends StatefulWidget {
  final String documentId;
  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  final _api = StudentDocumentsApi.instance;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _doc;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final doc = await _api.fetchDocument(widget.documentId);
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppStrings.of(context).failedToLoadDocument;
        _loading = false;
      });
    }
  }

  Map<String, dynamic> get doc => _doc ?? const {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/home/vault')),
        title: Text(
          _titleForDoc(),
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.primary),
            onPressed: () => context.go('/home/qr-generate'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDocHeader(),
                      const SizedBox(height: 20),
                      _buildInfoCard(),
                      if ((doc['content'] as Map<String, dynamic>?)?['courses']
                              is List &&
                          ((doc['content'] as Map<String, dynamic>)['courses']
                                  as List)
                              .isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildGradesCard(),
                      ],
                      const SizedBox(height: 20),
                      _buildSecurityCard(context),
                      const SizedBox(height: 20),
                      _buildQrSection(),
                      const SizedBox(height: 20),
                      _buildActions(context),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDocHeader() {
    final docType = _typeFromString(doc['type'] as String? ?? 'attestation');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: docType.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(docType.icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc['title'] as String? ?? '',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  doc['field'] as String? ?? '',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.of(context).documentAuthenticated,
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final rows = [
      (
        AppStrings.of(context).university,
        doc['university_name'] as String? ?? '—'
      ),
      (AppStrings.of(context).diplomaLabel, doc['degree'] as String? ?? '—'),
      (AppStrings.of(context).mention, doc['mention'] as String? ?? '—'),
      (
        AppStrings.of(context).issueDate,
        _formatDate(doc['issue_date'] as String?)
      ),
      (
        AppStrings.of(context).registrationNumber,
        doc['matricule'] as String? ?? '—'
      ),
      (AppStrings.of(context).documentReference, '#${_shortId()}'),
    ];
    return _card(
      title: AppStrings.of(context).information,
      child: Column(
        children: rows.map((r) => _infoRow(r.$1, r.$2)).toList(),
      ),
    );
  }

  Widget _buildGradesCard() {
    final content = (doc['content'] as Map<String, dynamic>?) ?? const {};
    final grades = (content['courses'] as List? ?? const [])
        .whereType<Map>()
        .map((g) => Map<String, dynamic>.from(g))
        .toList();
    final avg = grades.isEmpty
        ? 0.0
        : grades.fold<double>(0.0, (s, g) => s + _gradeValue(g)) /
            grades.length;

    return _card(
      title: AppStrings.of(context).gradesReport,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${AppStrings.of(context).average} ${avg.toStringAsFixed(2)}${AppStrings.of(context).gradeOutOf}',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      child: Column(
        children: grades.map((g) {
          final value = _gradeValue(g);
          final color = value >= 14
              ? AppColors.success
              : value >= 10
                  ? AppColors.warning
                  : AppColors.error;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(
                  g['code'] as String? ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    g['name'] as String? ?? '',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Text(
                  '$value${AppStrings.of(context).gradeOutOf}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  double _gradeValue(Map<String, dynamic> g) {
    final value = g['grade'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _shortId() {
    final id = doc['id'] as String? ?? widget.documentId;
    return id.length <= 8 ? id.toUpperCase() : id.substring(0, 8).toUpperCase();
  }

  String _titleForDoc() {
    final type = _typeFromString(doc['type'] as String? ?? 'attestation');
    return _localizedDocTypeLabel(type);
  }

  String _formatDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) return value ?? '—';
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }

  DocumentType _typeFromString(String value) {
    switch (value.toLowerCase()) {
      case 'diploma':
        return DocumentType.diploma;
      case 'transcript':
        return DocumentType.transcript;
      case 'certificate':
        return DocumentType.certificate;
      default:
        return DocumentType.attestation;
    }
  }

  String _localizedDocTypeLabel(DocumentType type) {
    final strings = AppStrings.of(context);
    switch (type) {
      case DocumentType.diploma:
        return strings.diplomaLabel;
      case DocumentType.transcript:
        return strings.transcriptLabel;
      case DocumentType.certificate:
        return strings.certificateLabel;
      case DocumentType.attestation:
        return strings.attestationLabel;
    }
  }

  Widget _buildSecurityCard(BuildContext context) {
    final hash = doc['hash_sha256'] as String? ?? '—';
    return _card(
      title: AppStrings.of(context).cryptographicFingerprint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: hash));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppStrings.of(context).hashCopied)),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hash,
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy_rounded,
                      size: 16, color: AppColors.textHint),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _securityBadge(
              Icons.lock_rounded, AppStrings.of(context).e2eEncryption, true),
          _securityBadge(Icons.visibility_off_rounded,
              AppStrings.of(context).zeroKnowledgeProof, true),
          _securityBadge(
              Icons.shield_rounded, AppStrings.of(context).tamperProof, true),
        ],
      ),
    );
  }

  Widget _buildQrSection() {
    final id = doc['id'] as String? ?? widget.documentId;
    final hash = doc['hash_sha256'] as String? ?? '';
    final hashPart = hash.length >= 20 ? hash.substring(0, 20) : hash;
    return _card(
      title: AppStrings.of(context).qrCodeSharing,
      child: Center(
        child: Column(
          children: [
            QrImageView(
              data: 'diplomax://verify/$id?hash=$hashPart',
              version: QrVersions.auto,
              size: 160,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.of(context).codeValidSingleUse,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.textHint,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.qr_code_rounded, size: 18),
          label: Text(AppStrings.of(context).generateDynamicQRCode),
          onPressed: () => context.go('/home/qr-generate'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.nfc_rounded, size: 18),
          label: Text(AppStrings.of(context).validateViaNCF),
          onPressed: () => context.go('/home/nfc'),
        ),
      ],
    );
  }

  Widget _card(
      {required String title, required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              if (trailing != null) ...[const Spacer(), trailing],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityBadge(IconData icon, String label, bool active) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 14, color: active ? AppColors.success : AppColors.textHint),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: active ? AppColors.textPrimary : AppColors.textHint,
              fontWeight: FontWeight.w300,
            ),
          ),
          const Spacer(),
          if (active)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                AppStrings.of(context).active,
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
