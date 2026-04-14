import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../l10n/app_strings.dart';

// ── Models ────────────────────────────────────────────────────────────────────

enum DocumentType { diploma, transcript, certificate, attestation }

extension DocTypeExt on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.diploma:
        return 'Diploma';
      case DocumentType.transcript:
        return 'Transcript';
      case DocumentType.certificate:
        return 'Certificate';
      case DocumentType.attestation:
        return 'Attestation';
    }
  }

  String get apiValue {
    switch (this) {
      case DocumentType.diploma:
        return 'diploma';
      case DocumentType.transcript:
        return 'transcript';
      case DocumentType.certificate:
        return 'certificate';
      case DocumentType.attestation:
        return 'attestation';
    }
  }
}

class DocumentSummary {
  final String id;
  final String title;
  final DocumentType type;
  final String university;
  final String mention;
  final String issueDate;
  final bool isVerified;
  final String hashSha256;

  DocumentSummary.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['title'] as String,
        type = _parseType(j['type'] as String),
        university = j['university_name'] as String,
        mention = j['mention'] as String? ?? '',
        issueDate = j['issue_date'] as String,
        isVerified = j['is_verified'] as bool? ?? false,
        hashSha256 = j['hash_sha256'] as String;

  static DocumentType _parseType(String s) => DocumentType.values.firstWhere(
        (t) => t.apiValue == s,
        orElse: () => DocumentType.certificate,
      );
}

// ── Search API ────────────────────────────────────────────────────────────────

class DocumentSearchService {
  final _client = ApiClient();

  Future<List<DocumentSummary>> search({
    String? query,
    DocumentType? type,
    String? year,
    String? mention,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (query != null && query.isNotEmpty) 'q': query,
        if (type != null) 'type': type.apiValue,
        if (year != null && year.isNotEmpty) 'year': year,
        if (mention != null && mention.isNotEmpty) 'mention': mention,
      };
      final response = await _client.dio.get(
        '/documents/search',
        queryParameters: params,
      );
      final items =
          (response.data['items'] as List).cast<Map<String, dynamic>>();
      return items.map(DocumentSummary.fromJson).toList();
    } catch (_) {
      return [];
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

class SearchState {
  final List<DocumentSummary> results;
  final bool isLoading;
  final bool hasSearched;
  final String? error;
  SearchState({
    this.results = const [],
    this.isLoading = false,
    this.hasSearched = false,
    this.error,
  });
  SearchState copyWith({
    List<DocumentSummary>? results,
    bool? isLoading,
    bool? hasSearched,
    String? error,
  }) =>
      SearchState(
        results: results ?? this.results,
        isLoading: isLoading ?? this.isLoading,
        hasSearched: hasSearched ?? this.hasSearched,
        error: error ?? this.error,
      );
}

class SearchNotifier extends StateNotifier<SearchState> {
  final _svc = DocumentSearchService();
  SearchNotifier() : super(SearchState());

  String _query = '';
  DocumentType? _type;
  String? _year;
  String? _mention;

  Future<void> search({
    String? query,
    DocumentType? type,
    String? year,
    String? mention,
  }) async {
    _query = query ?? _query;
    _type = type ?? _type;
    _year = year ?? _year;
    _mention = mention ?? _mention;

    state = state.copyWith(isLoading: true, hasSearched: true, error: null);
    final results = await _svc.search(
      query: _query.isEmpty ? null : _query,
      type: _type,
      year: _year,
      mention: _mention,
    );
    state = state.copyWith(results: results, isLoading: false);
  }

  void reset() {
    _query = '';
    _type = null;
    _year = null;
    _mention = null;
    state = SearchState();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>(
    (ref) => SearchNotifier());

// ── UI ────────────────────────────────────────────────────────────────────────

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);
const _textHint = Color(0xFFAAAAAA);

final _typeColors = {
  DocumentType.diploma: const Color(0xFF0F6E56),
  DocumentType.transcript: const Color(0xFF185FA5),
  DocumentType.certificate: const Color(0xFFBA7517),
  DocumentType.attestation: const Color(0xFF7F77DD),
};

class DocumentSearchScreen extends ConsumerStatefulWidget {
  const DocumentSearchScreen({super.key});
  @override
  ConsumerState<DocumentSearchScreen> createState() => _SearchState();
}

class _SearchState extends ConsumerState<DocumentSearchScreen> {
  final _queryCtrl = TextEditingController();
  DocumentType? _selectedType;
  String? _selectedYear;
  String? _selectedMention;

  final _years = List.generate(
    10,
    (i) => (DateTime.now().year - i).toString(),
  );
  final _mentions = ['', 'Très Bien', 'Bien', 'Assez Bien', 'Passable'];

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _doSearch() => ref.read(searchProvider.notifier).search(
        query: _queryCtrl.text.trim(),
        type: _selectedType,
        year: _selectedYear,
        mention: _selectedMention,
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          onPressed: () => context.go('/home'),
          color: _textPri,
        ),
        title: Text(
          AppStrings.of(context)
              .tr('Recherche de documents', 'Document search'),
          style: GoogleFonts.instrumentSerif(
            fontSize: 20,
            color: _textPri,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilters(),
          const Divider(height: 1, color: _border),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(color: _green))
                : !state.hasSearched
                    ? _buildHint()
                    : state.results.isEmpty
                        ? _buildEmpty()
                        : _buildResults(state.results),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _queryCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _doSearch(),
                decoration: InputDecoration(
                  hintText: AppStrings.of(context).tr(
                      'Rechercher par titre, domaine, diplôme...',
                      'Search by title, field, degree...'),
                  hintStyle: GoogleFonts.dmSans(color: _textHint, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _textHint, size: 20),
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _green, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                minimumSize: const Size(52, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              onPressed: _doSearch,
              child: const Icon(Icons.search_rounded, size: 22),
            ),
          ],
        ),
      );

  Widget _buildFilters() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(
          children: [
            // Type filter
            _FilterChip(
              label: _getLocalizedTypeLabel(_selectedType) ??
                  AppStrings.of(context).tr('Tous les types', 'All types'),
              active: _selectedType != null,
              onTap: () => _showTypeSheet(),
            ),
            const SizedBox(width: 8),
            // Year filter
            _FilterChip(
              label: _selectedYear ??
                  AppStrings.of(context).tr('Toute année', 'Any year'),
              active: _selectedYear != null,
              onTap: () => _showYearSheet(),
            ),
            const SizedBox(width: 8),
            // Mention filter
            _FilterChip(
              label: (_selectedMention?.isEmpty ?? true)
                  ? AppStrings.of(context).tr('Toute mention', 'Any mention')
                  : _selectedMention!,
              active: _selectedMention != null && _selectedMention!.isNotEmpty,
              onTap: () => _showMentionSheet(),
            ),
            if (_selectedType != null ||
                _selectedYear != null ||
                (_selectedMention?.isNotEmpty ?? false)) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedType = null;
                    _selectedYear = null;
                    _selectedMention = null;
                  });
                  ref.read(searchProvider.notifier).reset();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    AppStrings.of(context)
                        .tr('Effacer les filtres', 'Clear filters'),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  String? _getLocalizedTypeLabel(DocumentType? type) {
    if (type == null) return null;
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

  void _showTypeSheet() => showModalBottomSheet(
        context: context,
        builder: (_) => _PickerSheet(
          title: AppStrings.of(context).tr('Type de document', 'Document type'),
          items: [
            AppStrings.of(context).tr('Tous', 'All'),
            ...DocumentType.values.map((t) => _getLocalizedTypeLabel(t) ?? ''),
          ],
          onSelect: (v) {
            setState(() {
              _selectedType = (v == AppStrings.of(context).tr('Tous', 'All'))
                  ? null
                  : DocumentType.values.firstWhere(
                      (t) => _getLocalizedTypeLabel(t) == v,
                    );
            });
            _doSearch();
          },
        ),
      );

  void _showYearSheet() => showModalBottomSheet(
        context: context,
        builder: (_) => _PickerSheet(
          title: AppStrings.of(context).tr('Année', 'Year'),
          items: [AppStrings.of(context).tr('Toute', 'Any'), ..._years],
          onSelect: (v) {
            setState(() => _selectedYear =
                (v == AppStrings.of(context).tr('Toute', 'Any')) ? null : v);
            _doSearch();
          },
        ),
      );

  void _showMentionSheet() => showModalBottomSheet(
        context: context,
        builder: (_) => _PickerSheet(
          title: AppStrings.of(context).tr('Mention', 'Mention'),
          items: [
            AppStrings.of(context).tr('Toute', 'Any'),
            AppStrings.of(context).tr('Très Bien', 'Very Good'),
            AppStrings.of(context).tr('Bien', 'Good'),
            AppStrings.of(context).tr('Assez Bien', 'Fairly Good'),
            AppStrings.of(context).tr('Passable', 'Satisfactory')
          ],
          onSelect: (v) {
            setState(() => _selectedMention =
                (v == AppStrings.of(context).tr('Toute', 'Any')) ? null : v);
            _doSearch();
          },
        ),
      );

  Widget _buildHint() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_rounded, size: 56, color: _border),
            const SizedBox(height: 16),
            Text(
              AppStrings.of(context)
                  .tr('Recherchez vos documents', 'Search your documents'),
              style: GoogleFonts.instrumentSerif(fontSize: 22, color: _textPri),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.of(context).tr(
                  'Recherchez par titre, domaine ou utilisez les filtres\npour trouver un document spécifique.',
                  'Search by title, field, or use filters\nto find a specific document.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: _textSec,
                fontWeight: FontWeight.w300,
                height: 1.6,
              ),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off_rounded, size: 56, color: _border),
            const SizedBox(height: 16),
            Text(
              AppStrings.of(context)
                  .tr('Aucun document trouvé', 'No documents found'),
              style: GoogleFonts.dmSans(
                fontSize: 16,
                color: _textSec,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.of(context).tr(
                  'Essayez d\'autres termes de recherche ou filtres.',
                  'Try different search terms or filters.'),
              style: GoogleFonts.dmSans(fontSize: 13, color: _textHint),
            ),
          ],
        ),
      );

  Widget _buildResults(List<DocumentSummary> docs) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,
        itemBuilder: (_, i) => _DocumentCard(
          doc: docs[i],
          onTap: () => context.go('/home/document/${docs[i].id}'),
        ),
      );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? _greenLight : _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? _green : _border,
              width: active ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: active ? _green : _textSec,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: active ? _green : _textHint,
              ),
            ],
          ),
        ),
      );
}

class _DocumentCard extends StatelessWidget {
  final DocumentSummary doc;
  final VoidCallback onTap;
  const _DocumentCard({required this.doc, required this.onTap});

  Color get _color => _typeColors[doc.type] ?? _green;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon, color: _color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _textPri,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doc.university} · ${doc.issueDate.substring(0, 4)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: _textSec,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    if (doc.mention.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          doc.mention,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: _color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (doc.isVerified)
                const Icon(Icons.verified_rounded, size: 18, color: _green),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: _textHint),
            ],
          ),
        ),
      );

  IconData get _typeIcon {
    switch (doc.type) {
      case DocumentType.diploma:
        return Icons.school_rounded;
      case DocumentType.transcript:
        return Icons.description_rounded;
      case DocumentType.certificate:
        return Icons.verified_rounded;
      case DocumentType.attestation:
        return Icons.assignment_rounded;
    }
  }
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<String> items;
  final void Function(String) onSelect;
  const _PickerSheet(
      {required this.title, required this.items, required this.onSelect});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _textPri,
                ),
              ),
              const SizedBox(height: 12),
              ...items.map((item) => ListTile(
                    title: Text(item, style: GoogleFonts.dmSans(fontSize: 14)),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(item);
                    },
                  )),
            ],
          ),
        ),
      );
}
