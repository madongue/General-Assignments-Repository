import 'package:flutter/material.dart';
import 'nfc_screen_v2.dart' as real;

// Legacy import path kept for compatibility.
// Any caller using this file now gets the real NFC implementation.
class NfcScreen extends StatelessWidget {
  const NfcScreen({super.key});

  @override
  Widget build(BuildContext context) => const real.NfcScreen();
}
