// DIPLOMAX CM — NFC Write Screen (University App)
// Real NFC write using nfc_manager package
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:dio/dio.dart';
import '../../l10n/app_strings.dart';

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _amber = Color(0xFFBA7517);
const _amberLight = Color(0xFFFAEEDA);
const _red = Color(0xFFA32D2D);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);

enum _WState { idle, checking, ready, writing, success, error }

NdefMessage _buildNdef(String documentId, String hash, String verifyUrl) {
  final uriRecord = NdefRecord.createUri(Uri.parse(verifyUrl));
  final textBytes = utf8
      .encode('DPLX:v2:${documentId.substring(0, 8)}:${hash.substring(0, 16)}');
  final langBytes = utf8.encode('en');
  final payload = Uint8List(1 + langBytes.length + textBytes.length);
  payload[0] = langBytes.length & 0x3F;
  payload.setAll(1, langBytes);
  payload.setAll(1 + langBytes.length, textBytes);
  final textRecord = NdefRecord(
      typeNameFormat: NdefTypeNameFormat.nfcWellknown,
      type: Uint8List.fromList([0x54]),
      identifier: Uint8List(0),
      payload: payload);
  return NdefMessage([uriRecord, textRecord]);
}

class NfcWriteScreen extends StatefulWidget {
  final String documentId, hashSha256, studentName, documentTitle;
  const NfcWriteScreen(
      {super.key,
      required this.documentId,
      required this.hashSha256,
      required this.studentName,
      required this.documentTitle});
  @override
  State<NfcWriteScreen> createState() => _NfcState();
}

class _NfcState extends State<NfcWriteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  _WState _state = _WState.idle;
  String? _errorMsg, _chipUid;
  bool _registered = false;

  late final String _url =
      'https://verify.diplomax.cm/nfc/${widget.documentId}';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _check();
  }

  @override
  void dispose() {
    _pulse.dispose();
    NfcManager.instance.stopSession();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() => _state = _WState.checking);
    final ok = await NfcManager.instance.isAvailable();
    setState(() {
      _state = ok ? _WState.ready : _WState.error;
      if (!ok)
        _errorMsg = AppStrings.of(context).tr(
            'NFC indisponible. Activez le NFC dans les parametres.',
            'NFC not available. Enable NFC in Settings.');
    });
  }

  Future<void> _write() async {
    setState(() {
      _state = _WState.writing;
      _errorMsg = null;
    });
    final msg = _buildNdef(widget.documentId, widget.hashSha256, _url);
    NfcManager.instance.startSession(
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            throw Exception(AppStrings.of(context).tr(
                'Tag non compatible NDEF. Utilisez NTAG213/215.',
                'Tag not NDEF compatible. Use NTAG213/215.'));
          }
          if (!ndef.isWritable) {
            throw Exception(AppStrings.of(context)
                .tr('La puce est en lecture seule.', 'Chip is read-only.'));
          }
          await ndef.write(msg);
          final id = tag.data['nfca']?['identifier'] as List<int>? ?? [];
          _chipUid = id
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
          await NfcManager.instance.stopSession();
          await _register(_chipUid!);
          setState(() => _state = _WState.success);
        } catch (e) {
          await NfcManager.instance.stopSession(errorMessage: e.toString());
          setState(() {
            _state = _WState.error;
            _errorMsg = e.toString();
          });
        }
      },
      onError: (e) async => setState(() {
        _state = _WState.error;
        _errorMsg = e.message;
      }),
    );
  }

  Future<void> _register(String uid) async {
    try {
      await Dio().post('/v1/nfc/register',
          data: {'document_id': widget.documentId, 'nfc_uid': uid});
      setState(() => _registered = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: BackButton(onPressed: () => ctx.pop(), color: _textPri),
            title: Text(
                AppStrings.of(ctx).tr('Ecrire une puce NFC', 'Write NFC chip'),
                style: GoogleFonts.instrumentSerif(
                    fontSize: 20, color: _textPri))),
        body: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              const Spacer(),
              Text(_title(),
                  style: GoogleFonts.instrumentSerif(
                      fontSize: 26, color: _titleColor()),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_subtitle(),
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: _textSec,
                      fontWeight: FontWeight.w300,
                      height: 1.6),
                  textAlign: TextAlign.center),
              const SizedBox(height: 48),
              _ring(),
              const SizedBox(height: 32),
              _status(),
              const Spacer(),
              _action(),
              const SizedBox(height: 20),
            ])),
      );

  Color _titleColor() {
    if (_state == _WState.success) return _green;
    if (_state == _WState.error) return _red;
    return _textPri;
  }

  String _title() {
    final strings = AppStrings.of(context);
    switch (_state) {
      case _WState.success:
        return strings.tr('Puce ecrite!', 'Chip written!');
      case _WState.error:
        return strings.tr('Echec de l\'ecriture', 'Write failed');
      case _WState.writing:
        return strings.tr('Approchez le diplome...', 'Bring diploma close...');
      default:
        return strings.tr('Ecrire une puce NFC', 'Write NFC chip');
    }
  }

  String _subtitle() {
    final strings = AppStrings.of(context);
    switch (_state) {
      case _WState.success:
        return strings.tr(
            'Le diplome porte maintenant sa propre identite cryptographique.',
            'Diploma now carries its own cryptographic identity.');
      case _WState.error:
        return _errorMsg ??
            strings.tr('Une erreur est survenue.', 'An error occurred.');
      case _WState.writing:
        return strings.tr(
            'Maintenez la puce NFC contre l\'arriere du telephone.',
            'Hold the NFC chip against the back of the phone.');
      default:
        return strings.tr(
            'Integrez l\'URL de verification et le hash dans la puce physique du diplome.',
            'Embed the verification URL and hash into the physical diploma chip.');
    }
  }

  Widget _ring() {
    final c = _state == _WState.success
        ? _green
        : _state == _WState.error
            ? _red
            : const Color(0xFF534AB7);
    return AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
              if (_state == _WState.writing)
                Transform.scale(
                    scale: 1 + _pulse.value * 0.12,
                    child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.withOpacity(0.06 * _pulse.value)))),
              Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.withOpacity(0.1),
                      border: Border.all(color: c, width: 2)),
                  child: Icon(
                      _state == _WState.success
                          ? Icons.check_rounded
                          : _state == _WState.error
                              ? Icons.close_rounded
                              : Icons.nfc_rounded,
                      size: 56,
                      color: c)),
            ]));
  }

  Widget _status() {
    final strings = AppStrings.of(context);
    if (_state == _WState.success) {
      return Column(children: [
        _row(
            Icons.check_rounded,
            strings.tr('NDEF ecrit sur la puce', 'NDEF written to chip'),
            _green),
        if (_chipUid != null)
          _row(Icons.tag_rounded,
              strings.tr('UID puce: $_chipUid', 'Chip UID: $_chipUid'), _green),
        _row(
            _registered ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            _registered
                ? strings.tr(
                    'Enregistre sur le backend', 'Registered on backend')
                : strings.tr('Enregistrement backend en attente',
                    'Backend registration pending'),
            _registered ? _green : _amber),
        const SizedBox(height: 12),
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _greenLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withOpacity(0.3))),
            child: Text(
                strings.tr('URL de verification: $_url', 'Verify URL: $_url'),
                style: GoogleFonts.dmSans(fontSize: 10, color: _green))),
      ]);
    }
    if (_state == _WState.writing) {
      return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _amberLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _amber.withOpacity(0.3))),
          child: Row(children: [
            const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(color: _amber, strokeWidth: 2)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    strings.tr('En attente d\'un tag NFC...',
                        'Waiting for NFC tag...'),
                    style: GoogleFonts.dmSans(fontSize: 12, color: _amber))),
          ]));
    }
    return const SizedBox.shrink();
  }

  Widget _row(IconData ic, String t, Color c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(ic, size: 15, color: c),
        const SizedBox(width: 8),
        Expanded(child: Text(t, style: GoogleFonts.dmSans(fontSize: 12)))
      ]));

  Widget _action() {
    final strings = AppStrings.of(context);
    switch (_state) {
      case _WState.checking:
        return const Center(child: CircularProgressIndicator(color: _green));
      case _WState.ready:
        return _btn(strings.tr('Ecrire sur la puce NFC', 'Write to NFC chip'),
            Icons.nfc_rounded, _write);
      case _WState.writing:
        return _outBtn(strings.tr('Annuler', 'Cancel'), () {
          NfcManager.instance.stopSession();
          setState(() => _state = _WState.ready);
        });
      case _WState.success:
        return Column(children: [
          _btn(strings.tr('Termine', 'Done'), Icons.check_rounded,
              () => context.pop()),
          const SizedBox(height: 8),
          TextButton(
              onPressed: () => setState(() {
                    _state = _WState.ready;
                    _chipUid = null;
                    _registered = false;
                  }),
              child: Text(
                  strings.tr('Ecrire une autre puce', 'Write another chip'),
                  style: GoogleFonts.dmSans(color: _textSec, fontSize: 13)))
        ]);
      case _WState.error:
        return Column(children: [
          _btn(strings.tr('Reessayer', 'Try again'), Icons.refresh_rounded,
              _check),
          const SizedBox(height: 8),
          TextButton(
              onPressed: () => context.pop(),
              child: Text(strings.tr('Ignorer', 'Skip'),
                  style: GoogleFonts.dmSans(color: _textSec, fontSize: 13)))
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _btn(String l, IconData ic, VoidCallback fn) => ElevatedButton.icon(
      icon: Icon(ic, size: 18),
      label: Text(l),
      style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0),
      onPressed: fn);
  Widget _outBtn(String l, VoidCallback fn) => OutlinedButton(
      onPressed: fn,
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: _border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: Text(l, style: GoogleFonts.dmSans(color: _textSec)));
}
