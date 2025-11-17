// lib/main.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sincro_app_flutter/firebase_options.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/login/login_screen.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/user_details/user_details_screen.dart';
import 'package:sincro_app_flutter/features/dashboard/presentation/dashboard_screen.dart';
import 'package:sincro_app_flutter/app/routs/app_router.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

// --- INÍCIO DAS NOVAS IMPORTAÇÕES ---
import 'package:sincro_app_flutter/services/notification_service.dart';
// Removidos imports não utilizados após simplificação do fluxo de autenticação
// --- FIM DAS NOVAS IMPORTAÇÕES ---

// Chave do Site reCAPTCHA v3 para Web
// Em produção, injete via --dart-define=RECAPTCHA_V3_SITE_KEY=... no build.
const String kReCaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_V3_SITE_KEY',
  defaultValue: '6LfPrg8sAAAAAEM0C6vuU0H9qMlXr89zr553zi_B',
);

// ========================================
// FUNÇÃO DE CONEXÃO COM EMULADORES
// ========================================
Future<void> _connectToEmulators() async {
  // Define o host baseado na plataforma
  String host;
  if (kIsWeb) {
    host = 'localhost';
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    // Emulador Android acessa host através de 10.0.2.2
    host = '10.0.2.2';
  } else {
    host = 'localhost';
  }

  // Portas (conforme seu firebase.json)
  const int firestorePort = 8081;
  const int authPort = 9098;
  const int functionsPort = 5002;

  FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);

  await FirebaseAuth.instance.useAuthEmulator(host, authPort);

  FirebaseFunctions.instanceFor(region: 'us-central1')
      .useFunctionsEmulator(host, functionsPort);
}
// ========================================
// FIM DA FUNÇÃO
// ========================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  // Inicializa Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ========================================
  // APP CHECK - ATIVAR IMEDIATAMENTE APÓS FIREBASE
  // ========================================
  // CRÍTICO: App Check DEVE ser ativado ANTES de qualquer
  // chamada a Firestore, Auth ou Functions para evitar 400.
  // Firebase SDK carrega reCAPTCHA v3 automaticamente quando
  // ReCaptchaV3Provider() é instanciado.
  // ========================================
  try {
    debugPrint(
        '🔧 Ativando App Check no startup (ANTES de qualquer serviço Firebase)...');

    if (kDebugMode) {
      // Modo Debug: usa debug provider
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(kReCaptchaSiteKey),
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      debugPrint('✅ App Check ativado em MODO DEBUG');
    } else {
      // Modo Produção: usa providers reais
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(kReCaptchaSiteKey),
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
      );
      debugPrint('✅ App Check ativado em MODO PRODUÇÃO');
    }

    // Aguarda token estar pronto (evita race condition com primeiros requests)
    if (kIsWeb) {
      try {
        await FirebaseAppCheck.instance.getToken();
        debugPrint('✅ Token App Check obtido com sucesso no startup');
      } catch (e) {
        debugPrint('⚠️ Erro ao obter token App Check no startup: $e');
        debugPrint('   (Token será tentado novamente na primeira requisição)');
      }
    }
  } catch (e, s) {
    debugPrint('❌ ERRO CRÍTICO ao ativar App Check: $e');
    debugPrint('Stack trace: $s');
  }
  // ========================================
  // FIM APP CHECK
  // ========================================

  // Inicializa o serviço de notificação (apenas mobile)
  if (!kIsWeb) {
    try {
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('❌ Erro ao inicializar Notification Service: $e');
    }
  }

  if (kDebugMode) {
    try {
      await _connectToEmulators();
    } catch (e) {
      // Intencional: ignorar falha ao conectar aos emuladores em debug
    }
  }

  runApp(const SincroApp());
}

class SincroApp extends StatelessWidget {
  const SincroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SincroApp',
      debugShowCheckedModeBanner: false,
      routes: AppRouter.routes,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
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
        fontFamily: 'Poppins',
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
            fontFamily: 'Poppins',
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
            fontFamily: 'Poppins',
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

  // Removido agendamento de notificações do fluxo inicial web para evitar interferência

  @override
  void initState() {
    super.initState();
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      if (mounted) {
        setState(() {
          _firebaseUser = user;
          _isLoading = false;
        });
        debugPrint('[AuthCheck] authStateChanges emissão user=${user?.uid}');
      }
    });
    debugPrint(
        '[AuthCheck] initState concluído. currentUser inicial=${FirebaseAuth.instance.currentUser?.uid}');
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  // Removido agendamento antecipado para simplificar fluxo de autenticação

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

    if (_firebaseUser == null) {
      return const LoginScreen();
    }

    return FutureBuilder<UserModel?>(
      future: firestoreService.getUserData(_firebaseUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (snapshot.hasError) {
          debugPrint(
              '[AuthCheck] Erro ao carregar UserModel: ${snapshot.error} -> Dashboard');
          return const DashboardScreen();
        }
        final userModel = snapshot.data;
        if (userModel == null) {
          debugPrint('[AuthCheck] UserModel null -> UserDetails');
          return UserDetailsScreen(firebaseUser: _firebaseUser!);
        }
        if (userModel.nomeAnalise.isEmpty) {
          debugPrint('[AuthCheck] nomeAnalise vazio -> UserDetails');
          return UserDetailsScreen(firebaseUser: _firebaseUser!);
        }
        debugPrint('[AuthCheck] UserModel válido -> Dashboard');
        return const DashboardScreen();
      },
    );
  }
}

// Removida extensão auxiliar não utilizada
