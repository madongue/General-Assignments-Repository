import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../l10n/app_strings.dart';

class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  bool _scanning = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    setState(() {
      _scanning = true;
      _success = false;
    });
    await Future.delayed(const Duration(milliseconds: 1800));
    setState(() {
      _scanning = false;
      _success = true;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              Text(
                strings.tr(
                    'Vérification\nbiométrique', 'Biometric\nverification'),
                style: GoogleFonts.instrumentSerif(
                  fontSize: 36,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                  height: 1.15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                strings.tr(
                  'Placez votre doigt sur le capteur\npour accéder à votre coffre-fort.',
                  'Place your finger on the sensor\nto access your vault.',
                ),
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w300,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 60),

              // Fingerprint animation
              GestureDetector(
                onTap: _authenticate,
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) {
                    final pScale =
                        _scanning ? 1.0 + (_pulseCtrl.value * 0.08) : 1.0;
                    final color = _success
                        ? AppColors.success
                        : _scanning
                            ? AppColors.primary
                            : AppColors.primaryLight;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer pulse ring
                        if (_scanning)
                          Transform.scale(
                            scale: pScale,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary
                                    .withOpacity(0.1 * _pulseCtrl.value),
                              ),
                            ),
                          ),
                        // Main circle
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: _success
                                  ? AppColors.success
                                  : AppColors.primary,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _success
                                ? Icons.check_rounded
                                : Icons.fingerprint_rounded,
                            size: 64,
                            color: _success ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _success
                    ? Text(
                        strings.tr(
                            'Identité vérifiée ✓', 'Identity verified ✓'),
                        key: const ValueKey('success'),
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.success,
                        ),
                      )
                    : _scanning
                        ? Text(
                            strings.tr('Vérification en cours...',
                                'Verification in progress...'),
                            key: const ValueKey('scanning'),
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w300,
                            ),
                          )
                        : Text(
                            strings.tr('Appuyez sur le capteur pour commencer',
                                'Tap the sensor to start'),
                            key: const ValueKey('idle'),
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: AppColors.textHint,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
              ),

              const Spacer(),

              // Face ID alt
              TextButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.face_rounded,
                    size: 18, color: AppColors.primary),
                label: Text(
                  strings.tr('Utiliser la reconnaissance faciale',
                      'Use face recognition'),
                  style: GoogleFonts.dmSans(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(
                  strings.tr('Continuer avec le mot de passe',
                      'Continue with password'),
                  style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
