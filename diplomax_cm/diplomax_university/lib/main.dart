import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/students/screens/students_screen.dart';
import 'features/documents/screens/documents_screen.dart';
import 'features/issuance/screens/sign_document_screen.dart';
import 'features/document_input/document_input_hub.dart';
import 'features/document_input/form/manual_form_screen.dart';
import 'features/document_input/pdf_scan/pdf_scan_screen.dart';
import 'features/document_input/csv_import/csv_import_screen.dart';
import 'features/document_input/photo_scan/photo_scan_screen.dart';
import 'features/document_input/template/template_fill_screen.dart';
import 'features/requests/requests_review_screen.dart';
import 'features/onboarding/institution_onboarding_screen.dart';
import 'features/batch_sign/batch_sign_screen.dart';
import 'features/ministry/ministry_dashboard_screen.dart';
import 'l10n/app_locale_controller.dart';
import 'l10n/app_strings.dart';
import 'l10n/language_toggle.dart';

const _G = Color(0xFF0F6E56);
const _GL = Color(0xFFE1F5EE);
const _BG = Color(0xFFF7F6F2);
const _SUR = Color(0xFFFFFFFF);
const _BD = Color(0xFFE0DDD5);
const _T1 = Color(0xFF1A1A1A);
const _T2 = Color(0xFF6B6B6B);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final localeController = AppLocaleController();
  await localeController.load();
  runApp(ProviderScope(
    overrides: [
      appLocaleControllerProvider.overrideWith((ref) => localeController)
    ],
    child: const DiplomaxUniversityApp(),
  ));
}

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const UniversityLoginScreen()),
    GoRoute(
        path: '/register',
        builder: (_, __) => const InstitutionOnboardingScreen()),
    ShellRoute(
      builder: (ctx, state, child) => _Shell(child: child),
      routes: [
        GoRoute(
            path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(
            path: '/ministry',
            builder: (_, __) => const MinistryDashboardScreen()),
        GoRoute(
            path: '/students',
            builder: (_, __) => const StudentsScreen(),
            routes: [
              GoRoute(
                  path: ':id',
                  builder: (_, s) =>
                      StudentDetailScreen(id: s.pathParameters['id']!))
            ]),
        GoRoute(
            path: '/documents',
            builder: (_, __) => const UnivDocumentsScreen(),
            routes: [
              GoRoute(
                  path: ':id',
                  builder: (_, s) =>
                      UnivDocDetailScreen(id: s.pathParameters['id']!))
            ]),
        GoRoute(
            path: '/issue',
            builder: (_, __) => const DocumentInputHubScreen(),
            routes: [
              GoRoute(
                  path: 'form',
                  builder: (_, __) => const ManualDocumentFormScreen()),
              GoRoute(
                  path: 'pdf-scan', builder: (_, __) => const PdfScanScreen()),
              GoRoute(path: 'csv', builder: (_, __) => const CsvImportScreen()),
              GoRoute(
                  path: 'photo', builder: (_, __) => const PhotoScanScreen()),
              GoRoute(
                  path: 'template',
                  builder: (_, __) => const TemplateFillScreen()),
              GoRoute(
                  path: 'batch', builder: (_, __) => const BatchSignScreen()),
              GoRoute(
                  path: 'sign/:documentId',
                  builder: (_, s) => SignDocumentScreen(
                      documentId: s.pathParameters['documentId']!)),
            ]),
        GoRoute(
            path: '/requests',
            builder: (_, __) => const RequestsReviewScreen()),
      ],
    ),
  ],
);

class DiplomaxUniversityApp extends ConsumerWidget {
  const DiplomaxUniversityApp({super.key});
  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
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
            seedColor: _G, primary: _G, surface: _SUR, background: _BG),
        textTheme: GoogleFonts.dmSansTextTheme(),
        appBarTheme: AppBarTheme(
            backgroundColor: _SUR,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: _T1),
            titleTextStyle:
                GoogleFonts.instrumentSerif(fontSize: 20, color: _T1)),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                backgroundColor: _G,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0)),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _SUR,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _BD)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _BD)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _G, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  final Widget child;
  const _Shell({required this.child});
  @override
  Widget build(BuildContext ctx) => MediaQuery.of(ctx).size.width > 800
      ? _Desktop(child: child)
      : _Mobile(child: child);
}

class _Desktop extends StatelessWidget {
  final Widget child;
  const _Desktop({required this.child});
  @override
  Widget build(BuildContext ctx) {
    final strings = AppStrings.of(ctx);
    final items = [
      _N('/dashboard', Icons.dashboard_rounded, strings.dashboard),
      _N('/students', Icons.people_rounded, strings.students),
      _N('/documents', Icons.folder_rounded, strings.documents),
      _N('/issue', Icons.add_circle_outline_rounded, strings.issueDocument),
      _N('/requests', Icons.inbox_rounded, strings.requests),
      _N('/ministry', Icons.account_balance_rounded, strings.ministry),
    ];

    return Scaffold(
      body: Row(children: [
        Container(
          width: 220,
          color: _SUR,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: _G, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.school_rounded,
                        color: Colors.white, size: 20)),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Diplomax',
                      style: GoogleFonts.instrumentSerif(
                          fontSize: 15, color: _T1)),
                  Text(strings.isFrench ? 'Université' : 'University',
                      style: GoogleFonts.dmSans(fontSize: 10, color: _T2))
                ]),
              ]),
            ),
            const SizedBox(height: 28),
            ...items.map((item) {
              final path = GoRouterState.of(ctx).uri.toString();
              final active = path.startsWith(item.path);
              return InkWell(
                onTap: () => ctx.go(item.path),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.fromLTRB(12, 2, 12, 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: active ? _GL : Colors.transparent,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(item.icon, size: 18, color: active ? _G : _T2),
                    const SizedBox(width: 10),
                    Text(item.label,
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight:
                                active ? FontWeight.w500 : FontWeight.w400,
                            color: active ? _G : _T2))
                  ]),
                ),
              );
            }),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: LanguageToggleButton(compact: false),
            ),
            const Divider(color: _BD, height: 1),
            ListTile(
                leading: const Icon(Icons.logout_rounded, size: 18, color: _T2),
                title: Text(strings.logout,
                    style: GoogleFonts.dmSans(fontSize: 13, color: _T2)),
                onTap: () => ctx.go('/login')),
            const SizedBox(height: 12),
          ]),
        ),
        const VerticalDivider(width: 1, color: _BD),
        Expanded(child: child),
      ]),
    );
  }
}

class _Mobile extends StatelessWidget {
  final Widget child;
  const _Mobile({required this.child});
  @override
  Widget build(BuildContext ctx) {
    final strings = AppStrings.of(ctx);
    final items = [
      _N('/dashboard', Icons.dashboard_rounded, strings.dashboard),
      _N('/students', Icons.people_rounded, strings.students),
      _N('/documents', Icons.folder_rounded, strings.documents),
      _N('/issue', Icons.add_rounded, strings.issueDocument),
      _N('/requests', Icons.inbox_rounded, strings.requests),
    ];
    final path = GoRouterState.of(ctx).uri.toString();
    final sel = items.indexWhere((i) => path.startsWith(i.path));
    return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
            backgroundColor: _SUR,
            selectedIndex: sel < 0 ? 0 : sel,
            onDestinationSelected: (i) => ctx.go(items[i].path),
            destinations: items
                .map((i) =>
                    NavigationDestination(icon: Icon(i.icon), label: i.label))
                .toList()));
  }
}

class _N {
  final String path, label;
  final IconData icon;
  const _N(this.path, this.icon, this.label);
}
