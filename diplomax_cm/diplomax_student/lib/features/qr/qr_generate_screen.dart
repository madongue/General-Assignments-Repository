// ─── QR Generate Screen ──────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/api/student_documents_api.dart';
import '../../l10n/app_strings.dart';

class QrGenerateScreen extends StatefulWidget {
  const QrGenerateScreen({super.key});
  @override
  State<QrGenerateScreen> createState() => _QrGenerateState();
}

class _QrGenerateState extends State<QrGenerateScreen> {
  final _api = StudentDocumentsApi.instance;
  Map<String, dynamic>? _selected;
  List<Map<String, dynamic>> _docs = const [];
  bool _loading = true;
  String? _error;
  int _validity = 24;
  bool _zkpMode = false;

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

  String get _qrData => _selected == null
      ? 'diplomax://select-document'
      : 'diplomax://verify/${_selected!['id']}?ttl=${_validity}h&zkp=$_zkpMode&hash=${_hashPrefix(_selected!)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/home')),
        title: Text(
            AppStrings.of(context).tr('Generer un QR Code', 'Generate QR code'),
            style: GoogleFonts.instrumentSerif(fontSize: 20)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document selector
            Text(
                AppStrings.of(context)
                    .tr('Selectionner un document', 'Select a document'),
                style: _label()),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!,
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: AppColors.textSecondary)),
              )
            else
              ..._docs.map((d) => _docTile(d)),
            const SizedBox(height: 24),

            // Options
            if (_selected != null) ...[
              Text(
                  AppStrings.of(context)
                      .tr('Options de partage', 'Share options'),
                  style: _label()),
              const SizedBox(height: 12),
              _optionCard(),
              const SizedBox(height: 24),
            ],

            // QR Code
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: _qrData,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    foregroundColor: _selected != null
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                  const SizedBox(height: 16),
                  if (_selected == null)
                    Text(
                        AppStrings.of(context).tr(
                            'Selectionnez un document', 'Select a document'),
                        style: GoogleFonts.dmSans(
                            color: AppColors.textHint, fontSize: 13))
                  else ...[
                    Text(_selected!['title'] as String? ?? '',
                        style: GoogleFonts.dmSans(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                        '${AppStrings.of(context).tr('Valide', 'Valid')} ${_validity}h · ${_zkpMode ? AppStrings.of(context).tr('Mode ZKP', 'ZKP mode') : AppStrings.of(context).tr('Mode standard', 'Standard mode')}',
                        style: GoogleFonts.dmSans(
                            color: AppColors.textHint, fontSize: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_selected != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(AppStrings.of(context)
                    .tr('Partager ce QR Code', 'Share this QR code')),
                onPressed: () {},
              ),
          ],
        ),
      ),
    );
  }

  Widget _docTile(Map<String, dynamic> d) {
    final selected = _selected?['id'] == d['id'];
    final type = _typeValue(d['type'] as String? ?? 'attestation');
    return GestureDetector(
      onTap: () => setState(() => _selected = d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 0.5),
        ),
        child: Row(
          children: [
            Icon(_typeIcon(type), color: _typeColor(type), size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(d['title'] as String? ?? '',
                    style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w400))),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _optionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Validity
          Row(
            children: [
              Text(AppStrings.of(context).tr('Validite', 'Validity'),
                  style: GoogleFonts.dmSans(fontSize: 13)),
              const Spacer(),
              ...[12, 24, 48].map((h) => GestureDetector(
                    onTap: () => setState(() => _validity = h),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _validity == h
                            ? AppColors.primary
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${h}h',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _validity == h
                                ? Colors.white
                                : AppColors.textSecondary,
                          )),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          // ZKP toggle
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      AppStrings.of(context)
                          .tr('Mode Zero-Knowledge', 'Zero-Knowledge mode'),
                      style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w400)),
                  Text(
                      AppStrings.of(context).tr(
                          'Partager uniquement la mention',
                          'Share mention only'),
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: AppColors.textHint)),
                ],
              ),
              const Spacer(),
              Switch(
                value: _zkpMode,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _zkpMode = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _label() => GoogleFonts.dmSans(
      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary);

  String _hashPrefix(Map<String, dynamic> doc) {
    final hash = doc['hash_sha256'] as String? ?? '';
    return hash.length >= 20 ? hash.substring(0, 20) : hash;
  }

  String _typeValue(String value) => value.toLowerCase();

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
}
