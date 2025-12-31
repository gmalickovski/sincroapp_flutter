// lib/main.dart
import 'dart:async';

// import 'package:firebase_auth/firebase_auth.dart'; // Removido
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sincro_app_flutter/firebase_options.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/login/login_screen.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/user_details/user_details_screen.dart';
import 'package:sincro_app_flutter/features/dashboard/presentation/dashboard_screen.dart';
import 'package:sincro_app_flutter/app/routs/app_router.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

// --- INÍCIO DAS NOVAS IMPORTAÇÕES ---
import 'package:sincro_app_flutter/services/notification_service.dart';
import 'package:sincro_app_flutter/services/payment_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import completo (User vem daqui)
import 'package:sincro_app_flutter/services/supabase_service.dart';
// --- FIM DAS NOVAS IMPORTAÇÕES ---

// Chave do Site reCAPTCHA v3 para Web
const String kReCaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_V3_SITE_KEY',
  defaultValue: '6LfPrg8sAAAAAEM0C6vuU0H9qMlXr89zr553zi_B',
);

// ========================================
// FUNÇÃO DE CONEXÃO COM EMULADORES
// ========================================
Future<void> _connectToEmulators() async {
  String host = kIsWeb ? 'localhost' : (defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost');

  const int firestorePort = 8081;
  // const int authPort = 9098; // Auth Emulator não usado com Supabase
  const int functionsPort = 5002;

  FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);

  // await FirebaseAuth.instance.useAuthEmulator(host, authPort); // Removido

  FirebaseFunctions.instanceFor(region: 'us-central1')
      .useFunctionsEmulator(host, functionsPort);

  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
}

import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🚀 Import dotenv

// ... (imports remain)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  // 🚀 Carrega o arquivo .env
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('📄 Arquivo .env carregado com sucesso.');
  } catch (e) {
    debugPrint('⚠️ Erro ao carregar .env: $e');
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ... (PaymentService init)

  // ========================================
  // INICIALIZAÇÃO SUPABASE (USANDO .ENV)
  // ========================================
  try {
    // Tenta pegar do .env, se não existir usa string vazia (que vai dar erro, mas é o esperado se faltar config)
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? const String.fromEnvironment('SUPABASE_URL');
    final supabaseAnonKey = dotenv.env['ANON_KEY'] ?? const String.fromEnvironment('SUPABASE_ANON_KEY'); // Note: .env usually uses ANON_KEY, flutter uses SUPABASE_ANON_KEY

    // Fallback para hardcoded se ainda estiver vazio (segurança para o usuário não ficar travado agora)
    // Mas o ideal é vir do .env
    
    await Supabase.initialize(
      url: supabaseUrl ?? 'https://supabase.studiomlk.com.br', 
      anonKey: supabaseAnonKey ?? 'chave-invalida-se-nao-tiver-no-env',
    );
    debugPrint('🚀 Supabase inicializado com sucesso usando .env!');
  } catch (e) {
    debugPrint('❌ Erro ao inicializar Supabase: $e');
  }

  const bool useEmulators = kDebugMode; 

  if (kDebugMode && useEmulators) {
    try {
      await _connectToEmulators();
      debugPrint('🔧 Conectado aos emuladores do Firebase (Firestore, Functions, Storage)');
    } catch (e) {
      debugPrint('⚠️ Falha ao conectar aos emuladores: $e');
    }
  }

  // APP CHECK (Pulo se estiver em emulação, mas mantendo lógica original)
  if (!(kDebugMode && useEmulators)) {
    try {
      debugPrint('🔧 Ativando App Check (Produção)...');
      if (kIsWeb) {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(kReCaptchaSiteKey),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        await FirebaseAppCheck.instance.activate(
          appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        );
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        );
      }
    } catch (e, s) {
      debugPrint('❌ ERRO ao ativar App Check: $e');
    }
  }

  if (!kIsWeb) {
    try {
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('❌ Erro ao inicializar Notification Service: $e');
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
            shape: const StadiumBorder(),
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
  User? _user;
  bool _isLoading = true;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      debugPrint('[AuthCheck] ========== authStateChanges EMISSÃO ==========');
      debugPrint('[AuthCheck] user recebido: ${user?.id ?? "NULL"}');
      debugPrint('[AuthCheck] email: ${user?.email ?? "N/A"}');
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
          _hasNavigated = false; // Reset ao mudar usuário
        });
        debugPrint(
            '[AuthCheck] setState concluído. _user=${_user?.id}, _isLoading=$_isLoading');
      }
      debugPrint(
          '[AuthCheck] ================================================');
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _navigateToScreen(Widget screen, String screenName) {
    if (_hasNavigated) {
      debugPrint(
          '[AuthCheck] ⚠️  Navegação para $screenName já realizada, ignorando');
      return;
    }

    _hasNavigated = true;
    debugPrint('[AuthCheck] 🚀 Navegando para $screenName via pushReplacement');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => screen),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();

    if (_isLoading) {
      return const Scaffold(
        key: ValueKey('loading'),
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_user == null) {
      debugPrint('[AuthCheck] Nenhum usuário autenticado -> LoginScreen');
      return const LoginScreen(key: ValueKey('login'));
    }

    debugPrint(
        '[AuthCheck] Usuário autenticado: ${_user!.id}, carregando dados do Supabase...');

    return FutureBuilder<UserModel?>(
      key: ValueKey(_user!.id), 
      future: supabaseService.getUserData(_user!.id),
      builder: (context, snapshot) {
        debugPrint(
            '[AuthCheck] FutureBuilder - connectionState: ${snapshot.connectionState}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            key: ValueKey('loading-user'),
            backgroundColor: AppColors.background,
            body: Center(
              child: CustomLoadingSpinner(),
            ),
          );
        }
        if (snapshot.hasError) {
          debugPrint(
              '[AuthCheck] Erro ao carregar UserModel: ${snapshot.error} -> Dashboard');
          // Em caso de erro, tentamos ir para Dashboard mesmo assim (pode ser erro temporário)
          // Ou então redirecionar para Login se for erro de Auth?
          // Vou manter Dashboard por enquanto.
          _navigateToScreen(const DashboardScreen(), 'DashboardScreen (error)');
          return const Scaffold(
            key: ValueKey('navigating'),
            backgroundColor: AppColors.background,
            body: Center(
              child: CustomLoadingSpinner(),
            ),
          );
        }

        final userModel = snapshot.data;
        if (userModel == null) {
          debugPrint('[AuthCheck] UserModel null -> UserDetails');
          _navigateToScreen(
            UserDetailsScreen(user: _user!),
            'UserDetailsScreen (null)',
          );
          return const Scaffold(
            key: ValueKey('navigating'),
            backgroundColor: AppColors.background,
            body: Center(
              child: CustomLoadingSpinner(),
            ),
          );
        }

        final String nomeAnalise = (userModel.nomeAnalise).trim();
        final String dataNasc = (userModel.dataNasc).trim();
        final bool dataValida =
            RegExp(r'^\d{2}/\d{2}/\d{4} ?$').hasMatch(dataNasc) ||
                RegExp(r'^\d{2}/\d{2}/\d{4}$')
                    .hasMatch(dataNasc); 

        if (nomeAnalise.isEmpty || dataNasc.isEmpty || !dataValida) {
          debugPrint(
              '[AuthCheck] Dados incompletos -> UserDetails');
          _navigateToScreen(
            UserDetailsScreen(user: _user!),
            'UserDetailsScreen (missing-or-invalid)',
          );
          return const Scaffold(
            key: ValueKey('navigating'),
            backgroundColor: AppColors.background,
            body: Center(
              child: CustomLoadingSpinner(),
            ),
          );
        }

        debugPrint('[AuthCheck] UserModel válido -> Dashboard');
        _navigateToScreen(const DashboardScreen(), 'DashboardScreen');

        return const Scaffold(
          key: ValueKey('navigating'),
          backgroundColor: AppColors.background,
          body: Center(
            child: CustomLoadingSpinner(),
          ),
        );
      },
    );
  }
}
