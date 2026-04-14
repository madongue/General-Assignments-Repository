import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/biometric_screen.dart';
import 'features/auth/screens/first_login_screen.dart';
import 'features/home_screen.dart';
import 'features/vault/vault_screen.dart';
import 'features/vault/document_detail_screen.dart';
import 'features/search/screens/search_screen.dart';
import 'features/qr/qr_generate_screen.dart';
import 'features/qr/qr_scan_screen.dart';
import 'features/nfc/nfc_screen_v2.dart';
import 'features/ocr/ocr_screen_v2.dart';
import 'features/liveness/liveness_screen.dart';
import 'features/share/screens/share_document_screen.dart';
import 'features/payment/payment_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/international_share/international_share_screen.dart';
import 'features/requests/document_request_screen.dart';
import 'l10n/app_locale_controller.dart';
import 'l10n/app_strings.dart';
import 'l10n/language_toggle.dart';

const _green = Color(0xFF0F6E56);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/first-login', builder: (_, __) => const FirstLoginScreen()),
    GoRoute(path: '/biometric', builder: (_, __) => const BiometricScreen()),
    GoRoute(
      path: '/home',
      builder: (_, __) => const HomeScreen(),
      routes: [
        GoRoute(path: 'vault', builder: (_, __) => const VaultScreen()),
        GoRoute(
            path: 'document/:id',
            builder: (_, s) =>
                DocumentDetailScreen(documentId: s.pathParameters['id']!)),
        GoRoute(
            path: 'search', builder: (_, __) => const DocumentSearchScreen()),
        GoRoute(
            path: 'qr-generate', builder: (_, __) => const QrGenerateScreen()),
        GoRoute(path: 'qr-scan', builder: (_, __) => const QrScanScreen()),
        GoRoute(path: 'nfc', builder: (_, __) => const NfcScreen()),
        GoRoute(path: 'ocr', builder: (_, __) => const OcrScreen()),
        GoRoute(path: 'liveness', builder: (_, __) => const LivenessScreen()),
        GoRoute(
            path: 'share/:documentId',
            builder: (_, s) => ShareDocumentScreen(
                  documentId: s.pathParameters['documentId']!,
                  documentTitle: s.uri.queryParameters['title'] ?? '',
                  mention: s.uri.queryParameters['mention'] ?? '',
                )),
        GoRoute(path: 'payment', builder: (_, __) => const PaymentScreen()),
        GoRoute(
            path: 'payment/:product',
            builder: (_, s) =>
                PaymentScreen(initialProduct: s.pathParameters['product'])),
        GoRoute(path: 'profile', builder: (_, __) => const ProfileScreen()),
        GoRoute(
            path: 'international-share',
            builder: (_, __) => const InternationalShareScreen(
                documentIds: [], documentTitles: [])),
        GoRoute(
            path: 'request', builder: (_, __) => const DocumentRequestScreen()),
      ],
    ),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  final localeController = AppLocaleController();
  await localeController.load();
  runApp(ProviderScope(
    overrides: [
      appLocaleControllerProvider.overrideWith((ref) => localeController)
    ],
    child: const DiplomaxStudentApp(),
  ));
}

class DiplomaxStudentApp extends ConsumerWidget {
  const DiplomaxStudentApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appLocaleControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppStrings.of(context).appName,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      locale: controller.locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: AppStrings.localizationsDelegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: _green,
            primary: _green,
            surface: _surface,
            background: _bg),
        textTheme: GoogleFonts.dmSansTextTheme(),
        appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(color: Color(0xFF1A1A1A))),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        )),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _green, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SS();
}

class _SS extends State<_SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _f;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _f = CurvedAnimation(parent: _c, curve: Curves.easeIn);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _green,
        body: FadeTransition(
          opacity: _f,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24)),
                    child: const Icon(Icons.school_rounded,
                        color: Colors.white, size: 50)),
                const SizedBox(height: 24),
                Text(AppStrings.of(context).appName,
                    style: GoogleFonts.instrumentSerif(
                        fontSize: 36, color: Colors.white)),
                const SizedBox(height: 8),
                Text(AppStrings.of(context).secureAcademicCredentials,
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w300)),
                const SizedBox(height: 28),
                const LanguageToggleButton(compact: true),
                const SizedBox(height: 10),
                Text(AppStrings.of(context).switchLanguageHint,
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: Colors.white70)),
                const SizedBox(height: 18),
                SizedBox(
                  width: 220,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _green,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => context.go('/login'),
                    child: Text(
                      AppStrings.of(context).continueToSignIn,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
