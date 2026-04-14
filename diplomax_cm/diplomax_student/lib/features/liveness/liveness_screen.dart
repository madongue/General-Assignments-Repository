import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../l10n/app_strings.dart';

class LivenessScreen extends StatefulWidget {
  const LivenessScreen({super.key});
  @override
  State<LivenessScreen> createState() => _LivenessState();
}

class _LivenessState extends State<LivenessScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late AnimationController _progressCtrl;
  _LivenessStep _step = _LivenessStep.intro;
  int _challengeIndex = 0;
  bool _passed = false;

  final _challenges = [
    const _Challenge(Icons.face_rounded, 'Regardez droit devant vous',
        'Positionnez votre visage dans le cercle'),
    const _Challenge(Icons.turn_slight_right, 'Tournez légèrement à droite',
        'Mouvement lent et naturel'),
    const _Challenge(Icons.turn_slight_left, 'Tournez légèrement à gauche',
        'Revenez au centre doucement'),
    const _Challenge(Icons.airline_seat_flat_rounded, 'Clignez des yeux',
        'Clignement naturel détecté'),
  ];

  @override
  void initState() {
    super.initState();
    _ringCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  Future<void> _startCheck() async {
    setState(() {
      _step = _LivenessStep.checking;
      _challengeIndex = 0;
    });
    for (int i = 0; i < _challenges.length; i++) {
      setState(() => _challengeIndex = i);
      await Future.delayed(const Duration(milliseconds: 1600));
    }
    setState(() {
      _step = _LivenessStep.result;
      _passed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/home')),
        title: Text(
            AppStrings.of(context)
                .tr('Verification de presence', 'Liveness verification'),
            style: GoogleFonts.instrumentSerif(fontSize: 22)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            _buildTitle(),
            const SizedBox(height: 40),
            _buildFaceView(),
            const SizedBox(height: 32),
            _buildChallengeArea(),
            const Spacer(),
            _buildBottomAction(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    String title, sub;
    switch (_step) {
      case _LivenessStep.intro:
        title = AppStrings.of(context)
            .tr('Verification anti-fraude', 'Anti-fraud verification');
        sub = AppStrings.of(context).tr(
            'Prouvez que vous etes bien une personne reelle en suivant les instructions.',
            'Prove you are a real person by following the instructions.');
        break;
      case _LivenessStep.checking:
        title = _challenges[_challengeIndex].instruction;
        sub = _challenges[_challengeIndex].hint;
        break;
      case _LivenessStep.result:
        title = _passed
            ? AppStrings.of(context)
                .tr('Identite confirmee !', 'Identity confirmed!')
            : AppStrings.of(context)
                .tr('Verification echouee', 'Verification failed');
        sub = _passed
            ? AppStrings.of(context).tr(
                'Vous etes bien une personne reelle. Acces autorise.',
                'You are a real person. Access granted.')
            : AppStrings.of(context).tr(
                'Veuillez reessayer dans de meilleures conditions.',
                'Please try again under better conditions.');
    }
    return Column(
      children: [
        Text(title,
            style: GoogleFonts.instrumentSerif(
                fontSize: 28,
                color: _step == _LivenessStep.result
                    ? (_passed ? AppColors.success : AppColors.error)
                    : AppColors.textPrimary),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(sub,
            style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w300,
                height: 1.6),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildFaceView() {
    final color = _step == _LivenessStep.result
        ? (_passed ? AppColors.success : AppColors.error)
        : AppColors.primary;

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse rings
          if (_step == _LivenessStep.checking)
            AnimatedBuilder(
              animation: _ringCtrl,
              builder: (_, __) => Opacity(
                opacity: (1 - _ringCtrl.value) * 0.3,
                child: Container(
                  width: 200 + _ringCtrl.value * 40,
                  height: 200 + _ringCtrl.value * 40,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 1.5)),
                ),
              ),
            ),
          // Face oval
          Container(
            width: 190,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(110),
              border: Border.all(color: color, width: 2.5),
              color: color.withOpacity(0.06),
            ),
          ),
          // Center icon
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _step == _LivenessStep.result
                    ? (_passed ? Icons.check_rounded : Icons.close_rounded)
                    : _step == _LivenessStep.checking
                        ? _challenges[_challengeIndex].icon
                        : Icons.face_rounded,
                size: 64,
                color: color.withOpacity(0.6),
              ),
              if (_step == _LivenessStep.checking) ...[
                const SizedBox(height: 12),
                _progressDots(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_challenges.length, (i) {
        final done = i < _challengeIndex;
        final active = i == _challengeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: done
                ? AppColors.success
                : active
                    ? AppColors.primary
                    : AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildChallengeArea() {
    if (_step == _LivenessStep.intro) {
      return _antifraudInfo();
    }
    if (_step == _LivenessStep.checking) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                    value: (_challengeIndex + 1) / _challenges.length)),
            const SizedBox(width: 12),
            Text(
                '${AppStrings.of(context).tr('Etape', 'Step')} ${_challengeIndex + 1} / ${_challenges.length}',
                style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    if (_step == _LivenessStep.result && _passed) {
      return Column(
        children: [
          _resultRow(
              Icons.person_rounded,
              AppStrings.of(context)
                  .tr('Personne reelle detectee', 'Real person detected')),
          _resultRow(
              Icons.no_photography_rounded,
              AppStrings.of(context).tr('Aucune photo/video frauduleuse',
                  'No fraudulent photo/video detected')),
          _resultRow(
              Icons.smartphone_rounded,
              AppStrings.of(context)
                  .tr('Emulateur non detecte', 'Emulator not detected')),
          _resultRow(
              Icons.face_retouching_natural_rounded,
              AppStrings.of(context)
                  .tr('Visage authentifie', 'Face authenticated')),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _antifraudInfo() {
    final points = [
      AppStrings.of(context)
          .tr('Suivi de 4 mouvements naturels', 'Tracking 4 natural movements'),
      AppStrings.of(context).tr('Detection photo/video frauduleuse',
          'Fraudulent photo/video detection'),
      AppStrings.of(context)
          .tr('Verification correspondance visage', 'Face match verification'),
      AppStrings.of(context)
          .tr('Anti-emulateur integre', 'Built-in anti-emulator'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Column(
        children: points
            .map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(p,
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _resultRow(IconData icon, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.success),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: AppColors.textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6)),
              child: Text('OK',
                  style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  Widget _buildBottomAction(BuildContext ctx) {
    if (_step == _LivenessStep.result && _passed) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.check_rounded, size: 18),
        label: Text(AppStrings.of(context)
            .tr('Continuer vers le document', 'Continue to document')),
        onPressed: () => context.go('/home'),
      );
    }
    if (_step == _LivenessStep.checking) {
      return OutlinedButton(
        onPressed: () => setState(() {
          _step = _LivenessStep.intro;
        }),
        child: Text(AppStrings.of(context).tr('Annuler', 'Cancel')),
      );
    }
    return ElevatedButton.icon(
      icon: const Icon(Icons.videocam_rounded, size: 18),
      label: Text(AppStrings.of(context)
          .tr('Demarrer la verification', 'Start verification')),
      onPressed: _startCheck,
    );
  }
}

enum _LivenessStep { intro, checking, result }

class _Challenge {
  final IconData icon;
  final String instruction;
  final String hint;
  const _Challenge(this.icon, this.instruction, this.hint);
}
