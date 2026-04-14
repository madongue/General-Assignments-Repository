import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../core/models.dart';
import '../../core/api/student_documents_api.dart';
import '../../l10n/app_strings.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  DocumentType? _filter;
  final _api = StudentDocumentsApi.instance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _docs = const [];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      final docs = await _api.fetchDocuments(pageSize: 50);
      if (!mounted) return;
      setState(() {
        _docs = docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppStrings.of(context).tr(
            'Impossible de charger les documents', 'Unable to load documents');
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered => _filter == null
      ? _docs
      : _docs
          .where((d) => _mapType(d['type'] as String? ?? '') == _filter)
          .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/home')),
        title: Text(
          AppStrings.of(context).tr('Coffre-fort', 'Vault'),
          style: GoogleFonts.instrumentSerif(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppColors.primary),
            onPressed: () {},
            tooltip: AppStrings.of(context).tr('Synchroniser', 'Sync'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterRow(),

          // Document list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _errorState()
                    : _filtered.isEmpty
                        ? _emptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _buildDocCard(_filtered[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final strings = AppStrings.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          _filterChip(null, strings.tr('Tous', 'All')),
          ...DocumentType.values
              .map((t) => _filterChip(t, _localizedDocTypeLabel(t))),
        ],
      ),
    );
  }

  Widget _filterChip(DocumentType? type, String label) {
    final active = _filter == type;
    final color = type?.color ?? AppColors.primary;
    return GestureDetector(
      onTap: () => setState(() => _filter = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDocCard(Map<String, dynamic> doc) {
    final type = _mapType(doc['type'] as String? ?? '');
    final color = _typeColor(type);
    final icon = _typeIcon(type);
    final label = _typeLabel(type);
    final issueDate = DateTime.tryParse(doc['issue_date'] as String? ?? '');
    final shortId = (doc['id'] as String? ?? '').substring(0, 8).toUpperCase();

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
            // Top colored bar
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
                            Icon(icon, size: 12, color: color),
                            const SizedBox(width: 4),
                            Text(
                              label,
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
                          Icons.calendar_today_rounded,
                          issueDate == null
                              ? '—'
                              : '${issueDate.day}/${issueDate.month}/${issueDate.year}'),
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

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error ?? '',
          textAlign: TextAlign.center,
          style:
              GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  DocumentType? _mapType(String value) {
    switch (value.toLowerCase()) {
      case 'diploma':
        return DocumentType.diploma;
      case 'transcript':
        return DocumentType.transcript;
      case 'certificate':
        return DocumentType.certificate;
      case 'attestation':
        return DocumentType.attestation;
      default:
        return null;
    }
  }

  String _typeLabel(DocumentType? type) => _localizedDocTypeLabel(type);

  String _localizedDocTypeLabel(DocumentType? type) {
    if (type == null) return 'Document';
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

  Color _typeColor(DocumentType? type) => type?.color ?? AppColors.primary;

  IconData _typeIcon(DocumentType? type) =>
      type?.icon ?? Icons.description_rounded;

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

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open_rounded,
              size: 60, color: AppColors.border),
          const SizedBox(height: 16),
          Text(
            AppStrings.of(context).tr('Aucun document', 'No documents'),
            style: GoogleFonts.dmSans(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}
