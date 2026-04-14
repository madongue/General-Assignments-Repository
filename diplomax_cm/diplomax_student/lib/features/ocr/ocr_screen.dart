// DIPLOMAX CM — Real OCR Screen using google_mlkit_text_recognition
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
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

enum _S { idle, processing, done, error }

Map<String, String> _parse(String text) {
  final f = <String, String>{};
  final mat = RegExp(r'(?:matricule|mat\.?)[:\s]*([A-Z0-9/\-]{6,20})',
          caseSensitive: false)
      .firstMatch(text);
  if (mat != null) f['matricule'] = mat.group(1)!.trim();
  final nm = RegExp(
          r'(?:nom|name|student)[:\s]+([A-ZÀ-Ÿa-zà-ÿ][A-ZÀ-Ÿa-zà-ÿ\s]{4,40})',
          caseSensitive: false)
      .firstMatch(text);
  if (nm != null) f['student_name'] = nm.group(1)!.trim();
  final mn =
      RegExp(r'(Très\s+Bien|Bien|Assez\s+Bien|Passable)', caseSensitive: false)
          .firstMatch(text);
  if (mn != null) f['mention'] = mn.group(1)!;
  final dg = RegExp(r'(licence|master|doctorat|bachelor|bts|dut)',
          caseSensitive: false)
      .firstMatch(text);
  if (dg != null) f['degree'] = dg.group(1)!;
  final yr = RegExp(r'\b(20\d{2})\b')
      .allMatches(text)
      .map((m) => m.group(1)!)
      .toSet()
      .toList()
    ..sort();
  if (yr.isNotEmpty) f['year'] = yr.last;
  return f;
}

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});
  @override
  State<OcrScreen> createState() => _OcrState();
}

class _OcrState extends State<OcrScreen> {
  final _rec = TextRecognizer(script: TextRecognitionScript.latin);
  final _pick = ImagePicker();
  _S _s = _S.idle;
  String _raw = '';
  Map<String, String> _ex = {};
  String? _err;
  File? _img;
  List<String> _steps = [];

  @override
  void dispose() {
    _rec.close();
    super.dispose();
  }

  Future<void> _camera() async {
    final ok = await Permission.camera.request();
    if (!ok.isGranted) {
      setState(() {
        _s = _S.error;
        _err = AppStrings.of(context)
            .tr('Permission camera refusee.', 'Camera permission denied.');
      });
      return;
    }
    final f =
        await _pick.pickImage(source: ImageSource.camera, imageQuality: 95);
    if (f != null) await _process(File(f.path));
  }

  Future<void> _gallery() async {
    final f =
        await _pick.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (f != null) await _process(File(f.path));
  }

  Future<void> _process(File f) async {
    setState(() {
      _s = _S.processing;
      _img = f;
      _steps = [];
      _raw = '';
      _ex = {};
      _err = null;
    });
    try {
      await _step(AppStrings.of(context)
          .tr('Chargement de l\'image...', 'Loading image...'));
      final input = InputImage.fromFile(f);
      await _step(AppStrings.of(context).tr(
          'Execution de ML Kit OCR (sur appareil)...',
          'Running ML Kit OCR (on-device)...'));
      final result = await _rec.processImage(input);
      await _step(AppStrings.of(context).tr(
          'Extraction des champs academiques...',
          'Extracting academic fields...'));
      final ex = _parse(result.text);
      await _step(AppStrings.of(context).tr(
          'Termine - ${ex.length} champs trouves',
          'Done - ${ex.length} fields found'));
      setState(() {
        _s = _S.done;
        _raw = result.text;
        _ex = ex;
      });
    } catch (e) {
      setState(() {
        _s = _S.error;
        _err = e.toString();
      });
    }
  }

  Future<void> _step(String s) async {
    setState(() => _steps.add(s));
    await Future.delayed(const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading:
              BackButton(onPressed: () => ctx.go('/home'), color: _textPri),
          title: Text(
              AppStrings.of(ctx)
                  .tr('Scanner un document (OCR)', 'Scan document (OCR)'),
              style:
                  GoogleFonts.instrumentSerif(fontSize: 20, color: _textPri))),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _banner(),
            const SizedBox(height: 18),
            _preview(),
            const SizedBox(height: 16),
            if (_s == _S.idle) _idle(),
            if (_s == _S.processing) _proc(),
            if (_s == _S.done) _done(ctx),
            if (_s == _S.error) _errW(ctx),
          ])));

  Widget _banner() => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _amberLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _amber.withOpacity(0.2))),
      child: Row(children: [
        const Icon(Icons.document_scanner_rounded, color: _amber, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(
                AppStrings.of(context).tr(
                    'Google ML Kit OCR - Sur appareil - Pas d\'internet requis',
                    'Google ML Kit OCR - On-device - No internet required'),
                style: GoogleFonts.dmSans(fontSize: 11, color: _amber)))
      ]));

  Widget _preview() => Container(
      height: 220,
      decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _s == _S.done ? _green : _border,
              width: _s == _S.done ? 2 : 0.5)),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: _img != null
              ? Image.file(_img!, fit: BoxFit.cover)
              : const Center(
                  child: Icon(Icons.document_scanner_rounded,
                      color: Colors.white24, size: 56))));

  Widget _idle() => Column(children: [
        _btn(AppStrings.of(context).tr('Prendre une photo', 'Take photo'),
            Icons.camera_alt_rounded, _camera),
        const SizedBox(height: 10),
        _out(
            AppStrings.of(context)
                .tr('Importer depuis la galerie', 'Import from gallery'),
            Icons.photo_library_rounded,
            _gallery)
      ]);

  Widget _proc() => Column(
      children: _steps
          .map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: _green)),
                const SizedBox(width: 12),
                Text(s,
                    style: GoogleFonts.dmSans(fontSize: 12, color: _textSec))
              ])))
          .toList());

  Widget _done(BuildContext ctx) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            AppStrings.of(context).tr('Extrait (${_ex.length} champs)',
                'Extracted (${_ex.length} fields)'),
            style:
                GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        Container(
            decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border)),
            child: Column(
                children: _ex.entries
                    .toList()
                    .asMap()
                    .entries
                    .map((e) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        color: e.key % 2 == 0
                            ? const Color(0xFFF9FCF9)
                            : Colors.transparent,
                        child: Row(children: [
                          SizedBox(
                              width: 110,
                              child: Text(e.value.key,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 11, color: _textSec))),
                          Expanded(
                              child: Text(e.value.value,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)))
                        ])))
                    .toList())),
        const SizedBox(height: 14),
        _btn(
            AppStrings.of(context)
                .tr('Enregistrer dans le coffre', 'Save to vault'),
            Icons.save_rounded, () {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Text(
                  AppStrings.of(context)
                      .tr('Enregistre dans le coffre', 'Saved to vault'),
                  style: GoogleFonts.dmSans()),
              backgroundColor: _green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))));
        }),
        const SizedBox(height: 8),
        _out(
            AppStrings.of(context).tr('Scanner un autre', 'Scan another'),
            Icons.camera_alt_rounded,
            () => setState(() {
                  _s = _S.idle;
                  _img = null;
                  _ex = {};
                  _raw = '';
                })),
      ]);

  Widget _errW(BuildContext ctx) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFFCEBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _red.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 18),
          const SizedBox(width: 8),
          Text(AppStrings.of(context).tr('Echec OCR', 'OCR failed'),
              style: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w500, color: _red))
        ]),
        const SizedBox(height: 6),
        Text(_err ?? '',
            style: GoogleFonts.dmSans(fontSize: 12, color: _red, height: 1.4)),
        const SizedBox(height: 12),
        _btn(
            AppStrings.of(context).tr('Reessayer', 'Try again'),
            Icons.refresh_rounded,
            () => setState(() {
                  _s = _S.idle;
                  _img = null;
                })),
      ]));

  Widget _btn(String l, IconData ic, VoidCallback fn) => ElevatedButton.icon(
      icon: Icon(ic, size: 16),
      label: Text(l),
      style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0),
      onPressed: fn);
  Widget _out(String l, IconData ic, VoidCallback fn) => OutlinedButton.icon(
      icon: Icon(ic, size: 16),
      label: Text(l),
      style: OutlinedButton.styleFrom(
          foregroundColor: _green,
          side: const BorderSide(color: _green),
          minimumSize: const Size(double.infinity, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      onPressed: fn);
}
