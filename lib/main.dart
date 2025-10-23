// lib/main.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:sincro_app_flutter/firebase_options.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/login/login_screen.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/user_details/user_details_screen.dart';
import 'package:sincro_app_flutter/features/dashboard/presentation/dashboard_screen.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

// Chave do Site reCAPTCHA v3 para Web
const String kReCaptchaSiteKey = '6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  // Inicializa Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    debugPrint('🔧 Inicializando Firebase App Check...');

    // ========================================
    // CONFIGURAÇÃO AUTOMÁTICA DO APP CHECK
    // ========================================
    // O Flutter detecta automaticamente se está em:
    // - Modo debug (desenvolvimento)
    // - Modo release (produção)
    // E escolhe o provedor correto!

    await FirebaseAppCheck.instance.activate(
      // ===== WEB =====
      // Em debug: usa debug token (definido no index.html)
      // Em release: usa reCAPTCHA v3 automaticamente
      webProvider: ReCaptchaV3Provider(kReCaptchaSiteKey),

      // ===== ANDROID =====
      // Em debug (kDebugMode = true): usa debug provider
      // Em release (kDebugMode = false): usa Play Integrity (requer app na Play Store)
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,

      // ===== iOS/macOS =====
      // Em debug: usa debug provider
      // Em release: usa App Attest (requer app na App Store)
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );

    debugPrint('✅ Firebase App Check ativado!');
    _logAppCheckStatus();
  } catch (e, s) {
    debugPrint('');
    debugPrint('❌ ===== ERRO NO APP CHECK =====');
    debugPrint('Erro: $e');
    debugPrint('StackTrace: $s');
    debugPrint('================================');
    debugPrint('');
  }

  runApp(const SincroApp());
}

/// Função helper para logar o status do App Check
void _logAppCheckStatus() {
  if (!kDebugMode) {
    // Em produção, não logamos detalhes
    return;
  }

  debugPrint('');
  debugPrint('📱 ===== APP CHECK STATUS =====');
  debugPrint('Modo: ${kDebugMode ? "DEBUG 🛠️" : "RELEASE 🚀"}');
  debugPrint('Plataforma: ${defaultTargetPlatform.name}');

  if (kIsWeb) {
    debugPrint('');
    debugPrint('🌐 WEB:');
    if (kDebugMode) {
      debugPrint('  ✓ Usando: Debug Token');
      debugPrint('  ℹ️ Procure no console por:');
      debugPrint('     "Firebase App Check debug token: XXXX..."');
      debugPrint('  ℹ️ Registre em: console.firebase.google.com > App Check');
    } else {
      debugPrint('  ✓ Usando: reCAPTCHA v3 (Produção)');
      debugPrint('  ✓ Site Key: $kReCaptchaSiteKey');
    }
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    debugPrint('');
    debugPrint('🤖 ANDROID:');
    if (kDebugMode) {
      debugPrint('  ✓ Usando: Debug Provider');
      debugPrint('  ⚠️ PROCURE NO LOGCAT POR:');
      debugPrint('     "Firebase App Check debug token"');
      debugPrint('  ℹ️ Registre em: console.firebase.google.com > App Check');
    } else {
      debugPrint('  ✓ Usando: Play Integrity API (Produção)');
      debugPrint('  ⚠️ Requer: App publicado na Play Store');
    }
  } else if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    debugPrint('');
    debugPrint('🍎 iOS/macOS:');
    if (kDebugMode) {
      debugPrint('  ✓ Usando: Debug Provider');
      debugPrint('  ℹ️ Registre o token no Firebase Console');
    } else {
      debugPrint('  ✓ Usando: App Attest (Produção)');
      debugPrint('  ⚠️ Requer: App publicado na App Store');
    }
  }

  debugPrint('================================');
  debugPrint('');
}

class SincroApp extends StatelessWidget {
  const SincroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SincroApp',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primaryAccent,
        fontFamily: 'Inter',
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        textTheme: const TextTheme().apply(
          bodyColor: AppColors.primaryText,
          displayColor: AppColors.primaryText,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryAccent,
            foregroundColor: AppColors.primaryText,
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF2a2141),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            color: AppColors.primaryText,
            fontFamily: 'Inter',
            fontSize: 16,
          ),
          elevation: 4,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          space: 1,
          thickness: 1,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.primary),
          titleTextStyle: TextStyle(
            color: AppColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
      ),
      home: const AuthCheck(),
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  late final StreamSubscription<User?> _authSubscription;
  final AuthRepository _authRepository = AuthRepository();
  User? _firebaseUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      if (mounted) {
        setState(() {
          _firebaseUser = user;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_firebaseUser != null) {
      return FutureBuilder<UserModel?>(
        future: firestoreService.getUserData(_firebaseUser!.uid),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          if (userSnapshot.hasData &&
              userSnapshot.data != null &&
              userSnapshot.data!.nomeAnalise.isNotEmpty) {
            return const DashboardScreen();
          }

          if (userSnapshot.data == null ||
              userSnapshot.data!.nomeAnalise.isEmpty) {
            return UserDetailsScreen(firebaseUser: _firebaseUser!);
          }

          return const LoginScreen();
        },
      );
    }
    return const LoginScreen();
  }
}
