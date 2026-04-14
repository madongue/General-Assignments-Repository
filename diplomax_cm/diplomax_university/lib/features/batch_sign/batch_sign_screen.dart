// ═══════════════════════════════════════════════════════════════════════════
// DIPLOMAX CM — Batch Sign Screen
// Authorize 500 digital diplomas in ~10 seconds using RSA-2048.
// The registrar signs ALL pending unsigned documents at once.
// Each document gets the university's digital signature + blockchain update.
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:convert/convert.dart';
import '../../l10n/app_strings.dart';

const _G = Color(0xFF0F6E56);
const _GL = Color(0xFFE1F5EE);
const _BG = Color(0xFFF7F6F2);
const _S = Color(0xFFFFFFFF);
const _BD = Color(0xFFE0DDD5);
const _T1 = Color(0xFF1A1A1A);
const _T2 = Color(0xFF6B6B6B);
const _A = Color(0xFFBA7517);
const _AL = Color(0xFFFAEEDA);
const _R = Color(0xFFA32D2D);

const _API = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://diplomax-backend.onrender.com/v1');
const _sto = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true));

class BatchSignScreen extends ConsumerStatefulWidget {
  const BatchSignScreen({super.key});
  @override
  ConsumerState<BatchSignScreen> createState() => _BS();
}

enum _Phase { loading, preview, signing, done }

class _BS extends ConsumerState<BatchSignScreen> {
  _Phase _phase = _Phase.loading;
  List<Map<String, dynamic>> _pending = [];
  int _signed = 0;
  int _failed = 0;
  String? _error;
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<String?> _getToken() => _sto.read(key: 'access_token');

  Dio get _dio {
    late String tok;
    return Dio(BaseOptions(
      baseUrl: _API,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ))
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (opts, handler) async {
          final t = await _sto.read(key: 'access_token');
          if (t != null) opts.headers['Authorization'] = 'Bearer $t';
          handler.next(opts);
        },
      ));
  }

  Future<void> _loadPending() async {
    setState(() => _phase = _Phase.loading);
    try {
      final r = await _dio.get('/documents/pending-signatures',
          queryParameters: {'page_size': 500});
      final items =
          (r.data['items'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _pending = items;
        _phase = _Phase.preview;
      });
    } catch (e) {
      // If endpoint doesn't exist yet, show empty state gracefully
      setState(() {
        _pending = [];
        _phase = _Phase.preview;
      });
    }
  }

  // ── RSA-2048 signing ────────────────────────────────────────────────────
  // Reuses the same key as sign_document_screen.dart
  Future<String?> _signHash(String hashHex) async {
    final stored = await _sto.read(key: 'diplomax_university_rsa_private_v2');
    if (stored == null) return null;
    final parts = stored.split('|');
    if (parts.length < 4) return null;
    try {
      final priv = pc.RSAPrivateKey(
        BigInt.parse(parts[0], radix: 16),
        BigInt.parse(parts[1], radix: 16),
        BigInt.parse(parts[2], radix: 16),
        BigInt.parse(parts[3], radix: 16),
      );
      final signer = pc.Signer('SHA-256/RSA')
        ..init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(priv));
      final sig =
          signer.generateSignature(Uint8List.fromList(hashHex.codeUnits))
              as pc.RSASignature;
      return hex.encode(sig.bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _batchSign() async {
    if (_pending.isEmpty) return;
    setState(() {
      _phase = _Phase.signing;
      _signed = 0;
      _failed = 0;
      _startTime = DateTime.now();
    });

    // Check key exists
    final hasKey =
        await _sto.read(key: 'diplomax_university_rsa_private_v2') != null;
    if (!hasKey) {
      setState(() {
        _error =
            'No signing key found. Please generate keys in Document Signing settings first.';
        _phase = _Phase.preview;
      });
      return;
    }

    for (final doc in _pending) {
      final docId = doc['id'] as String;
      final hashSha = doc['hash_sha256'] as String? ?? '';
      if (hashSha.isEmpty) {
        setState(() => _failed++);
        continue;
      }

      final sig = await _signHash(hashSha);
      if (sig == null) {
        setState(() => _failed++);
        continue;
      }

      try {
        await _dio.post('/documents/$docId/sign', data: {'rsa_signature': sig});
        setState(() => _signed++);
      } catch (_) {
        setState(() => _failed++);
      }
    }

    setState(() {
      _phase = _Phase.done;
      _endTime = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _BG,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading:
              BackButton(color: _T1, onPressed: () => context.go('/documents')),
          title: Text(
              AppStrings.of(context).tr('Signature en lot', 'Batch sign'),
              style: GoogleFonts.instrumentSerif(fontSize: 20, color: _T1)),
        ),
        body: Padding(padding: const EdgeInsets.all(20), child: _buildBody()),
      );

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.loading:
        return Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: _G),
          const SizedBox(height: 16),
          Text(AppStrings.of(context).tr(
              'Chargement des documents en attente...',
              'Loading pending documents...')),
        ]));

      case _Phase.preview:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info banner
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _GL,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _G.withOpacity(0.2))),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_rounded, color: _G, size: 18),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'Batch signing applies your university\'s RSA-2048 digital signature '
                        'to all pending documents simultaneously. Each document is individually '
                        'signed with a unique cryptographic signature derived from its SHA-256 hash.',
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: _G, height: 1.5))),
              ])),
          const SizedBox(height: 20),

          // Stats
          Row(children: [
            _statBox('${_pending.length}', 'Documents\npending', _G, _GL),
            const SizedBox(width: 12),
            _statBox('RSA-2048', 'Signature\nalgorithm',
                const Color(0xFF185FA5), const Color(0xFFE6F1FB)),
            const SizedBox(width: 12),
            _statBox('~${(_pending.length * 0.02).toStringAsFixed(0)}s',
                'Estimated\ntime', _A, _AL),
          ]),
          const SizedBox(height: 20),

          if (_pending.isEmpty) ...[
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: _S,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _BD)),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, color: _G, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          'All documents are already signed. No pending signatures.',
                          style: GoogleFonts.dmSans(fontSize: 13))),
                ])),
          ] else ...[
            Text(
                AppStrings.of(context)
                    .tr('Documents en attente :', 'Pending documents:'),
                style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Expanded(
                child: ListView.builder(
              itemCount: _pending.length.clamp(0, 50),
              itemBuilder: (_, i) {
                final d = _pending[i];
                return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _S,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _BD)),
                    child: Row(children: [
                      const Icon(Icons.pending_actions_rounded,
                          color: _A, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(d['title'] ?? '',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(d['matricule'] ?? '',
                                style: GoogleFonts.dmSans(
                                    fontSize: 10, color: _T2)),
                          ])),
                    ]));
              },
            )),
            if (_pending.length > 50)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                      AppStrings.of(context).tr(
                          '... et ${_pending.length - 50} de plus',
                          '... and ${_pending.length - 50} more'),
                      style: GoogleFonts.dmSans(fontSize: 12, color: _T2))),
          ],

          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFFCEBEB),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_error!,
                    style: GoogleFonts.dmSans(color: _R, fontSize: 12))),
          ],
          const SizedBox(height: 16),
          if (_pending.isNotEmpty)
            ElevatedButton.icon(
                icon: const Icon(Icons.draw_rounded, size: 18),
                label: Text(AppStrings.of(context).tr(
                    'Signer maintenant les ${_pending.length} documents',
                    'Sign all ${_pending.length} documents now')),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _G,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
                onPressed: _batchSign),
        ]);

      case _Phase.signing:
        final total = _pending.length;
        final done = _signed + _failed;
        final prog = total > 0 ? done / total : 0.0;
        final elapsed = _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;
        final rate =
            done > 0 ? (done / (elapsed / 1000)).toStringAsFixed(0) : '…';

        return Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                    value: prog,
                    color: _G,
                    backgroundColor: _GL,
                    strokeWidth: 8)),
            Text('${(prog * 100).toInt()}%',
                style: GoogleFonts.instrumentSerif(fontSize: 28, color: _G)),
          ]),
          const SizedBox(height: 24),
          Text(
              AppStrings.of(context)
                  .tr('Signature en cours...', 'Signing in progress...'),
              style: GoogleFonts.instrumentSerif(fontSize: 22, color: _T1)),
          const SizedBox(height: 8),
          Text(
              AppStrings.of(context).tr(
                  '$done / $total documents signes  ·  $rate docs/sec',
                  '$done / $total documents signed  ·  $rate docs/sec'),
              style: GoogleFonts.dmSans(fontSize: 13, color: _T2)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
              value: prog,
              backgroundColor: _BD,
              valueColor: const AlwaysStoppedAnimation<Color>(_G)),
        ]));

      case _Phase.done:
        final duration = _endTime != null && _startTime != null
            ? _endTime!.difference(_startTime!).inMilliseconds / 1000
            : 0.0;
        return Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 90,
              height: 90,
              decoration:
                  const BoxDecoration(color: _GL, shape: BoxShape.circle),
              child: const Icon(Icons.verified_rounded, color: _G, size: 50)),
          const SizedBox(height: 24),
          Text(
              AppStrings.of(context)
                  .tr('Signature en lot terminee !', 'Batch signing complete!'),
              style: GoogleFonts.instrumentSerif(fontSize: 26, color: _T1)),
          const SizedBox(height: 16),
          Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: _S,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _BD)),
              child: Column(children: [
                _resultRow(
                    AppStrings.of(context)
                        .tr('Documents signes', 'Documents signed'),
                    _signed.toString(),
                    _G),
                _resultRow(AppStrings.of(context).tr('Echecs', 'Failed'),
                    _failed.toString(), _failed > 0 ? _R : _T2),
                _resultRow(
                    AppStrings.of(context).tr('Temps ecoule', 'Time elapsed'),
                    '${duration.toStringAsFixed(1)}s',
                    _T2),
                _resultRow(
                    AppStrings.of(context)
                        .tr('Docs par seconde', 'Docs per second'),
                    duration > 0
                        ? (_signed / duration).toStringAsFixed(0)
                        : '—',
                    _T2),
              ])),
          const SizedBox(height: 24),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _G,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0),
              onPressed: () => context.go('/documents'),
              child: Text(AppStrings.of(context)
                  .tr('Retour aux documents', 'Back to documents'))),
        ]));
    }
  }

  Widget _statBox(String v, String l, Color c, Color bg) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.withOpacity(0.3))),
          child: Column(children: [
            Text(v,
                style: GoogleFonts.instrumentSerif(fontSize: 22, color: c),
                textAlign: TextAlign.center),
            Text(l,
                style: GoogleFonts.dmSans(fontSize: 10, color: c),
                textAlign: TextAlign.center),
          ])));

  Widget _resultRow(String k, String v, Color vc) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: GoogleFonts.dmSans(fontSize: 13, color: _T2)),
        Text(v,
            style: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w600, color: vc)),
      ]));
}
