// lib/main.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
import 'package:sincro_app_flutter/app/routs/app_router.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

// --- INÍCIO DAS NOVAS IMPORTAÇÕES ---
import 'package:sincro_app_flutter/services/notification_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
// --- FIM DAS NOVAS IMPORTAÇÕES ---

// Chave do Site reCAPTCHA v3 para Web
const String kReCaptchaSiteKey = '6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU';

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

  // Inicializa o serviço de notificação
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('❌ Erro ao inicializar Notification Service: $e');
  }

  if (kDebugMode) {
    try {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(kReCaptchaSiteKey),
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
    } catch (e, s) {
      debugPrint('⚠️ Falha ao ativar App Check (debug): $e');
      debugPrint('$s');
    }

    try {
      await _connectToEmulators();
    } catch (e) {
      // Intencional: ignorar falha ao conectar aos emuladores em debug
    }
  } else {
    // ========================================
    // EM MODO RELEASE, ATIVE O APP CHECK
    // ========================================
    try {
      debugPrint('🔧 Inicializando Firebase App Check...');

      // ========================================
      // CONFIGURAÇÃO AUTOMÁTICA DO APP CHECK
      // ========================================
      await FirebaseAppCheck.instance.activate(
        // ===== WEB =====
        webProvider: ReCaptchaV3Provider(kReCaptchaSiteKey),

        // ===== ANDROID =====
        // Em release (kDebugMode = false): usa Play Integrity
        androidProvider: AndroidProvider.playIntegrity,

        // ===== iOS/macOS =====
        // Em release: usa App Attest
        appleProvider: AppleProvider.appAttest,
      );
    } catch (e, s) {
      debugPrint('');
      debugPrint('❌ ===== ERRO NO APP CHECK =====');
      debugPrint('Erro: $e');
      debugPrint('StackTrace: $s');
      debugPrint('================================');
      debugPrint('');
    }
  }
  // === FIM DA LÓGICA DE ATIVAÇÃO CONDICIONAL ===

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

  // --- NOVA VARIÁVEL DE ESTADO ---
  bool _dailyNotificationsScheduled = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      if (mounted) {
        setState(() {
          _firebaseUser = user;
          _isLoading = false;
          // --- ADICIONADO ---
          // Se o usuário deslogar, reseta o flag
          if (user == null) {
            _dailyNotificationsScheduled = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  // --- NOVA FUNÇÃO HELPER ---
  /// Agenda as notificações diárias (Dia Pessoal e Lembrete de Fim de Dia)
  void _scheduleDailyNotifications(UserModel user) {
    // Garante que só rode uma vez por login
    if (_dailyNotificationsScheduled) return;
    if (user.nomeAnalise.isEmpty || user.dataNasc.isEmpty) return;

    try {
      // 1. Agendar Notificação Matinal (Feature #2)
      final engine = NumerologyEngine(
        nomeCompleto: user.nomeAnalise,
        dataNascimento: user.dataNasc,
      );
      final today = DateTime.now();
      final personalDay = engine.calculatePersonalDayForDate(today);

      final dayInfo = ContentData.vibracoes['diaPessoal']?[personalDay];
      final title = "✨ Vibração do seu Dia: $personalDay";

      // --- INÍCIO DA CORREÇÃO ---
      // A propriedade correta é 'descricaoCurta', conforme
      // lib/features/authentication/data/content_data.dart
      final body = dayInfo?.descricaoCurta ??
          "Veja o que a vibração de hoje significa para você.";
      // --- FIM DA CORREÇÃO ---

      NotificationService.instance.scheduleDailyPersonalDayNotification(
        title: title,
        body: body,
        // --- INÍCIO DA CORREÇÃO ---
        // Usa o construtor TimeOfDay
        scheduleTime: const TimeOfDay(hour: 8, minute: 0), // 8:00 AM
        // --- FIM DA CORREÇÃO ---
      );

      // 2. Agendar Verificação de Fim de Dia (Feature #1)
      NotificationService.instance.scheduleDailyEndOfDayCheck(
        user.uid,
        // --- INÍCIO DA CORREÇÃO ---
        // Usa o construtor TimeOfDay
        const TimeOfDay(hour: 21, minute: 0), // 9:00 PM
        // --- FIM DA CORREÇÃO ---
      );

      // Marca como agendado
      setState(() {
        _dailyNotificationsScheduled = true;
      });
      debugPrint(
          "✅ Notificações diárias (Dia Pessoal e Fim de Dia) agendadas.");
    } catch (e) {
      debugPrint("❌ Erro ao agendar notificações diárias: $e");
    }
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
            // --- INÍCIO DA LÓGICA DE AGENDAMENTO ---
            // Agenda as notificações diárias assim que temos os dados do usuário
            _scheduleDailyNotifications(userSnapshot.data!);
            // --- FIM DA LÓGICA DE AGENDAMENTO ---

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
